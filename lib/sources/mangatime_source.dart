import 'dart:convert';

import 'package:http/http.dart' as http;

import 'source_base.dart';

/// MangaTime source adapter.
///
/// MangaTime exposes public content through tRPC. The adapter keeps the
/// source-specific URL/identifier format isolated from the shared reader and
/// content models used by AniTV.
class MangaTimeSource extends ContentSource {
  static const _site = 'https://mangatime.org';
  static const _trpc = '$_site/api/trpc';
  static const _appVersion = '1.5.45';

  @override
  String get id => 'mangatime';

  @override
  String get name => 'MangaTime';

  @override
  String get kind => 'manga';

  @override
  List<String> get hosts => const ['mangatime.org'];

  @override
  bool handles(String url) => url.startsWith('mangatime://') || super.handles(url);

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return const [];
    final response = await _call('search.searchSeries', {'query': value, 'page': 1, 'limit': 30});
    return _list(response)
        .map(_series)
        .where((item) => item['title'].toString().trim().isNotEmpty)
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    if (page < 1) page = 1;
    final response = await _call('homepage.getLatestReleases', {'page': page, 'limit': 30});
    return _list(response).map(_series).where((item) => item['title'].toString().trim().isNotEmpty).toList();
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final slug = _slugFrom(url);
    if (slug.isEmpty) throw Exception('MangaTime: invalid series slug');
    final raw = _asMap(await _call('content.getSeriesBySlug', {'slug': slug}));
    if (raw.isEmpty) throw Exception('MangaTime: series not found');
    final item = _series(raw);
    item['url'] = _seriesUrl(_string(raw['id']), slug);
    item['chapters'] = await _chapters(_string(raw['id']));
    return item;
  }

  @override
  Future<Map<String, dynamic>?> chapterImages(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'mangatime') return null;
    final chapterId = uri.queryParameters['id'] ?? '';
    if (chapterId.isEmpty) throw Exception('MangaTime: missing chapter id');
    final raw = _asMap(await _call('content.getChapterPages', {'chapterId': chapterId}));
    final pages = _strings(raw['pages']).map(_imageUrl).where((x) => x.isNotEmpty).toList();
    if (pages.isEmpty) throw Exception('MangaTime: chapter pages not found');
    final dimensions = raw['pageDimensions'] is List ? raw['pageDimensions'] : const [];
    return {
      'title': _string(raw['title'], 'الفصل ${uri.queryParameters['number'] ?? ''}'.trim()),
      'chapter_number': raw['number'] ?? uri.queryParameters['number'] ?? '',
      'format': raw['format'] ?? 'images',
      'page_dimensions': dimensions,
      'pages': pages,
      'images': pages.map((image) => {'url': image}).toList(),
      'url': url,
      'navigation': {
        if (raw['prevChapter'] is Map && _string(raw['prevChapter']['id']).isNotEmpty)
          'prev_chapter': _chapterUrl(_string(raw['prevChapter']['id']), raw['prevChapter']['number']),
        if (raw['nextChapter'] is Map && _string(raw['nextChapter']['id']).isNotEmpty)
          'next_chapter': _chapterUrl(_string(raw['nextChapter']['id']), raw['nextChapter']['number']),
      },
    };
  }

  Future<List<Map<String, dynamic>>> _chapters(String seriesId) async {
    if (seriesId.isEmpty) return const [];
    final response = await _call('content.getChapters', {'seriesId': seriesId, 'limit': -1});
    final result = _list(response).map((raw) {
      final id = _string(raw['id']);
      final number = raw['number'] ?? _number(raw['title']);
      return {
        'id': id,
        'chapter_id': id,
        'chapter_number': number ?? 0,
        'number': number ?? 0,
        'title': _string(raw['title'], 'الفصل ${number ?? ''}'.trim()),
        'volume': raw['volume'] ?? '',
        'release_date': _string(raw['publishedAt'] ?? raw['createdAt']),
        'date': _string(raw['publishedAt'] ?? raw['createdAt']),
        'format': raw['format'] ?? 'images',
        'page_count': raw['pageCount'] ?? 0,
        'url': _chapterUrl(id, number),
      };
    }).where((item) => item['id'].toString().isNotEmpty).toList();
    result.sort((a, b) => _compareNumbers(b['number'], a['number']));
    return result;
  }

  Map<String, dynamic> _series(Map<String, dynamic> raw) {
    final id = _string(raw['id']);
    final slug = _string(raw['slug']);
    final stats = _asMap(raw['stats']);
    final title = _string(raw['title'], 'بدون عنوان');
    final alternatives = raw['alternativeTitles'] ?? raw['alternateTitles'] ?? const [];
    final genres = raw['genres'];
    final item = this.item(
      title: title,
      url: _seriesUrl(id, slug),
      image: _imageUrl(raw['coverUrl'] ?? raw['cover']),
      type: _string(raw['type'], 'manga'),
      genres: _strings(genres),
      description: _string(raw['description']),
      rating: _string(raw['rating'] ?? stats['rating']),
    );
    item.addAll({
      'manga_id': id,
      'series_id': id,
      'slug': slug,
      'alternate_titles': _strings(alternatives, mapKey: 'title'),
      'author': _string(raw['author']),
      'artist': _string(raw['artist']),
      'status': _string(raw['status']),
      'year': raw['year'] ?? '',
      'banner_image_url': _imageUrl(raw['bannerUrl']),
      'updated_at': _string(raw['updatedAt']),
      'published_at': _string(raw['publishedAt']),
      'total_chapters': raw['chapterCount'] ?? stats['chapterCount'] ?? '',
    });
    return item;
  }

  Future<dynamic> _call(String procedure, Map<String, dynamic> input) async {
    final encoded = Uri.encodeQueryComponent(jsonEncode({'json': input}));
    final response = await http.get(
      Uri.parse('$_trpc/$procedure?input=$encoded'),
      headers: const {
        'Accept': 'application/json',
        'X-MT-Platform': 'app',
        'X-MT-App-Version': _appVersion,
        'X-MT-UIMode': 'dark',
      },
    ).timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('MangaTime request failed (${response.statusCode})');
    }
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['error'] != null) {
      throw Exception('MangaTime server error');
    }
    return _unwrap(decoded);
  }

  static dynamic _unwrap(dynamic value) {
    var current = value;
    for (var i = 0; i < 8; i++) {
      if (current is Map && current.containsKey('result')) current = current['result'];
      else if (current is Map && current.containsKey('data')) current = current['data'];
      else if (current is Map && current.containsKey('json')) current = current['json'];
      else break;
    }
    return current;
  }

  static List<Map<String, dynamic>> _list(dynamic value) {
    final unwrapped = _unwrap(value);
    if (unwrapped is List) return unwrapped.whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList();
    if (unwrapped is Map) {
      for (final key in const ['results', 'items', 'chapters', 'data']) {
        final found = _list(unwrapped[key]);
        if (found.isNotEmpty) return found;
      }
    }
    return const [];
  }

  static Map<String, dynamic> _asMap(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static String _string(dynamic value, [String fallback = '']) => value == null ? fallback : value.toString().trim().isEmpty ? fallback : value.toString().trim();

  static List<String> _strings(dynamic value, {String? mapKey}) {
    if (value is String) return value.trim().isEmpty ? const [] : [value.trim()];
    if (value is List) return value.map((entry) => entry is Map && mapKey != null ? _string(entry[mapKey]) : _string(entry)).where((x) => x.isNotEmpty).toList();
    return const [];
  }

  static String _imageUrl(dynamic value) {
    final raw = _string(value);
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return '$_site/${raw.replaceFirst(RegExp(r'^/+'), '')}';
  }

  static String _seriesUrl(String id, [String slug = '']) => 'mangatime://series/${Uri.encodeComponent(slug.isNotEmpty ? slug : id)}?id=${Uri.encodeQueryComponent(id)}';

  static String _chapterUrl(String id, dynamic number) => 'mangatime://chapter?id=${Uri.encodeQueryComponent(id)}&number=${Uri.encodeQueryComponent(_string(number))}';

  static String _slugFrom(String url) {
    final uri = Uri.tryParse(url);
    if (uri?.scheme == 'mangatime') return uri!.pathSegments.isEmpty ? '' : Uri.decodeComponent(uri.pathSegments.last);
    if (uri != null && uri.host.contains('mangatime.org')) {
      final parts = uri.pathSegments.where((x) => x.isNotEmpty).toList();
      return parts.isEmpty ? '' : parts.last;
    }
    return '';
  }

  static num? _number(dynamic value) => num.tryParse(_string(value).replaceAll(',', ''));

  static int _compareNumbers(dynamic a, dynamic b) => ((_number(a) ?? 0).compareTo(_number(b) ?? 0));
}
