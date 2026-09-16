import 'dart:convert';

import 'package:http/http.dart' as http;

import 'html_client.dart';
import 'source_base.dart';

/// Manga Slayer adapter. The API supplies catalog data and a remote source
/// configuration; the configured WordPress endpoints supply chapters/pages.
class MangaSlayerSource extends ContentSource {
  static const _api = 'https://api.mangaslayers.com';
  static const _apiKey = 'dd2eb612-b6df-4db6-a90c-3fe484270750';
  static const _userAgent = 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/128.0 Mobile Safari/537.36';
  static Map<String, dynamic>? _config;
  static DateTime? _configAt;

  @override String get id => 'manga_slayer';
  @override String get name => 'Manga Slayer';
  @override String get kind => 'manga';
  @override List<String> get hosts => ['mangaslayers.com', 'api.mangaslayers.com', 'sparkmanga.net', 'link-manga.net'];
  @override bool handles(String url) => url.startsWith('mangaslayer://') || super.handles(url);

  Map<String, dynamic> _searchBody(String query) => {
        'query': query, 'status': null, 'format': null, 'year': null,
        'yearRange': null, 'chapterCountRange': null, 'countryOrigin': null,
        'source': null, 'genres': null, 'tags': null,
      };

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return const [];
    final response = await _apiRequest('POST', '/manga/search?page=1&size=30', body: _searchBody(value));
    await _sourceConfig();
    return _asList(response).whereType<Map>().map((raw) => _mangaItem(Map<String, dynamic>.from(raw))).where(_validItem).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    try {
      final response = await _apiRequest('GET', '/manga?listType=LATEST&page=$page&size=30');
      await _sourceConfig();
      final items = _asList(response).whereType<Map>().map((raw) => _mangaItem(Map<String, dynamic>.from(raw))).where(_validItem).toList();
      if (items.isNotEmpty) return items;
    } catch (_) {}

    // The latest endpoint has returned 500 before. Search fallback uses the
    // complete request schema, not an abbreviated body the API rejects.
    final seen = <String>{};
    final fallback = <Map<String, dynamic>>[];
    for (final term in const ['a', 'm', 'e']) {
      try {
        final response = await _apiRequest('POST', '/manga/search?page=$page&size=30', body: _searchBody(term));
        for (final raw in _asList(response).whereType<Map>()) {
          final item = _mangaItem(Map<String, dynamic>.from(raw));
          final key = '${item['manga_id'] ?? ''}|${item['title'] ?? ''}';
          if (_validItem(item) && seen.add(key)) fallback.add(item);
        }
      } catch (_) {}
      if (fallback.length >= 30) break;
    }
    await _sourceConfig();
    return fallback.take(30).toList();
  }

  bool _validItem(Map<String, dynamic> item) => (item['manga_id']?.toString() ?? '').isNotEmpty && (item['title']?.toString() ?? '').trim().isNotEmpty;

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final id = _idFrom(url);
    if (id == null) throw Exception('تعذر تحديد المانجا من Manga Slayer');
    final raw = _asMap(await _apiRequest('GET', '/manga/detail/$id'));
    await _sourceConfig();
    final result = _mangaItem(raw);
    result['url'] = url;
    result['manga_id'] = id;
    result['chapters'] = await _chapters(id);
    return result;
  }

  @override
  Future<Map<String, dynamic>?> chapterImages(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'mangaslayer') return null;
    final chapterUrl = uri.queryParameters['chapter_url'] ?? '';
    final postId = uri.queryParameters['post_id'] ?? '';
    final chapter = uri.queryParameters['chapter'] ?? _chapterSlug(chapterUrl);
    if (chapterUrl.isEmpty || postId.isEmpty || chapter.isEmpty) return null;

    final config = await _sourceConfig();
    final extractor = _extractor(config, 'chapter_pages');
    if (extractor == null) throw Exception('Manga Slayer: إعداد صفحات الفصول غير متاح');
    final parameters = <String, dynamic>{'postId': int.tryParse(postId) ?? postId, 'chapter': chapter};
    final query = _resolveList(extractor['parameters'], parameters);
    final fields = _resolveMap(extractor['fields'], parameters);
    final response = await _sourcePost(config, query.isEmpty ? _ajaxUrl(config) : '${_ajaxUrl(config)}?${query.join('&')}', fields);
    var html = _htmlFromResponse(response);
    var images = _images(html, chapterUrl, extractor['root_selector']?.toString() ?? 'img', extractor);
    if (images.isEmpty) {
      final retry = await _sourcePost(config, '${_ajaxUrl(config)}?postID=${Uri.encodeQueryComponent(postId)}&manga-paged=1&chapter=${Uri.encodeQueryComponent(chapter)}&style=list', fields);
      html = _htmlFromResponse(retry);
      images = _images(html, chapterUrl, extractor['root_selector']?.toString() ?? 'img', extractor);
    }
    if (images.isEmpty) throw Exception('Manga Slayer: لم يتم العثور على صفحات الفصل');
    return {'pages': images, 'images': images.map((image) => {'url': image}).toList(), 'url': url};
  }

  Future<List<Map<String, dynamic>>> _chapters(int mangaId) async {
    final config = await _sourceConfig();
    final extractor = _extractor(config, 'chapters');
    if (extractor == null) return const [];
    final response = await _sourcePost(config, _ajaxUrl(config), _resolveMap(extractor['fields'], {'manga': mangaId}));
    final html = _htmlFromResponse(response);
    final classNames = _selectorClasses(extractor['root_selector']?.toString() ?? 'li.wp-manga-chapter');
    final pattern = RegExp(r'<li[^>]*class=["\'][^"\']*["\'][^>]*>([\s\S]*?)</li>', caseSensitive: false);
    final blocks = <String>[];
    for (final match in pattern.allMatches(html)) {
      final full = match.group(0) ?? '';
      final classes = _classNames(full);
      if (classNames.isEmpty || classNames.every(classes.contains)) blocks.add(match.group(1) ?? '');
    }
    final domain = _configDomain(config);
    final result = <Map<String, dynamic>>[];
    for (var index = 0; index < blocks.length; index++) {
      final block = blocks[index];
      final href = RegExp(r'''href=["']([^"']+)''', caseSensitive: false).firstMatch(block)?.group(1) ?? '';
      final rawTitle = RegExp(r'<a[^>]*>([\s\S]*?)</a>', caseSensitive: false).firstMatch(block)?.group(1) ?? block;
      final title = _normalizeChapterTitle(HtmlParse.stripTags(rawTitle));
      final releaseDate = RegExp(r'<(?:i|span)[^>]*>([\s\S]*?)</(?:i|span)>', caseSensitive: false).firstMatch(block)?.group(1) ?? '';
      if (href.isEmpty || title.isEmpty) continue;
      final absolute = HtmlParse.absUrl('https://$domain/', href);
      final number = _chapterNumber(title, blocks.length - index - 1);
      final chapterId = _chapterSlug(absolute);
      final internalUrl = 'mangaslayer://chapter?chapter_url=${Uri.encodeComponent(absolute)}&post_id=$mangaId&chapter=${Uri.encodeComponent(chapterId)}';
      result.add({'id': chapterId, 'chapter_id': chapterId, 'chapter_number': number, 'number': number, 'title': title, 'url': internalUrl, 'chapter_url': absolute, 'release_date': HtmlParse.stripTags(releaseDate)});
    }
    return result;
  }

  Map<String, dynamic> _mangaItem(Map<String, dynamic> raw) {
    final id = raw['_id'] ?? raw['id'] ?? raw['mangaId'] ?? raw['manga_id'];
    final titles = raw['titles'];
    final poster = raw['poster'];
    final title = _firstValue([raw['title'], titles is Map ? titles['native'] : null, titles is Map ? titles['english'] : null, titles is Map ? titles['romaji'] : null, raw['name']]);
    final image = _firstValue([raw['poster'], raw['cover'], raw['coverUrl'], raw['posterUrl'], poster is Map ? poster['sourcePoster'] : null, poster is Map ? poster['aniPoster'] : null]);
    final item = this.item(title: title, url: 'mangaslayer://manga/$id', image: _absoluteImage(image), type: _formatType(raw['format'] ?? raw['type']), genres: _list(raw['genre'] ?? raw['genres'] ?? raw['tags']), description: _firstValue([raw['overview'], raw['description'], raw['synopsis'], raw['story']]), rating: _firstValue([raw['score'], raw['rating'], raw['mangaMainScore']]));
    item.addAll({'manga_id': id, 'original_title': _firstValue([titles is Map ? titles['native'] : null, raw['originalTitle'], raw['original_title']]), 'alternate_titles': _list(raw['synonyms'] ?? raw['alternateTitles'] ?? raw['alternate_titles']), 'banner_image_url': _absoluteImage(_firstValue([raw['bannerImage'], raw['banner'], raw['bannerUrl']])), 'author': _firstValue([raw['author'], raw['authors']]), 'artist': _firstValue([raw['artist'], raw['artists']]), 'status': _status(raw['status']), 'year': _firstValue([raw['started'], raw['year']]), 'latest_chapter': raw['latestChapter'] ?? raw['chapterNumber'] ?? '', 'total_chapters': raw['chapters'] ?? ''});
    return item;
  }

  Future<Map<String, dynamic>> _sourceConfig() async {
    if (_config != null && _configAt != null && DateTime.now().difference(_configAt!) < const Duration(hours: 6)) return _config!;
    try {
      final config = _asMap(await _apiRequest('GET', '/source/main_source_config'));
      if (config.isNotEmpty) { _config = config; _configAt = DateTime.now(); }
    } catch (_) {}
    return _config ?? <String, dynamic>{};
  }

  Future<dynamic> _apiRequest(String method, String path, {Map<String, dynamic>? body}) async {
    final headers = {'Accept': 'application/json', 'Content-Type': 'application/json', 'User-Agent': _userAgent, 'X-Api-Key': _apiKey};
    final response = method == 'POST' ? await http.post(Uri.parse('$_api$path'), headers: headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 20)) : await http.get(Uri.parse('$_api$path'), headers: headers).timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('Manga Slayer request failed (${response.statusCode})');
    final decoded = utf8.decode(response.bodyBytes, allowMalformed: true);
    try { return jsonDecode(decoded); } catch (_) { throw Exception('Manga Slayer returned invalid data'); }
  }

  Future<dynamic> _sourcePost(Map<String, dynamic> config, String url, Map<String, String> fields) async {
    final domain = _configDomain(config);
    final response = await http.post(Uri.parse(url), headers: {'User-Agent': _userAgent, 'Accept': 'text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8', 'Accept-Language': 'ar,en-US;q=0.9,en;q=0.8', 'Origin': 'https://$domain', 'Referer': 'https://$domain/'}, body: fields).timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('Manga Slayer source request failed (${response.statusCode})');
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    try { return jsonDecode(text); } catch (_) { return text; }
  }

  String _ajaxUrl(Map<String, dynamic> config) { final domain = _configDomain(config); final endpoint = config['ajax_endpoint']?.toString() ?? '/wp-admin/admin-ajax.php'; return 'https://$domain${endpoint.startsWith('/') ? endpoint : '/$endpoint'}'; }
  String _configDomain(Map<String, dynamic> config) { final value = _string((config['source'] as Map?)?['domain']); return value.isNotEmpty ? value.replaceFirst(RegExp(r'^https?://'), '').replaceFirst(RegExp(r'/$'), '') : 'sparkmanga.net'; }
  String _htmlFromResponse(dynamic value) { var current = value; for (var depth = 0; depth < 6; depth++) { if (current is Map && current['content'] != null) current = current['content']; else if (current is Map && current.containsKey('data')) current = current['data']; else break; } return _string(current); }

  List<String> _images(String html, String base, String selector, Map<String, dynamic> extractor) {
    final urls = <String>{};
    final requiredClasses = _selectorClasses(selector);
    for (final tagMatch in RegExp(r'<img\b[^>]*>', caseSensitive: false).allMatches(html)) {
      final tag = tagMatch.group(0) ?? '';
      final classes = _classNames(tag);
      if (requiredClasses.isNotEmpty && !requiredClasses.every(classes.contains)) continue;
      var raw = _attribute(tag, 'data-src') ?? _attribute(tag, 'data-lazy-src') ?? _attribute(tag, 'data-original') ?? _attribute(tag, 'data-url') ?? _attribute(tag, 'src') ?? '';
      if (raw.isEmpty) raw = (_attribute(tag, 'srcset') ?? '').split(',').first.trim().split(' ').first;
      if (raw.isEmpty || raw.startsWith('data:image')) continue;
      var url = HtmlParse.absUrl(base, _normalizeUrl(raw));
      url = _transformUrl(url, extractor['url_transformations']);
      if (url.isNotEmpty) urls.add(url);
    }
    return urls.toList();
  }

  static String? _attribute(String tag, String name) => RegExp('\\b${RegExp.escape(name)}=["\\\']([^"\\\']+)', caseSensitive: false).firstMatch(tag)?.group(1);
  static Set<String> _classNames(String html) => ((_attribute(html, 'class') ?? '').split(RegExp(r'\s+'))..removeWhere((e) => e.isEmpty)).toSet();
  static Set<String> _selectorClasses(String selector) => RegExp(r'\.([A-Za-z0-9_-]+)').allMatches(selector).map((m) => m.group(1)!).toSet();
  static String _normalizeUrl(String value) => value.replaceAll('&amp;', '&').replaceAll(r'\/', '/').replaceAll(r'\u0026', '&').trim();
  String _transformUrl(String url, dynamic transformations) { var result = url; if (transformations is List) for (final t in transformations.whereType<Map>()) { final pattern = _string(t['pattern']); if (t['type'] == 'REGEX_REPLACE' && pattern.isNotEmpty) result = result.replaceFirst(RegExp(pattern), _string(t['replacement'])); } return result; }
  Map<String, dynamic>? _extractor(Map<String, dynamic> config, String name) { for (final value in config['extractors'] as List? ?? const []) { if (value is Map && value['name'] == name) return Map<String, dynamic>.from(value); } return null; }
  Map<String, String> _resolveMap(dynamic raw, Map<String, dynamic> params) => raw is Map ? raw.map((key, value) => MapEntry(key.toString(), _resolve(value.toString(), params))) : {};
  List<String> _resolveList(dynamic raw, Map<String, dynamic> params) => raw is List ? raw.map((value) => _resolve(value.toString(), params)).toList() : [];
  String _resolve(String value, Map<String, dynamic> params) => value.replaceAllMapped(RegExp(r'\{([^}]+)\}'), (m) => _string(params[m.group(1)]));
  int? _idFrom(String url) => int.tryParse(RegExp(r'(?:manga/|manga_id=)(\d+)').firstMatch(url)?.group(1) ?? '');
  String _chapterSlug(String url) { final parts = Uri.tryParse(url)?.pathSegments ?? const []; return parts.isEmpty ? '' : parts.last; }
  int _chapterNumber(String title, int fallback) { final normalized = _arabicDigits(title); final match = RegExp(r'\d+(?:\.\d+)?').firstMatch(normalized); return int.tryParse(match?.group(0) ?? '') ?? fallback; }
  String _arabicDigits(String value) => value.split('').map((c) => '٠١٢٣٤٥٦٧٨٩'.indexOf(c) >= 0 ? '٠١٢٣٤٥٦٧٨٩'.indexOf(c).toString() : c).join();
  String _normalizeChapterTitle(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();
  List<dynamic> _asList(dynamic value) { if (value is List) return value; if (value is Map) { for (final key in ['data', 'items', 'results', 'manga', 'records', 'rows']) { final nested = value[key]; final result = _asList(nested); if (result.isNotEmpty) return result; } } return const []; }
  Map<String, dynamic> _asMap(dynamic value) { if (value is! Map) return {}; final data = value['data']; if (data is Map) return Map<String, dynamic>.from(data); return Map<String, dynamic>.from(value); }
  String _firstValue(Iterable<dynamic> values) { for (final value in values) { final text = _string(value); if (text.isNotEmpty) return text; } return ''; }
  String _absoluteImage(String value) { if (value.isEmpty || Uri.tryParse(value)?.hasScheme == true) return value; final sourceImage = _config?['source_image'] as Map?; final domain = _string(sourceImage?['image_domain']).isNotEmpty ? _string(sourceImage?['image_domain']) : 'mangaslayers.com'; final path = _string(sourceImage?['image_path']); return HtmlParse.absUrl('https://$domain${path.isEmpty ? '/' : path}', value); }
  String _formatType(dynamic value) { final text = _string(value).toLowerCase(); return text.isEmpty ? 'manga' : (text == '1' ? 'manga' : text); }
  String _status(dynamic value) => value is num ? value.toString() : _string(value);
  String _string(dynamic value) => value == null || value is Map || value is List ? '' : value.toString().trim();
  List<dynamic> _list(dynamic value) => value is List ? value : value is String ? value.split(RegExp(r'[,،]')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList() : const [];
}
