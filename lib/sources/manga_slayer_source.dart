import 'dart:convert';

import 'package:http/http.dart' as http;

import 'html_client.dart';
import 'source_base.dart';

/// Manga Slayer adapter. API DTO mapping and the dynamic WordPress extractor
/// are intentionally isolated here so other sources keep their contracts.
class MangaSlayerSource extends ContentSource {
  static const _api = 'https://api.mangaslayers.com';
  static const _apiKey = 'dd2eb612-b6df-4db6-a90c-3fe484270750';
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
  List<String> get hosts => ['mangaslayers.com', 'api.mangaslayers.com', 'sparkmanga.net', 'link-manga.net'];

  @override
  bool handles(String url) => url.startsWith('mangaslayer://') || super.handles(url);

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return const [];
    final response = await _apiRequest(
      'POST',
      '/manga/search?page=1&size=30',
      body: {
        'query': value,
        'status': null,
        'format': null,
        'year': null,
        'yearRange': null,
        'chapterCountRange': null,
        'countryOrigin': null,
        'source': null,
        'genres': null,
        'tags': null,
      },
    );
    await _sourceConfig();
    return _asList(response)
        .whereType<Map>()
        .map((raw) => _mangaItem(Map<String, dynamic>.from(raw)))
        .where((item) => (item['manga_id']?.toString() ?? '').isNotEmpty && (item['title']?.toString() ?? '').isNotEmpty)
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final response = await _apiRequest('GET', '/manga?listType=LATEST&page=$page&size=30');
    await _sourceConfig();
    return _asList(response)
        .whereType<Map>()
        .map((raw) => _mangaItem(Map<String, dynamic>.from(raw)))
        .toList();
  }

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
    if (extractor == null) return null;
    final parameters = <String, dynamic>{'postId': int.tryParse(postId) ?? postId, 'chapter': chapter};
    final query = _resolveList(extractor['parameters'], parameters);
    final response = await _sourcePost(
      config,
      query.isEmpty ? _ajaxUrl(config) : '${_ajaxUrl(config)}?${query.join('&')}',
      _resolveMap(extractor['fields'], parameters),
    );
    final html = _htmlFromResponse(response);
    final images = _images(html, chapterUrl, extractor['root_selector']?.toString() ?? 'img', config, extractor);
    final imageEntries = images.map((image) => <String, dynamic>{'url': image}).toList();
    return images.isEmpty ? null : {'pages': images, 'images': imageEntries, 'url': url};
  }

  Future<List<Map<String, dynamic>>> _chapters(int mangaId) async {
    final config = await _sourceConfig();
    final extractor = _extractor(config, 'chapters');
    if (extractor == null) return const [];
    final response = await _sourcePost(
      config,
      _ajaxUrl(config),
      _resolveMap(extractor['fields'], {'manga': mangaId}),
    );
    final html = _htmlFromResponse(response);
    // The reference APK uses a CSS selector over the returned HTML.  Keep the
    // equivalent class extraction here, but do not depend on the exact outer
    // <ul> markup because the source has changed whitespace/attributes over
    // time.
    final root = extractor['root_selector']?.toString() ?? 'li.wp-manga-chapter';
    final className = root.split('.').last.trim();
    final pattern = RegExp(
      '<li[^>]*class=["\\\'][^"\\\']*${RegExp.escape(className)}[^"\\\']*["\\\'][^>]*>([\\s\\S]*?)</li>',
      caseSensitive: false,
    );
    final blocks = pattern.allMatches(html).map((match) => match.group(1) ?? '').toList();
    final domain = _configDomain(config);
    final result = <Map<String, dynamic>>[];
    for (var index = 0; index < blocks.length; index++) {
      final block = blocks[index];
      final href = RegExp('href=["\\\']([^"\\\']+)', caseSensitive: false).firstMatch(block)?.group(1) ?? '';
      final rawTitle = RegExp('<a[^>]*>([\\s\\S]*?)</a>', caseSensitive: false).firstMatch(block)?.group(1) ?? block;
      final title = _normalizeChapterTitle(HtmlParse.stripTags(rawTitle));
      final releaseDate = RegExp('<(?:i|span)[^>]*>([\\s\\S]*?)</(?:i|span)>', caseSensitive: false).firstMatch(block)?.group(1) ?? '';
      if (href.isEmpty || title.isEmpty) continue;
      final absolute = HtmlParse.absUrl('https://$domain/', href);
      // APK behavior: chapter numbers are read from Arabic/Latin digits and
      // fall back to the site's displayed order when a title has no number.
      final number = _chapterNumber(title, blocks.length - index - 1);
      final chapterId = _chapterSlug(absolute);
      final internalUrl = 'mangaslayer://chapter?chapter_url=${Uri.encodeComponent(absolute)}&post_id=$mangaId&chapter=${Uri.encodeComponent(chapterId)}';
      result.add({
        'id': chapterId,
        'chapter_id': chapterId,
        'chapter_number': number,
        'number': number,
        'title': title,
        'url': internalUrl,
        'chapter_url': absolute,
        'release_date': HtmlParse.stripTags(releaseDate),
      });
    }
    return result;
  }

  Map<String, dynamic> _mangaItem(Map<String, dynamic> raw) {
    final id = raw['_id'] ?? raw['id'] ?? raw['mangaId'] ?? raw['manga_id'];
    final titleObject = raw['titles'];
    final posterObject = raw['poster'];
    final image = _firstValue([
      raw['poster'],
      raw['cover'],
      raw['coverUrl'],
      raw['posterUrl'],
      posterObject is Map ? posterObject['sourcePoster'] : null,
      posterObject is Map ? posterObject['aniPoster'] : null,
    ]);
    final title = _firstValue([
      raw['title'],
      titleObject is Map ? titleObject['native'] : null,
      titleObject is Map ? titleObject['english'] : null,
      titleObject is Map ? titleObject['romaji'] : null,
      raw['name'],
    ]);
    final item = this.item(
      title: title,
      url: 'mangaslayer://manga/$id',
      image: _absoluteImage(image),
      type: _formatType(raw['format'] ?? raw['type']),
      genres: _list(raw['genre'] ?? raw['genres'] ?? raw['tags']),
      description: _firstValue([raw['overview'], raw['description'], raw['synopsis'], raw['story']]),
      rating: _firstValue([raw['score'], raw['rating'], raw['mangaMainScore']]),
    );
    item.addAll({
      'manga_id': id,
      'original_title': _firstValue([titleObject is Map ? titleObject['native'] : null, raw['originalTitle'], raw['original_title']]),
      'alternate_titles': _list(raw['synonyms'] ?? raw['alternateTitles'] ?? raw['alternate_titles']),
      'banner_image_url': _absoluteImage(_firstValue([raw['bannerImage'], raw['banner'], raw['bannerUrl']])),
      'author': _firstValue([raw['author'], raw['authors']]),
      'artist': _firstValue([raw['artist'], raw['artists']]),
      'status': _status(raw['status']),
      'year': _firstValue([raw['started'], raw['year']]),
      'latest_chapter': raw['latestChapter'] ?? raw['chapterNumber'] ?? '',
      'total_chapters': raw['chapters'] ?? '',
    });
    return item;
  }

  Future<Map<String, dynamic>> _sourceConfig() async {
    if (_config != null && _configAt != null && DateTime.now().difference(_configAt!) < const Duration(hours: 6)) return _config!;
    _config = _asMap(await _apiRequest('GET', '/source/main_source_config'));
    _configAt = DateTime.now();
    return _config!;
  }

  Future<dynamic> _apiRequest(String method, String path, {Map<String, dynamic>? body}) async {
    // The API rejects an empty Authorization header even when X-Api-Key is valid.
    final headers = {'Accept': 'application/json', 'Content-Type': 'application/json', 'User-Agent': _userAgent, 'X-Api-Key': _apiKey};
    final response = method == 'POST'
        ? await http.post(Uri.parse('$_api$path'), headers: headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 20))
        : await http.get(Uri.parse('$_api$path'), headers: headers).timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('Manga Slayer request failed');
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<dynamic> _sourcePost(Map<String, dynamic> config, String url, Map<String, String> fields) async {
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'User-Agent': _userAgent,
        'Accept': 'text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8',
        'Accept-Language': 'ar,en-US;q=0.9,en;q=0.8',
        'Referer': _fallbackSite,
      },
      body: fields,
    ).timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('Manga Slayer source request failed');
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    try { return jsonDecode(text); } catch (_) { return text; }
  }

  String _ajaxUrl(Map<String, dynamic> config) {
    final domain = _configDomain(config);
    final endpoint = config['ajax_endpoint']?.toString() ?? '/wp-admin/admin-ajax.php';
    return 'https://$domain${endpoint.startsWith('/') ? endpoint : '/$endpoint'}';
  }

  String _configDomain(Map<String, dynamic> config) => _string((config['source'] as Map?)?['domain']).isNotEmpty ? _string((config['source'] as Map)['domain']) : 'sparkmanga.net';

  String _configIp(Map<String, dynamic> config) {
    final mapping = config['ip_mapping'] as Map?;
    final defaultIp = _string(mapping?['default']);
    return defaultIp.isNotEmpty ? defaultIp : '5.187.35.217';
  }

  String _htmlFromResponse(dynamic value) {
    var current = value;
    for (var depth = 0; depth < 5; depth++) {
      // chapter_navigate_page returns {data:{data:{content:<html>}}};
      // tolerate the older {data:<html>} response as well.
      if (current is Map && current['content'] != null) {
        current = current['content'];
      } else if (current is Map && current.containsKey('data')) {
        current = current['data'];
      } else {
        break;
      }
    }
    return _string(current);
  }

  List<String> _images(String html, String base, String selector, Map<String, dynamic> config, Map<String, dynamic> extractor) {
    final transformations = extractor['url_transformations'];
    final urls = <String>{};
    final requiredClass = selector.split('.').last.trim();
    final imageTags = RegExp('<img\\b[^>]*>', caseSensitive: false).allMatches(html);
    for (final tagMatch in imageTags) {
      final tag = tagMatch.group(0) ?? '';
      final classes = RegExp('\\bclass=["\\\']([^"\\\']*)', caseSensitive: false).firstMatch(tag)?.group(1) ?? '';
      if (requiredClass.isNotEmpty && !classes.split(RegExp(r'\s+')).contains(requiredClass)) continue;
      final source = RegExp('\\bsrc=["\\\']([^"\\\']+)', caseSensitive: false).firstMatch(tag)?.group(1) ?? '';
      var url = HtmlParse.absUrl(base, source.trim());
      url = _transformUrl(url, transformations);
      if (url.isNotEmpty) urls.add(_imageUrl(url, config));
    }
    return urls.toList();
  }

  String _imageUrl(String url, Map<String, dynamic> config) {
    // Keep the configured CDN hostname: it is required for TLS and virtual-host routing.
    return url;
  }

  String _transformUrl(String url, dynamic transformations) {
    if (transformations is! List) return url;
    var result = url;
    for (final transformation in transformations.whereType<Map>()) {
      if (transformation['type'] == 'REGEX_REPLACE') {
        final pattern = _string(transformation['pattern']);
        final replacement = _string(transformation['replacement']);
        if (pattern.isNotEmpty) result = result.replaceFirst(RegExp(pattern), replacement);
      }
    }
    return result;
  }

  Map<String, dynamic>? _extractor(Map<String, dynamic> config, String name) {
    for (final value in config['extractors'] as List? ?? const []) {
      if (value is Map && value['name'] == name) return Map<String, dynamic>.from(value);
    }
    return null;
  }

  Map<String, String> _resolveMap(dynamic raw, Map<String, dynamic> params) => raw is Map ? raw.map((key, value) => MapEntry(key.toString(), _resolve(value.toString(), params))) : {};
  List<String> _resolveList(dynamic raw, Map<String, dynamic> params) => raw is List ? raw.map((value) => _resolve(value.toString(), params)).toList() : [];
  String _resolve(String value, Map<String, dynamic> params) => value.replaceAllMapped(RegExp(r'\{([^}]+)\}'), (match) => _string(params[match.group(1)]));
  int? _idFrom(String url) => int.tryParse(RegExp(r'(?:manga/|manga_id=)(\d+)').firstMatch(url)?.group(1) ?? '');
  String _chapterSlug(String url) { final parts = Uri.tryParse(url)?.pathSegments ?? const []; return parts.isEmpty ? '' : parts.last; }
  int _chapterNumber(String title, int fallback) {
    final normalized = _arabicDigits(title);
    final match = RegExp(r'\d+(?:\.\d+)?').firstMatch(normalized);
    return int.tryParse(match?.group(0) ?? '') ?? fallback;
  }
  String _arabicDigits(String value) => value.split('').map((c) => '٠١٢٣٤٥٦٧٨٩'.indexOf(c) >= 0 ? '٠١٢٣٤٥٦٧٨٩'.indexOf(c).toString() : c).join();
  String _normalizeChapterTitle(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();
  List<dynamic> _asList(dynamic value) => value is List ? value : value is Map && value['data'] is List ? value['data'] : const [];
  Map<String, dynamic> _asMap(dynamic value) => value is Map ? Map<String, dynamic>.from(value['data'] is Map ? value['data'] : value) : {};
  String _firstValue(Iterable<dynamic> values) { for (final value in values) { final text = _string(value); if (text.isNotEmpty) return text; } return ''; }
  String _absoluteImage(String value) {
    if (value.isEmpty || Uri.tryParse(value)?.hasScheme == true) return value;
    final sourceImage = _config?['source_image'] as Map?;
    final domain = _string(sourceImage?['image_domain']).isNotEmpty ? _string(sourceImage?['image_domain']) : _fallbackSite;
    final path = _string(sourceImage?['image_path']);
    return HtmlParse.absUrl('https://$domain${path.isEmpty ? '/' : path}', value);
  }
  String _formatType(dynamic value) { final text = _string(value).toLowerCase(); return text.isEmpty ? 'manga' : (text == '1' ? 'manga' : text); }
  String _status(dynamic value) => value is num ? value.toString() : _string(value);
  String _string(dynamic value) => value == null || value is Map || value is List ? '' : value.toString().trim();
  List<dynamic> _list(dynamic value) => value is List ? value : value is String ? value.split(RegExp(r'[,،]')).map((part) => part.trim()).where((part) => part.isNotEmpty).toList() : const [];
}
