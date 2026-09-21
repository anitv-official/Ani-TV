import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../extension_base.dart';
import 'extension_http.dart';

class YouTubeExtension extends AniExtension {
  static const _base = 'https://www.youtube.com';
  static const _clientVersion = '2.20240101.00.00';
  final http.Client _client = http.Client();
  final YoutubeExplode _extractor = YoutubeExplode();

  @override String get id => 'youtube';
  @override String get name => 'YouTube';
  @override String get kind => 'video';
  @override List<String> get hosts => const ['youtube.com', 'youtu.be', 'googlevideo.com'];
  @override String get contentLabel => 'فيديوهات YouTube';
  @override String get iconUrl => 'https://www.youtube.com/s/desktop/28b1f4a1/img/favicon_32x32.png';
  @override ExtensionStatus get status => ExtensionStatus.limited;
  @override String get statusMessage => 'بحث YouTube وتشغيل مباشر Native عبر InnerTube';

  Map<String, String> _headers({String? referer, bool json = false}) => {
        'User-Agent': ExtensionHttp.userAgent,
        'Accept': json ? 'application/json' : 'text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8',
        'Accept-Language': 'ar,en-US;q=0.9,en;q=0.8',
        if (referer != null) 'Referer': referer,
        if (json) 'Content-Type': 'application/json',
      };

  Future<String> _page(String url) async {
    final response = await _client.get(Uri.parse(url), headers: _headers(referer: _base)).timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 400) throw Exception('YouTube HTTP ${response.statusCode}');
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  @override Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    try {
      final uri = Uri.parse('$_base/results').replace(queryParameters: {'search_query': 'anime', 'sp': 'CAI=', 'page': '$page'});
      final recent = _videosFromPage(await _page(uri.toString()));
      if (recent.isNotEmpty) return recent;
      return _videosFromPage(await _page('$_base/feed/trending'));
    } catch (_) { return []; }
  }

  @override Future<List<Map<String, dynamic>>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return latest();
    return _searchPage(value, 1);
  }

  @override Future<List<Map<String, dynamic>>> nextPage({String query = '', int page = 2}) async {
    if (query.trim().isEmpty) return latest(page: page);
    return _searchPage(query, page);
  }

  Future<List<Map<String, dynamic>>> _searchPage(String query, int page) async {
    try {
      final uri = Uri.parse('$_base/results').replace(queryParameters: {'search_query': query, 'page': '$page'});
      return _videosFromPage(await _page(uri.toString()));
    } catch (_) { return []; }
  }

  List<Map<String, dynamic>> _videosFromPage(String html) {
    final jsonText = extractBalancedJson(html, 'var ytInitialData =') ?? extractBalancedJson(html, 'ytInitialData =');
    if (jsonText == null) return [];
    try {
      final root = jsonDecode(jsonText);
      final videos = <Map<String, dynamic>>[];
      final seen = <String>{};
      void add(String id, String title, String image, String views, String description, [String duration = '']) {
        if (id.length < 6 || title.trim().isEmpty || !seen.add(id)) return;
        videos.add({...item(title: title.trim(), url: '$_base/watch?v=$id', image: image.isEmpty ? 'https://i.ytimg.com/vi/$id/hqdefault.jpg' : image, type: 'video', description: description, rating: views), 'duration': duration});
      }
      String text(dynamic value) {
        if (value is Map) {
          if (value['simpleText'] != null) return value['simpleText'].toString();
          if (value['content'] != null) return value['content'].toString();
          if (value['runs'] is List) return (value['runs'] as List).map((e) => e is Map ? e['text']?.toString() ?? '' : '').join();
        }
        return value?.toString() ?? '';
      }
      String thumb(dynamic value) => value is Map && value['thumbnails'] is List && (value['thumbnails'] as List).isNotEmpty ? ((value['thumbnails'] as List).last as Map)['url']?.toString() ?? '' : '';
      void walk(dynamic node) {
        if (node is Map) {
          final renderer = node['videoRenderer'] ?? node['gridVideoRenderer'] ?? node['compactVideoRenderer'] ?? node['videoWithContextRenderer'];
          if (renderer is Map) add(renderer['videoId']?.toString() ?? '', text(renderer['title']), thumb(renderer['thumbnail']), text(renderer['viewCountText']), text(renderer['descriptionSnippet']), text(renderer['lengthText']));
          final lockup = node['lockupViewModel'];
          if (lockup is Map && lockup['contentId']?.toString().isNotEmpty == true) {
            final metadata = lockup['metadata']?['lockupMetadataViewModel'];
            add(lockup['contentId'].toString(), text(metadata?['title']), thumb(lockup['contentImage']?['collectionThumbnailViewModel']?['primaryThumbnail']?['thumbnailViewModel']?['image']), text(metadata?['secondaryTitle']), '');
          }
          final reel = node['reelItemRenderer'];
          if (reel is Map) {
            final endpoint = reel['onTap']?['innertubeCommand']?['reelWatchEndpoint'];
            final id = endpoint?['videoId']?.toString() ?? reel['videoId']?.toString() ?? '';
            add(id, text(reel['headline'] ?? reel['overlayMetadata']?['primaryText']), thumb(reel['thumbnail'] ?? reel['thumbnailViewModel']?['image']), text(reel['viewCountText']), 'Shorts');
          }
          for (final value in node.values) walk(value);
        } else if (node is List) { for (final value in node) walk(value); }
      }
      walk(root);
      return videos.take(120).toList(growable: false);
    } catch (_) { return []; }
  }

  String _videoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    if (uri.host == 'youtu.be') return uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
    final value = uri.queryParameters['v'];
    if (value != null && value.isNotEmpty) return value;
    final parts = uri.pathSegments;
    return parts.isEmpty ? '' : parts.last;
  }

  Future<Map<String, dynamic>> _player(String videoId) async {
    final page = await _page('$_base/watch?v=$videoId');
    final key = RegExp(r'"INNERTUBE_API_KEY":"([^"]+)"').firstMatch(page)?.group(1);
    if (key == null) throw Exception('YouTube player API key unavailable');
    final response = await _client.post(Uri.parse('$_base/youtubei/v1/player?key=$key'), headers: _headers(referer: _base, json: true), body: jsonEncode({
      'context': {'client': {'clientName': 'WEB', 'clientVersion': _clientVersion, 'hl': 'ar', 'gl': 'US'}},
      'videoId': videoId,
      'contentCheckOk': true,
      'racyCheckOk': true,
    })).timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('YouTube player HTTP ${response.statusCode}');
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true)) as Map);
  }

  @override Future<Map<String, dynamic>> details(String url) async {
    final id = _videoId(url);
    try {
      final player = await _player(id);
      final details = player['videoDetails'] as Map?;
      final microformat = (player['microformat'] as Map?)?['playerMicroformatRenderer'] as Map?;
      final title = details?['title']?.toString() ?? id;
      final thumbs = details?['thumbnail'];
      return {
        ...item(title: title, url: url, image: _thumbnail(thumbs) ?? 'https://i.ytimg.com/vi/$id/hqdefault.jpg', type: 'video', description: details?['shortDescription']?.toString() ?? ''),
        'author': details?['author']?.toString() ?? '',
        'view_count': details?['viewCount']?.toString() ?? '',
        'published': microformat?['publishDate']?.toString() ?? '',
        'duration': details?['lengthSeconds']?.toString() ?? '',
        'episodes': [{'id': id, 'title': title, 'number': 1, 'url': url}],
        'video_id': id,
      };
    } catch (_) {
      return {...item(title: id, url: url, image: 'https://i.ytimg.com/vi/$id/hqdefault.jpg', type: 'video'), 'episodes': [{'id': id, 'title': id, 'number': 1, 'url': url}], 'video_id': id};
    }
  }

  @override Future<Map<String, dynamic>?> streams(String url) async {
    try {
      final id = _videoId(url);
      final manifest = await _extractor.videos.streamsClient.getManifest(id);
      final links = <Map<String, String>>[];
      final seen = <String>{};
      for (final info in manifest.muxed) {
        final value = info.url.toString();
        if (value.isEmpty || !seen.add(value)) continue;
        links.add({'url': value, 'quality': info.qualityLabel, 'name': 'YouTube Native', 'label': 'Muxed', 'type': 'video'});
      }
      links.sort((a, b) => _quality(b['quality']).compareTo(_quality(a['quality'])));
      if (links.isEmpty) return null;
      return {'stream_url': links.first['url'], 'direct_stream_urls': links, 'headers': {'User-Agent': ExtensionHttp.userAgent, 'Referer': _base}, 'allowed_hosts': ['googlevideo.com']};
    } catch (_) { return null; }
  }

  static String? _thumbnail(dynamic value) => value is Map && value['thumbnails'] is List && (value['thumbnails'] as List).isNotEmpty ? ((value['thumbnails'] as List).last as Map)['url']?.toString() : null;
  static int _quality(String? value) => int.tryParse((value ?? '').replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
}
