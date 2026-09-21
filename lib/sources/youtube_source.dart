import 'dart:convert';
import 'package:http/http.dart' as http;
import 'source_base.dart';

class YoutubeSource extends ContentSource {
  final http.Client _client = http.Client();
  static const _userAgent = 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/122 Safari/537.36';
  static const _pipedApis = <String>[
    'https://pipedapi.kavin.rocks',
    'https://pipedapi.leptons.xyz',
    'https://piped-api.privacy.com.de',
    'https://pipedapi-libre.kavin.rocks',
    'https://pipedapi.reallyaweso.me',
  ];
  final Map<String, String> _continuations = {};

  @override String get id => 'youtube';
  @override String get name => 'YouTube';
  @override String get kind => 'youtube';
  @override List<String> get hosts => const ['youtube.com', 'youtu.be', 'www.youtube.com', 'm.youtube.com'];

  @override Future<List<Map<String, dynamic>>> latest({int page = 1}) => _searchPage('أحدث فيديوهات عربية', page);
  @override Future<List<Map<String, dynamic>>> search(String query) => _searchPage(query, 1);

  @override Future<List<Map<String, dynamic>>> nextPage({String query = '', int page = 2}) async {
    final value = query.trim().isEmpty ? 'أحدث فيديوهات عربية' : query.trim();
    final token = _continuations[value];
    if (token == null || token.isEmpty) return _searchPage(value, page);
    final response = await _client.post(
      Uri.https('www.youtube.com', '/youtubei/v1/search', {'prettyPrint': 'false'}),
      headers: const {'User-Agent': _userAgent, 'Accept-Language': 'ar,en;q=0.8', 'Content-Type': 'application/json'},
      body: jsonEncode({'context': {'client': {'clientName': 'WEB', 'clientVersion': '2.20250915.01.00'}}, 'continuation': token}),
    ).timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('تعذر تحميل صفحة YouTube التالية (${response.statusCode})');
    final data = jsonDecode(response.body);
    if (data is! Map) return const [];
    _continuations[value] = _findContinuation(data) ?? '';
    final videos = <Map<String, dynamic>>[];
    _walk(data, videos);
    return videos;
  }

  Future<List<Map<String, dynamic>>> _searchPage(String query, int page) async {
    final value = query.trim().isEmpty ? 'أحدث فيديوهات عربية' : query.trim();
    final uri = Uri.https('www.youtube.com', '/results', {'search_query': value, 'hl': 'ar', 'gl': 'US', if (page > 1) 'page': '$page'});
    final response = await _client.get(uri, headers: const {
      'User-Agent': _userAgent,
      'Accept-Language': 'ar,en;q=0.8',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    }).timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('تعذر الاتصال بـ YouTube (${response.statusCode})');
    final data = _initialData(response.body);
    _continuations[value] = _findContinuation(data) ?? '';
    final videos = <Map<String, dynamic>>[];
    _walk(data, videos);
    if (videos.isEmpty) throw Exception('لم يعثر YouTube على فيديوهات لهذه الكلمة');
    return videos;
  }

  @override Future<Map<String, dynamic>> details(String url) async => item(title: 'فيديو YouTube', url: url, type: 'فيديو');

  @override Future<Map<String, dynamic>?> streams(String url) async {
    final id = _videoId(url);
    if (id.isEmpty) return null;
    for (final api in _pipedApis) {
      try {
        final response = await _client.get(Uri.parse('$api/streams/$id'), headers: const {'Accept': 'application/json', 'User-Agent': _userAgent}).timeout(const Duration(seconds: 20));
        if (response.statusCode < 200 || response.statusCode >= 300) continue;
        final raw = jsonDecode(response.body);
        if (raw is! Map) continue;
        final data = Map<String, dynamic>.from(raw);
        final links = <Map<String, dynamic>>[];
        final hls = data['hls']?.toString() ?? '';
        if (hls.isNotEmpty) links.add({'url': hls, 'label': 'HLS', 'name': 'HLS', 'quality': 'Auto', 'type': 'hls'});
        final streams = data['videoStreams'];
        if (streams is List) {
          final playable = streams.whereType<Map>().where((stream) => stream['videoOnly'] != true && (stream['url']?.toString() ?? '').isNotEmpty).toList();
          playable.sort((a, b) => _quality(b['height']).compareTo(_quality(a['height'])));
          for (final stream in playable.take(5)) {
            final quality = stream['quality']?.toString() ?? '${stream['height'] ?? ''}p';
            links.add({'url': stream['url'].toString(), 'label': quality, 'name': quality, 'quality': quality, 'type': 'mp4'});
          }
        }
        if (links.isNotEmpty) return {'stream_url': links.first['url'], 'direct_stream_urls': links, 'title': data['title']?.toString() ?? 'YouTube'};
      } catch (_) {}
    }
    return null;
  }

  Map<String, dynamic> _initialData(String html) {
    final encoded = RegExp(r"""var\s+ytInitialData\s*=\s*'((?:\\.|[^'])*)'""", caseSensitive: false).firstMatch(html)?.group(1);
    if (encoded != null) {
      final decoded = encoded.replaceAllMapped(RegExp(r'\\x([0-9a-fA-F]{2})'), (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16))).replaceAllMapped(RegExp(r'\\u([0-9a-fA-F]{4})'), (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16))).replaceAll(r'\/', '/');
      final value = jsonDecode(decoded);
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    const marker = 'var ytInitialData = ';
    final start = html.indexOf(marker);
    if (start < 0) throw Exception('لم يتم العثور على بيانات YouTube');
    final jsonStart = start + marker.length;
    final end = html.indexOf(';</script>', jsonStart);
    if (end < 0) throw Exception('استجابة YouTube غير مكتملة');
    final decoded = jsonDecode(html.substring(jsonStart, end));
    if (decoded is! Map) throw Exception('بيانات YouTube غير صالحة');
    return Map<String, dynamic>.from(decoded);
  }

  void _walk(dynamic value, List<Map<String, dynamic>> output) {
    if (value is List) { for (final item in value) _walk(item, output); return; }
    if (value is! Map) return;
    final renderer = value['videoRenderer'] ?? value['gridVideoRenderer'] ?? value['compactVideoRenderer'];
    if (renderer is Map) {
      final id = renderer['videoId']?.toString() ?? '';
      if (id.isNotEmpty && output.every((item) => item['video_id'] != id) && output.length < 200) {
        final title = _runs(renderer['title']);
        final channel = _runs(renderer['ownerText'] ?? renderer['longBylineText'] ?? renderer['shortBylineText']);
        final thumbnails = renderer['thumbnail']?['thumbnails'];
        final image = thumbnails is List && thumbnails.isNotEmpty ? thumbnails.last['url']?.toString() ?? '' : 'https://i.ytimg.com/vi/$id/hqdefault.jpg';
        final duration = _runs(renderer['lengthText']);
        output.add(item(title: title.isEmpty ? 'فيديو YouTube' : title, url: 'https://www.youtube.com/watch?v=$id', image: image, type: 'فيديو', description: channel, rating: duration)..['video_id'] = id);
      }
    }
    for (final child in value.values) _walk(child, output);
  }

  String? _findContinuation(dynamic value) {
    if (value is List) {
      for (final child in value) { final found = _findContinuation(child); if (found != null && found.isNotEmpty) return found; }
    } else if (value is Map) {
      final direct = value['continuationCommand']?['token'] ?? value['nextContinuationData']?['continuation'];
      if (direct is String && direct.isNotEmpty) return direct;
      for (final child in value.values) { final found = _findContinuation(child); if (found != null && found.isNotEmpty) return found; }
    }
    return null;
  }

  String _videoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    if (uri.host.contains('youtu.be')) return uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
    return uri.queryParameters['v'] ?? (uri.pathSegments.contains('shorts') && uri.pathSegments.length > 1 ? uri.pathSegments[1] : '');
  }

  int _quality(dynamic value) => int.tryParse(value?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '') ?? 0;
  String _runs(dynamic value) {
    if (value is Map && value['simpleText'] != null) return value['simpleText'].toString();
    if (value is Map && value['runs'] is List) return (value['runs'] as List).map((run) => run is Map ? run['text']?.toString() ?? '' : '').join();
    return '';
  }
}
