import 'dart:convert';

import 'package:http/http.dart' as http;

import 'html_client.dart';
import 'source_base.dart';

class MangaMelloSource extends ContentSource {
  // This is the normal (non-auth) API path used by the official MangaMello
  // client, extracted from its current APK rather than the retired /items API.
  static const _api = 'https://api.mangamello.com/nx/v3n';
  static const _site = 'https://mangamello.com';
  static const _ua = 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/128.0 Mobile Safari/537.36';

  @override
  String get id => 'manga_mello';

  @override
  String get name => 'MangaMello';

  @override
  String get kind => 'manga';

  @override
  List<String> get hosts => ['mangamello.com', 'api.mangamello.com'];

  @override
  bool handles(String url) => url.startsWith('mellomello://') || super.handles(url);

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final data = await _request('/mangas', {
      'search': q,
      'page': '1',
      'per_page': '30',
    });
    return _rows(data).map(_item).where((item) => item.isNotEmpty).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final data = await _request('/mangas', {
      'page': '$page',
      'per_page': '30',
    });
    return _rows(data).map(_item).where((item) => item.isNotEmpty).toList();
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final ids = _parse(url);
    if (ids == null) throw Exception('تعذر تحديد المانجا من MangaMello');

    final data = await _request('/mangas/${Uri.encodeComponent(ids.item)}');
    final result = _item(_record(data));
    result['url'] = _itemUrl(ids.item);
    result['manga_id'] = ids.item;
    // The official API exposes chapters separately. Images are deliberately
    // not requested here; they are lazy-loaded only when a chapter is opened.
    result['chapters'] = await _chapters(ids.item);
    return result;
  }

  @override
  Future<Map<String, dynamic>?> chapterImages(String url) async {
    final ids = _parse(url);
    if (ids == null || ids.chapter == null) return null;

    final chapterId = Uri.encodeComponent(ids.chapter!);
    var data = await _request('/chapters/$chapterId/refresh-images-json');
    var images = _images(data);
    if (images.isEmpty) {
      data = await _request('/chapters/$chapterId/refresh-images');
      images = _images(data);
    }
    if (images.isEmpty) return null;

    final chapter = _record(data);
    final title = _str(_first(chapter, ['title', 'name']), 'الفصل');
    return {
      'title': title,
      'images': images.map((image) => {'url': image}).toList(),
      'pages': images,
      'url': url,
    };
  }

  Future<List<Map<String, dynamic>>> _chapters(String mangaId) async {
    final result = <Map<String, dynamic>>[];
    for (var page = 1; page <= 100; page++) {
      final data = await _request('/mangas/${Uri.encodeComponent(mangaId)}/chapters', {
        'page': '$page',
        'per_page': '100',
      });
      final rows = _rows(data);
      if (rows.isEmpty) break;
      result.addAll(rows.map((row) => _chapter(row, mangaId)));
      if (rows.length < 100 && !_more(data)) break;
      if (!_more(data) && rows.length >= 100) break;
    }
    result.sort((a, b) => ((b['number'] as num?) ?? 0).compareTo((a['number'] as num?) ?? 0));
    return result;
  }

  Future<dynamic> _request(String path, [Map<String, String> params = const {}]) async {
    final uri = Uri.parse('$_api$path').replace(queryParameters: params.isEmpty ? null : params);
    final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('MangaMello request failed (${response.statusCode})');
    }
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (text.trim().isEmpty) return const {};
    try {
      return jsonDecode(text);
    } catch (_) {
      return text;
    }
  }

  static const _headers = {
    'Accept': 'application/json',
    'Accept-Language': 'ar,en-US;q=0.9,en;q=0.8',
    'Origin': _site,
    'Referer': '$_site/',
    'User-Agent': _ua,
    'X-Requested-With': 'com.wael.mangamello',
  };

  Map<String, dynamic> _item(Map<String, dynamic> raw) {
    final id = _first(raw, ['id', '_id', 'manga_id']);
    if (id == null) return {};
    final description = HtmlParse.stripTags(_str(_first(raw, ['description', 'overview', 'synopsis', 'summary', 'story'])));
    final item = this.item(
      title: _str(_first(raw, ['title', 'name']), 'بدون عنوان'),
      url: _itemUrl('$id'),
      image: _image(raw['cover'] ?? raw['image'] ?? raw['poster'] ?? raw['thumbnail']),
      type: _str(_first(raw, ['type', 'format']), 'comic'),
      genres: _strings(raw['genres'] ?? raw['tags'] ?? raw['genre']),
      description: description,
      rating: _str(_first(raw, ['rating', 'score', 'rate'])),
    );
    item.addAll({
      'manga_id': '$id',
      'description': description,
      'author': _str(_first(raw, ['author', 'authors'])),
      'artist': _str(_first(raw, ['artist', 'artists'])),
      'status': _str(_first(raw, ['status', 'state'])),
      'updated_at': _str(_first(raw, ['updated_at', 'updatedAt', 'updated'])),
      'total_chapters': raw['chapter_count'] ?? raw['chapters_count'] ?? '',
    });
    return item;
  }

  Map<String, dynamic> _chapter(Map<String, dynamic> raw, String mangaId) {
    final id = _str(_first(raw, ['id', '_id', 'chapter_id', 'part_id']));
    final title = _str(_first(raw, ['title', 'name']), 'الفصل');
    final number = _number(raw['number'] ?? raw['chapter'] ?? raw['chapter_number'] ?? title) ?? 0;
    return {
      'id': id,
      'chapter_id': id,
      'title': title,
      'number': number,
      'chapter_number': number,
      'volume': raw['volume'] ?? '',
      'release_date': _str(_first(raw, ['published_at', 'publishedAt', 'release_date', 'date'])),
      'url': _chapterUrl(mangaId, id),
      'downloadable': raw['downloadable'] ?? true,
    };
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (value is Map) {
      for (final key in ['mangas', 'items', 'results', 'data', 'records', 'chapters']) {
        final nested = value[key];
        if (nested is List) return _rows(nested);
        if (nested is Map) {
          final found = _rows(nested);
          if (found.isNotEmpty) return found;
        }
      }
    }
    return const [];
  }

  Map<String, dynamic> _record(dynamic value) {
    if (value is Map) {
      for (final key in ['manga', 'chapter', 'item', 'data', 'result']) {
        if (value[key] is Map) return _record(value[key]);
      }
      return Map<String, dynamic>.from(value);
    }
    return {};
  }

  List<String> _images(dynamic value) {
    final result = <String>[];
    void visit(dynamic node) {
      if (node is List) {
        for (final entry in node) visit(entry);
      } else if (node is Map) {
        for (final entry in node.entries) {
          final key = entry.key.toString().toLowerCase();
          if (entry.value is String && (key.contains('image') || key.contains('url') || key == 'src')) {
            final image = _absolute(entry.value as String);
            if (image.isNotEmpty && !result.contains(image)) result.add(image);
          } else if (entry.value is Map || entry.value is List) {
            visit(entry.value);
          }
        }
      } else if (node is String && node.startsWith('http')) {
        if (!result.contains(node)) result.add(node);
      }
    }
    visit(value);
    return result;
  }

  bool _more(dynamic value) {
    if (value is! Map) return false;
    final next = value['has_next'] ?? value['hasNext'] ?? value['next_page'] ?? value['nextPage'];
    return next == true || (next != null && next.toString() != 'false' && next.toString() != 'null');
  }

  dynamic _first(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      if (map[key] != null && '${map[key]}'.isNotEmpty) return map[key];
    }
    return null;
  }

  String _str(dynamic value, [String fallback = '']) {
    if (value == null || value is Map || value is List) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  List<String> _strings(dynamic value) {
    if (value is String) return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (value is List) return value.map((e) => e is Map ? _str(e['name'] ?? e['title']) : _str(e)).where((e) => e.isNotEmpty).toList();
    return const [];
  }

  String _image(dynamic value) {
    if (value is Map) return _image(value['url'] ?? value['src'] ?? value['original'] ?? value['large'] ?? value['medium']);
    if (value is List && value.isNotEmpty) return _image(value.first);
    return _absolute(_str(value));
  }

  String _absolute(String value) {
    if (value.isEmpty) return '';
    final parsed = Uri.tryParse(value);
    if (parsed?.hasScheme == true) return value;
    return Uri.parse(_site).resolve(value).toString();
  }

  double? _number(dynamic value) {
    final match = RegExp(r'\d+(?:\.\d+)?').firstMatch(_str(value));
    return match == null ? null : double.tryParse(match.group(0)!);
  }

  String _itemUrl(String id) => 'mellomello://item/$id';

  String _chapterUrl(String manga, String chapter) => 'mellomello://chapter/$manga/$chapter';

  _MelloIds? _parse(String url) {
    final match = RegExp(r'mellomello://(?:item|chapter)/([^/?]+)(?:/([^/?]+))?').firstMatch(url);
    return match == null ? null : _MelloIds(match.group(1)!, match.group(2));
  }
}

class _MelloIds {
  final String item;
  final String? chapter;
  _MelloIds(this.item, this.chapter);
}
