import 'dart:convert';
import '../extension_base.dart';
import 'extension_http.dart';

class YouTubeExtension extends AniExtension {
  static const _base = 'https://www.youtube.com';

  @override String get id => 'youtube';
  @override String get name => 'YouTube';
  @override String get kind => 'video';
  @override List<String> get hosts => const ['youtube.com', 'youtu.be'];
  @override String get contentLabel => 'فيديوهات';
  @override String get iconUrl => 'https://www.youtube.com/s/desktop/28b1f4a1/img/favicon_32x32.png';
  @override ExtensionStatus get status => ExtensionStatus.limited;
  @override String get statusMessage => 'روابط progressive؛ DASH وSubtitles تحتاج bridge لاحقاً';

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final html = await ExtensionHttp.getText('$_base/feed/trending');
    return _videosFromPage(html);
  }

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return latest();
    final uri = Uri.parse('$_base/results').replace(queryParameters: {'search_query': value});
    return _videosFromPage(await ExtensionHttp.getText(uri.toString()));
  }

  List<Map<String, dynamic>> _videosFromPage(String html) {
    final jsonText = extractBalancedJson(html, 'var ytInitialData =') ?? extractBalancedJson(html, 'ytInitialData =');
    if (jsonText == null) return [];
    try {
      final root = jsonDecode(jsonText);
      final videos = <Map<String, dynamic>>[];
      final seen = <String>{};
      void walk(dynamic node) {
        if (node is Map) {
          final renderer = node['videoRenderer'] ?? node['gridVideoRenderer'] ?? node['compactVideoRenderer'] ?? node['videoWithContextRenderer'];
          if (renderer is Map) {
            final id = renderer['videoId']?.toString() ?? '';
            final title = _textValue(renderer['title']);
            final thumb = _thumbnail(renderer['thumbnail']);
            if (id.length >= 6 && title.isNotEmpty && seen.add(id)) {
              videos.add(item(title: title, url: '$_base/watch?v=$id', image: thumb, type: 'video', description: _textValue(renderer['descriptionSnippet']), rating: _textValue(renderer['viewCountText'])));
            }
          }
          for (final value in node.values) walk(value);
        } else if (node is List) {
          for (final value in node) walk(value);
        }
      }
      walk(root);
      return videos.take(60).toList();
    } catch (_) { return []; }
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final html = await ExtensionHttp.getText(url, referer: _base);
    final playerJson = extractBalancedJson(html, 'var ytInitialPlayerResponse =') ?? extractBalancedJson(html, 'ytInitialPlayerResponse =');
    Map<String, dynamic> player = {};
    if (playerJson != null) {
      try { player = Map<String, dynamic>.from(jsonDecode(playerJson) as Map); } catch (_) {}
    }
    final videoId = Uri.parse(url).queryParameters['v'] ?? Uri.parse(url).pathSegments.last;
    final title = _textValue(player['videoDetails']?['title']) != '' ? _textValue(player['videoDetails']?['title']) : (HtmlMeta.first(html, 'og:title') ?? videoId);
    final image = (player['videoDetails']?['thumbnail'] is Map ? _thumbnail(player['videoDetails']['thumbnail']) : null) ?? HtmlMeta.first(html, 'og:image') ?? '';
    final description = _textValue(player['videoDetails']?['shortDescription']).isNotEmpty ? _textValue(player['videoDetails']?['shortDescription']) : (HtmlMeta.first(html, 'og:description') ?? '');
    return {...item(title: title, url: url, image: image, type: 'video', description: description), 'episodes': [{'id': videoId, 'title': title, 'number': 1, 'url': url}], 'video_id': videoId};
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async {
    final html = await ExtensionHttp.getText(url, referer: _base);
    final playerJson = extractBalancedJson(html, 'var ytInitialPlayerResponse =') ?? extractBalancedJson(html, 'ytInitialPlayerResponse =');
    if (playerJson == null) return null;
    try {
      final root = Map<String, dynamic>.from(jsonDecode(playerJson) as Map);
      final streaming = root['streamingData'] as Map?;
      final formats = <Map<String, dynamic>>[];
      final rawFormats = <dynamic>[
        if (streaming?['formats'] is List) ...(streaming?['formats'] as List),
        if (streaming?['adaptiveFormats'] is List) ...(streaming?['adaptiveFormats'] as List),
      ];
      for (final value in rawFormats) {
        if (value is Map && value['url'] is String) formats.add(Map<String, dynamic>.from(value));
      }
      final links = formats.map((format) {
        final height = format['height']?.toString() ?? format['qualityLabel']?.toString() ?? 'Auto';
        return {'url': format['url'].toString(), 'quality': height, 'name': 'YouTube', 'label': format['mimeType']?.toString() ?? 'Progressive', 'type': 'video'};
      }).where((link) => (link['url'] as String).isNotEmpty).toList();
      links.sort((a, b) => _quality(b['quality']).compareTo(_quality(a['quality'])));
      if (links.isEmpty) return null;
      return {'stream_url': links.first['url'], 'direct_stream_urls': links, 'headers': {'User-Agent': ExtensionHttp.userAgent, 'Referer': _base}};
    } catch (_) { return null; }
  }

  static String _textValue(dynamic node) {
    if (node is Map) {
      if (node['simpleText'] != null) return node['simpleText'].toString();
      if (node['runs'] is List) return (node['runs'] as List).map((e) => e['text']?.toString() ?? '').join();
    }
    return node?.toString() ?? '';
  }

  static String _thumbnail(dynamic node) {
    if (node is Map && node['thumbnails'] is List && (node['thumbnails'] as List).isNotEmpty) return (node['thumbnails'] as List).last['url']?.toString() ?? '';
    return '';
  }

  static int _quality(String? value) => int.tryParse((value ?? '').replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
}

class HtmlMeta {
  static String? first(String html, String property) => RegExp('<meta[^>]+(?:property|name)=["\\\']$property["\\\'][^>]+content=["\\\']([^"\\\']+)', caseSensitive: false).firstMatch(html)?.group(1);
}
