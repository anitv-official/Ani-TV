import 'dart:convert';

import 'package:http/http.dart' as http;

import 'html_client.dart';
import 'source_base.dart';

/// Clean Manga Slayer adapter.
/// Catalog data comes from the Manga Slayer API; chapters and pages are
/// extracted from the configured Lek-Manga WordPress source.
class MangaSlayerSource extends ContentSource {
  static const _api = 'https://api.mangaslayers.com';
  static const _apiKey = 'dd2eb612-b6df-4db6-a90c-3fe484270750';
  static const _defaultSource = 'sparkmanga.net';
  static const _defaultImageHost = 'io.lek-manga.net';

  Map<String, dynamic>? _sourceConfig;

  @override String get id => 'manga_slayer';
  @override String get name => 'Manga Slayer';
  @override String get kind => 'manga';
  @override List<String> get hosts => const ['mangaslayers.com', 'api.mangaslayers.com', 'sparkmanga.net', 'link-manga.net', 'lek-manga.net'];
  @override bool handles(String url) => url.startsWith('mangaslayer://') || super.handles(url);

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return const [];
    final response = await _request('POST', '/manga/search?page=1&size=30', body: {
      'query': value, 'status': null, 'format': null, 'year': null,
      'yearRange': null, 'chapterCountRange': null, 'countryOrigin': null,
      'source': null, 'genres': null, 'tags': null,
    });
    return _rows(response).map(_mapManga).where(_valid).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final response = await _request('GET', '/manga?listType=LATEST&page=${page < 1 ? 1 : page}&size=30');
    return _rows(response).map(_mapManga).where(_valid).toList();
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final id = _idFrom(url);
    if (id == null) throw Exception('Manga Slayer: invalid manga id');
    final raw = _asMap(await _request('GET', '/manga/detail/$id'));
    if (raw.isEmpty) throw Exception('Manga Slayer: manga not found');
    final result = _mapManga(raw);
    result['url'] = 'mangaslayer://manga/$id';
    result['manga_id'] = id;
    result['chapters'] = await _loadChapters(id);
    return result;
  }

  @override
  Future<Map<String, dynamic>?> chapterImages(String url) async {
    final chapter = _chapterFrom(url);
    if (chapter == null) throw Exception('Manga Slayer: invalid chapter URL');
    final config = await _loadConfig();
    final extractor = _extractor(config, 'chapter_pages');
    if (extractor == null) throw Exception('Manga Slayer: chapter extractor unavailable');
    final params = <String, dynamic>{'postId': chapter.postId, 'chapter': chapter.slug};
    final fields = _resolveMap(extractor['fields'], params);
    final query = _resolveList(extractor['parameters'], params).join('&');
    final endpoint = _ajaxUrl(config);
    final response = await _requestLek('$endpoint${query.isEmpty ? '' : '?$query'}', fields);
    var images = _extractImages(_html(response), chapter.pageUrl, extractor);
    if (images.isEmpty) {
      final retry = await _requestLek('$endpoint?postID=${Uri.encodeQueryComponent(chapter.postId)}&manga-paged=1&chapter=${Uri.encodeQueryComponent(chapter.slug)}&style=list', fields);
      images = _extractImages(_html(retry), chapter.pageUrl, extractor);
    }
    if (images.isEmpty) throw Exception('Manga Slayer: no chapter pages found');
    return {'title': chapter.title, 'images': images.map((url) => {'url': url}).toList(), 'pages': images, 'url': url};
  }

  Future<List<Map<String, dynamic>>> _loadChapters(int mangaId) async {
    final config = await _loadConfig();
    final extractor = _extractor(config, 'chapters');
    if (extractor == null) return const [];
    final fields = _resolveMap(extractor['fields'], {'manga': mangaId});
    final response = await _requestLek(_ajaxUrl(config), fields);
    final html = _html(response);
    final selector = extractor['root_selector']?.toString() ?? 'li.wp-manga-chapter';
    final blocks = <String>[];
    for (final match in RegExp(r'<li[^>]*class=["\x27][^"\x27]*["\x27][^>]*>[\s\S]*?</li>', caseSensitive: false).allMatches(html)) {
      final block = match.group(0)!;
      if (_selectorClasses(selector).every(_classes(block).contains)) blocks.add(block);
    }
    final result = <Map<String, dynamic>>[];
    for (var index = 0; index < blocks.length; index++) {
      final block = blocks[index];
      final href = _attr(block, 'href') ?? '';
      final title = HtmlParse.stripTags(RegExp(r'<a[^>]*>([\s\S]*?)</a>', caseSensitive: false).firstMatch(block)?.group(1) ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (href.isEmpty || title.isEmpty) continue;
      final absolute = HtmlParse.absUrl(_site(config), href);
      final slug = _lastSegment(absolute);
      final number = _chapterNumber(title, blocks.length - index - 1);
      final release = RegExp(r'<(?:i|span)[^>]*>([\s\S]*?)</(?:i|span)>', caseSensitive: false).firstMatch(block)?.group(1) ?? '';
      final internal = _chapterUrl(mangaId, absolute, slug, title, number);
      result.add({'id': slug, 'chapter_id': slug, 'chapter_number': number, 'number': number, 'title': title, 'url': internal, 'chapter_url': absolute, 'release_date': HtmlParse.stripTags(release)});
    }
    result.sort((a, b) => (b['number'] as int).compareTo(a['number'] as int));
    return result;
  }

  Map<String, dynamic> _mapManga(Map<String, dynamic> raw) {
    final id = raw['_id'] ?? raw['id'] ?? raw['mangaId'] ?? raw['manga_id'];
    final titles = raw['titles'];
    final poster = raw['poster'];
    final image = _first([poster is Map ? poster['sourcePoster'] : null, poster is Map ? poster['aniPoster'] : null, raw['cover'], raw['poster']]);
    final description = _first([raw['overview'], raw['description'], raw['synopsis'], raw['story']]);
    final item = this.item(title: _first([raw['title'], raw['name']]), url: 'mangaslayer://manga/$id', image: _image(image), type: _type(raw['format'] ?? raw['type']), genres: _list(raw['genre'] ?? raw['genres'] ?? raw['tags']), description: description, rating: _first([raw['score'], raw['rating'], raw['mangaMainScore']]));
    item.addAll({'manga_id': id, 'alternate_titles': _list(raw['synonyms'] ?? raw['alternateTitles'] ?? raw['alternate_titles']), 'original_title': _first([titles is Map ? titles['native'] : null, raw['originalTitle']]), 'author': _first([raw['author'], raw['authors']]), 'artist': _first([raw['artist'], raw['artists']]), 'status': _status(raw['status']), 'year': _first([raw['started'], raw['year']]), 'banner_image_url': _image(raw['bannerImage'] ?? raw['bannerUrl']), 'total_chapters': raw['chapters'] ?? raw['chapterCount'] ?? ''});
    return item;
  }

  Future<Map<String, dynamic>> _loadConfig() async {
    if (_sourceConfig != null) return _sourceConfig!;
    final raw = await _request('GET', '/source/main_source_config');
    _sourceConfig = _asMap(raw);
    return _sourceConfig!;
  }

  Future<dynamic> _request(String method, String path, {Map<String, dynamic>? body}) async {
    final headers = const {'Accept': 'application/json', 'Content-Type': 'application/json', 'X-Api-Key': _apiKey, 'User-Agent': 'AniTV/1.0'};
    final response = method == 'POST' ? await http.post(Uri.parse('$_api$path'), headers: headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 25)) : await http.get(Uri.parse('$_api$path'), headers: headers).timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('Manga Slayer request failed (${response.statusCode})');
    return jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
  }

  Future<dynamic> _requestLek(String url, Map<String, String> fields) async {
    final response = await http.post(Uri.parse(url), headers: {'Accept': 'text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8', 'Origin': _site(await _loadConfig()), 'Referer': '${_site(await _loadConfig())}/', 'User-Agent': 'Mozilla/5.0'}, body: fields).timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('Manga Slayer chapter request failed (${response.statusCode})');
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    try { return jsonDecode(text); } catch (_) { return text; }
  }

  List<String> _extractImages(String html, String base, Map<String, dynamic> extractor) {
    final selector = extractor['root_selector']?.toString() ?? 'img';
    final required = _selectorClasses(selector);
    final result = <String>{};
    for (final match in RegExp(r'<img\b[^>]*>', caseSensitive: false).allMatches(html)) {
      final tag = match.group(0)!;
      if (required.isNotEmpty && !required.every(_classes(tag).contains)) continue;
      final raw = (_attr(tag, 'data-src') ?? _attr(tag, 'data-lazy-src') ?? _attr(tag, 'data-original') ?? _attr(tag, 'src') ?? '').trim();
      if (raw.isEmpty || raw.startsWith('data:')) continue;
      var url = HtmlParse.absUrl(base, raw.replaceAll('&amp;', '&'));
      for (final transform in (extractor['url_transformations'] as List? ?? const []).whereType<Map>()) {
        if (transform['type'] == 'REGEX_REPLACE') url = url.replaceFirst(RegExp(transform['pattern'].toString()), transform['replacement']?.toString() ?? '');
      }
      if (Uri.tryParse(url)?.hasScheme == true) result.add(url);
    }
    return result.toList();
  }

  static dynamic _unwrap(dynamic value) { var current = value; for (var i = 0; i < 5; i++) { if (current is Map && current['data'] != null) current = current['data']; else if (current is Map && current['content'] != null) current = current['content']; else break; } return current; }
  static List<Map<String, dynamic>> _rows(dynamic value) { final v = _unwrap(value); if (v is List) return v.whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList(); if (v is Map) { for (final k in ['items', 'results', 'manga', 'records', 'rows']) { final rows = _rows(v[k]); if (rows.isNotEmpty) return rows; } } return const []; }
  static Map<String, dynamic> _asMap(dynamic value) => value is Map ? Map<String, dynamic>.from(_unwrap(value) as Map) : <String, dynamic>{};
  static String _html(dynamic value) { var v = value; for (var i = 0; i < 5; i++) { if (v is Map && v['content'] != null) v = v['content']; else if (v is Map && v['data'] != null) v = v['data']; else break; } return v?.toString() ?? ''; }
  static bool _valid(Map<String, dynamic> item) => item['manga_id'].toString().isNotEmpty && item['title'].toString().trim().isNotEmpty;
  static String _first(Iterable<dynamic> values) => values.map((v) => v is Map || v is List || v == null ? '' : v.toString().trim()).firstWhere((v) => v.isNotEmpty, orElse: () => '');
  static List<dynamic> _list(dynamic value) => value is List ? value : value is String ? value.split(RegExp(r'[,،]')).map((x) => x.trim()).where((x) => x.isNotEmpty).toList() : const [];
  static String _image(dynamic value) { final raw = _first([value]); if (raw.isEmpty) return ''; return raw.startsWith('http') ? raw : 'https://$_defaultImageHost/wp-content/uploads/${raw.replaceFirst(RegExp(r'^/+'), '')}'; }
  static String _type(dynamic value) => _first([value]).isEmpty ? 'manga' : _first([value]);
  static String _status(dynamic value) => value is num ? value.toString() : _first([value]);
  static int? _idFrom(String url) => int.tryParse(RegExp(r'(?:manga/|manga_id=)(\d+)').firstMatch(url)?.group(1) ?? '');
  static String _site(Map<String, dynamic> config) => '${config['source'] is Map ? (config['source'] as Map)['scheme'] ?? 'https' : 'https'}://${config['source'] is Map ? (config['source'] as Map)['domain'] ?? _defaultSource : _defaultSource}';
  static String _ajaxUrl(Map<String, dynamic> config) => '${_site(config)}${(_first([config['ajax_endpoint']])).replaceFirst(RegExp(r'^(?!/)'), '/')}';
  static Map<String, dynamic>? _extractor(Map<String, dynamic> config, String name) {
    for (final value in config['extractors'] as List? ?? const []) {
      if (value is Map && value['name'] == name) return Map<String, dynamic>.from(value);
    }
    return null;
  }
  static Map<String, String> _resolveMap(dynamic value, Map<String, dynamic> params) => value is Map ? value.map((k, v) => MapEntry(k.toString(), _resolve(v.toString(), params))) : {};
  static List<String> _resolveList(dynamic value, Map<String, dynamic> params) => value is List ? value.map((v) => _resolve(v.toString(), params)).toList() : const [];
  static String _resolve(String value, Map<String, dynamic> params) => value.replaceAllMapped(RegExp(r'\{([^}]+)\}'), (m) => params[m.group(1)]?.toString() ?? '');
  static String _attr(String html, String name) => RegExp('\\b${RegExp.escape(name)}=["\\x27]([^"\\x27]+)', caseSensitive: false).firstMatch(html)?.group(1) ?? '';
  static Set<String> _classes(String html) => _attr(html, 'class').split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toSet();
  static Set<String> _selectorClasses(String selector) => RegExp(r'\.([A-Za-z0-9_-]+)').allMatches(selector).map((m) => m.group(1)!).toSet();
  static String _lastSegment(String url) => (Uri.tryParse(url)?.pathSegments.where((x) => x.isNotEmpty).toList() ?? const []).lastOrNull ?? '';
  static int _chapterNumber(String title, int fallback) => int.tryParse(RegExp(r'\d+(?:\.\d+)?').firstMatch(title)?.group(0) ?? '') ?? fallback;
  static String _chapterUrl(int postId, String pageUrl, String slug, String title, int number) => 'mangaslayer://chapter?post_id=$postId&chapter=${Uri.encodeQueryComponent(slug)}&chapter_url=${Uri.encodeQueryComponent(pageUrl)}&title=${Uri.encodeQueryComponent(title)}&number=$number';
  _Chapter? _chapterFrom(String url) { final uri = Uri.tryParse(url); if (uri?.scheme != 'mangaslayer' || uri?.host != 'chapter') return null; final q = uri!.queryParameters; final postId = q['post_id'] ?? ''; final pageUrl = q['chapter_url'] ?? ''; final slug = q['chapter'] ?? ''; if (postId.isEmpty || pageUrl.isEmpty || slug.isEmpty) return null; return _Chapter(postId, pageUrl, slug, q['title'] ?? 'الفصل', q['number'] ?? ''); }
}

class _Chapter {
  final String postId, pageUrl, slug, title, number;
  _Chapter(this.postId, this.pageUrl, this.slug, this.title, this.number);
}

extension _LastOrNull<T> on List<T> {
  T? get lastOrNull => isEmpty ? null : last;
}
