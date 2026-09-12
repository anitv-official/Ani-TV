import 'dart:convert';

import 'package:http/http.dart' as http;

import 'html_client.dart';
import 'source_base.dart';

/// Manga Slayer source backed by the API and dynamic source configuration used
/// by the official application. The parser deliberately stays isolated from
/// other source implementations.
class MangaSlayerSource extends ContentSource {
  static const _api = 'https://api.mangaslayers.com';
  static const _fallbackSite = 'https://mangaslayers.com';
  static const _userAgent = 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/128.0 Mobile Safari/537.36';
  static Map<String, dynamic>? _config;
  static DateTime? _configAt;

  @override
  String get id => 'manga_slayer';

  @override
  String get name => 'Manga Slayer';

  @override
  String get kind => 'manga';

  @override
  List<String> get hosts => ['mangaslayers.com', 'api.mangaslayers.com'];

  @override
  bool handles(String url) => url.startsWith('mangaslayer://') || super.handles(url);

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return const [];
    final response = await _request(
      'POST',
      '/manga/search?page=0&size=30',
      body: {'query': value},
    );
    final list = _asList(response);
    return list.whereType<Map>().map((e) => _mangaItem(Map<String, dynamic>.from(e))).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final response = await _request('GET', '/manga?listType=LATEST&page=${page - 1}&size=30');
    return _asList(response)
        .whereType<Map>()
        .map((e) => _mangaItem(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final id = _idFrom(url);
    if (id == null) throw Exception('تعذر تحديد المانجا من Manga Slayer');
    final raw = _asMap(await _request('GET', '/manga/detail/$id'));
    final result = _mangaItem(raw);
    result['url'] = url;
    result['manga_id'] = id;
    result['chapters'] = await _chapters(raw, id);
    return result;
  }

  @override
  Future<Map<String, dynamic>?> chapterImages(String url) async {
    final uri = Uri.tryParse(url);
    final pageUrl = uri?.queryParameters['page_url'] ??
        uri?.queryParameters['chapter_url'] ??
        (uri != null && uri.scheme == 'http' || uri?.scheme == 'https' ? url : '');
    final postId = uri?.queryParameters['post_id'] ?? uri?.queryParameters['postId'] ?? '';
    final chapter = uri?.queryParameters['chapter'] ?? '';
    if (pageUrl.isEmpty) return null;
    final config = await _sourceConfig();
    final extractor = _extractor(config, 'chapter_pages');
    if (extractor == null) return null;
    final parameters = <String, dynamic>{'postId': postId, 'chapter': chapter};
    final query = _resolveList(extractor['parameters'], parameters);
    final endpoint = _join(pageUrl, query.isEmpty ? '' : '?${query.join('&')}');
    final response = await _formPost(endpoint, _resolveMap(extractor['fields'], parameters));
    final html = _htmlFromResponse(response);
    final images = _images(html, pageUrl, extractor['root_selector']?.toString() ?? 'img');
    return images.isEmpty ? null : {'pages': images, 'images': images, 'url': url};
  }

  Future<List<Map<String, dynamic>>> _chapters(Map<String, dynamic> manga, int id) async {
    final config = await _sourceConfig();
    final extractor = _extractor(config, 'chapters');
    if (extractor == null) return const [];
    final sourceUrl = _string(manga['url'] ?? manga['sourceUrl'] ?? manga['link']);
    if (sourceUrl.isEmpty) return const [];
    final parameters = <String, dynamic>{'manga': id};
    final endpoint = _join(sourceUrl, config['ajax_endpoint']?.toString() ?? '/wp-admin/admin-ajax.php');
    final response = await _formPost(endpoint, _resolveMap(extractor['fields'], parameters));
    final html = _htmlFromResponse(response);
    final root = extractor['root_selector']?.toString() ?? 'a';
    final chapters = <Map<String, dynamic>>[];
    final pattern = RegExp('<li[^>]*class=["\'][^"\']*${RegExp.escape(root.split('.').last)}[^"\']*["\'][^>]*>([\\s\\S]*?)</li>', caseSensitive: false);
    final blocks = pattern.allMatches(html).map((m) => m.group(1) ?? '').toList();
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final href = RegExp('href=["\']([^"\']+)', caseSensitive: false).firstMatch(block)?.group(1) ?? '';
      final title = HtmlParse.stripTags(block).trim();
      if (href.isEmpty || title.isEmpty) continue;
      final number = _chapterNumber(title, blocks.length - i - 1);
      final chapterUrl = 'mangaslayer://chapter?chapter_url=${Uri.encodeComponent(HtmlParse.absUrl(sourceUrl, href))}&post_id=$id&chapter=${Uri.encodeComponent(title)}';
      chapters.add({'id': '${id}_$i', 'chapter_id': '${id}_$i', 'number': number, 'title': title, 'url': chapterUrl, 'chapter_url': chapterUrl});
    }
    return chapters;
  }

  Map<String, dynamic> _mangaItem(Map<String, dynamic> raw) {
    final title = _first(raw, ['title', 'name', 'originalTitle', 'original_title']);
    final image = _first(raw, ['poster', 'cover', 'coverUrl', 'posterUrl', 'image']);
    final id = _first(raw, ['id', '_id', 'mangaId', 'manga_id']);
    final item = this.item(title: title, url: 'mangaslayer://manga/$id', image: image, type: _first(raw, ['type', 'format']), genres: _list(raw['genres'] ?? raw['tags']), description: _first(raw, ['description', 'synopsis', 'story']), rating: _first(raw, ['rating', 'score']));
    item.addAll({'manga_id': id, 'original_title': _first(raw, ['originalTitle', 'original_title']), 'alternate_titles': _list(raw['alternateTitles'] ?? raw['alternate_titles']), 'banner_image_url': _first(raw, ['banner', 'bannerUrl']), 'author': _first(raw, ['author', 'authors']), 'artist': _first(raw, ['artist', 'artists']), 'status': _first(raw, ['storyStatus', 'status']), 'latest_chapter': raw['chapterNumber'] ?? raw['latestChapter'] ?? ''});
    return item;
  }

  Future<Map<String, dynamic>> _sourceConfig() async {
    if (_config != null && _configAt != null && DateTime.now().difference(_configAt!) < const Duration(hours: 6)) return _config!;
    final response = await _request('GET', '/source/main_source_config');
    _config = _asMap(response);
    _configAt = DateTime.now();
    return _config!;
  }

  Future<dynamic> _request(String method, String path, {Map<String, dynamic>? body}) async {
    final headers = {'Accept': 'application/json', 'Content-Type': 'application/json', 'User-Agent': _userAgent};
    final uri = Uri.parse('$_api$path');
    final response = method == 'POST' ? await http.post(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 20)) : await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('Manga Slayer request failed');
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<dynamic> _formPost(String url, Map<String, String> fields) async {
    final response = await http.post(Uri.parse(url), headers: {'User-Agent': _userAgent, 'Referer': _fallbackSite}, body: fields).timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('Manga Slayer chapter request failed');
    try { return jsonDecode(utf8.decode(response.bodyBytes)); } catch (_) { return utf8.decode(response.bodyBytes, allowMalformed: true); }
  }

  String _htmlFromResponse(dynamic value) => value is Map ? _string(value['data'] is Map ? (value['data']['content'] ?? value['data']) : (value['content'] ?? value['html'] ?? value)) : _string(value);
  List<String> _images(String html, String base, String selector) => RegExp('<img[^>]+(?:src|data-src)=["\']([^"\']+)', caseSensitive: false).allMatches(html).map((m) => HtmlParse.absUrl(base, m.group(1) ?? '')).where((u) => u.isNotEmpty).toSet().toList();
  Map<String, dynamic>? _extractor(Map<String, dynamic> config, String name) {
    for (final value in config['extractors'] as List? ?? const []) {
      if (value is Map && value['name'] == name) return Map<String, dynamic>.from(value);
    }
    return null;
  }
  Map<String, String> _resolveMap(dynamic raw, Map<String, dynamic> params) => raw is Map ? raw.map((k, v) => MapEntry(k.toString(), _resolve(v.toString(), params))) : {};
  List<String> _resolveList(dynamic raw, Map<String, dynamic> params) => raw is List ? raw.map((e) => _resolve(e.toString(), params)).toList() : [];
  String _resolve(String value, Map<String, dynamic> params) => value.replaceAllMapped(RegExp(r'\{([^}]+)\}'), (m) => _string(params[m.group(1)]));
  String _join(String base, String path) { final uri = Uri.parse(base); return uri.resolve(path).toString(); }
  int? _idFrom(String url) => int.tryParse(RegExp(r'(?:manga/|manga_id=)(\d+)').firstMatch(url)?.group(1) ?? '');
  int _chapterNumber(String title, int fallback) => int.tryParse(RegExp(r'\d+(?:\.\d+)?').firstMatch(title)?.group(0) ?? '') ?? fallback;
  List<dynamic> _asList(dynamic value) => value is List ? value : value is Map && value['data'] is List ? value['data'] : const [];
  Map<String, dynamic> _asMap(dynamic value) => value is Map ? Map<String, dynamic>.from(value['data'] is Map ? value['data'] : value) : {};
  String _first(Map<String, dynamic> raw, List<String> keys) => keys.map((k) => _string(raw[k])).firstWhere((v) => v.isNotEmpty, orElse: () => '');
  String _string(dynamic v) => v == null || v is Map || v is List ? '' : v.toString().trim();
  List<dynamic> _list(dynamic v) => v is List ? v : v is String ? v.split(RegExp(r'[,،]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList() : const [];
}
