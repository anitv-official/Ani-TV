import 'dart:convert';
import 'package:http/http.dart' as http;
import 'source_base.dart';

class YoutubeSource extends ContentSource {
  final http.Client _client = http.Client();
  static const _userAgent = 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/122 Safari/537.36';

  @override String get id => 'youtube';
  @override String get name => 'YouTube';
  @override String get kind => 'youtube';
  @override List<String> get hosts => const ['youtube.com', 'youtu.be', 'www.youtube.com', 'm.youtube.com'];

  @override Future<List<Map<String, dynamic>>> latest({int page = 1}) => search('أحدث فيديوهات عربية');

  @override Future<List<Map<String, dynamic>>> search(String query) async {
    final value = query.trim().isEmpty ? 'أحدث فيديوهات عربية' : query.trim();
    final uri = Uri.https('www.youtube.com', '/results', {'search_query': value, 'hl': 'ar', 'gl': 'US'});
    final response = await _client.get(uri, headers: const {
      'User-Agent': _userAgent,
      'Accept-Language': 'ar,en;q=0.8',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    }).timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('تعذر الاتصال بـ YouTube (${response.statusCode})');
    final data = _initialData(response.body);
    final videos = <Map<String, dynamic>>[];
    _walk(data, videos);
    if (videos.isEmpty) throw Exception('لم يعثر YouTube على فيديوهات لهذه الكلمة');
    return videos;
  }

  @override Future<Map<String, dynamic>> details(String url) async => item(title: 'فيديو YouTube', url: url, type: 'فيديو');

  @override Future<Map<String, dynamic>?> streams(String url) async => {'stream_url': url, 'direct_stream_urls': [{'url': url, 'label': 'YouTube', 'name': 'YouTube', 'type': 'youtube'}], 'title': 'YouTube'};

  Map<String, dynamic> _initialData(String html) {
    final encoded = RegExp(
      r"""var\s+ytInitialData\s*=\s*'((?:\\.|[^'])*)'""",
      caseSensitive: false,
    ).firstMatch(html)?.group(1);
    if (encoded != null) {
      final decoded = encoded
          .replaceAllMapped(RegExp(r'\\x([0-9a-fA-F]{2})'), (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)))
          .replaceAllMapped(RegExp(r'\\u([0-9a-fA-F]{4})'), (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)))
          .replaceAll(r'\/', '/');
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
      if (id.isNotEmpty && output.every((item) => item['video_id'] != id) && output.length < 100) {
        final title = _runs(renderer['title']);
        final channel = _runs(renderer['ownerText'] ?? renderer['longBylineText'] ?? renderer['shortBylineText']);
        final thumbnails = renderer['thumbnail']?['thumbnails'];
        final image = thumbnails is List && thumbnails.isNotEmpty ? thumbnails.last['url']?.toString() ?? '' : '';
        final duration = _runs(renderer['lengthText']);
        output.add(item(title: title.isEmpty ? 'فيديو YouTube' : title, url: 'https://www.youtube.com/watch?v=$id', image: image, type: 'فيديو', description: channel, rating: duration)..['video_id'] = id);
      }
    }
    for (final child in value.values) _walk(child, output);
  }

  String _runs(dynamic value) {
    if (value is Map && value['simpleText'] != null) return value['simpleText'].toString();
    if (value is Map && value['runs'] is List) return (value['runs'] as List).map((run) => run is Map ? run['text']?.toString() ?? '' : '').join();
    return '';
  }
}
