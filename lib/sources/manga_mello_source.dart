import 'dart:convert';

import 'package:http/http.dart' as http;

import 'html_client.dart';
import 'source_base.dart';

class MangaMelloSource extends ContentSource {
  static const _api = 'https://api.mangamello.com';
  static const _site = 'https://mangamello.com';
  static const _ua = 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/128.0 Mobile Safari/537.36';

  @override String get id => 'manga_mello';
  @override String get name => 'MangaMello';
  @override String get kind => 'manga';
  @override List<String> get hosts => ['mangamello.com', 'api.mangamello.com'];
  @override bool handles(String url) => url.startsWith('mellomello://') || super.handles(url);

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final data = await _request('/items/search', {'query': q, 'page': '1', 'per_page': '30', 'relations': 'genres'});
    final rows = _rows(data);
    print('MangaMello search: ${rows.length} results');
    return rows.map(_item).where((e) => e.isNotEmpty).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final data = await _request('/items', {'page': '$page', 'per_page': '30', 'sort_by': 'id', 'dir': 'desc', 'relations': 'genres'});
    final rows = _rows(data);
    print('MangaMello latest page $page: ${rows.length} results');
    return rows.map(_item).where((e) => e.isNotEmpty).toList();
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final ids = _parse(url);
    if (ids == null) throw Exception('تعذر تحديد المانجا من MangaMello');
    final data = await _request('/items/${Uri.encodeComponent(ids.item)}', {'relations': 'genres,chapters', 'rate': '1'});
    final result = _item(_record(data));
    result['url'] = _itemUrl(ids.item);
    result['manga_id'] = ids.item;
    result['chapters'] = await _chapters(ids.item);
    return result;
  }

  @override
  Future<Map<String, dynamic>?> chapterImages(String url) async {
    final ids = _parse(url);
    if (ids == null || ids.chapter == null) return null;
    var data = await _request('/items/${Uri.encodeComponent(ids.item)}/parts/${Uri.encodeComponent(ids.chapter!)}', {});
    var images = _images(data);
    if (images.isEmpty) {
      data = await _request('/items/parts/${Uri.encodeComponent(ids.chapter!)}/refresh-images-json', {}, method: 'POST');
      images = _images(data);
    }
    print('MangaMello pages: ${images.length}');
    if (images.isEmpty) return null;
    return {'title': _str(_record(data)['title'], 'الفصل'), 'images': images.map((e) => {'url': e}).toList(), 'pages': images, 'url': url};
  }

  Future<List<Map<String, dynamic>>> _chapters(String itemId) async {
    final result = <Map<String, dynamic>>[];
    for (var page = 1; page <= 100; page++) {
      final data = await _request('/items/${Uri.encodeComponent(itemId)}/parts', {'page': '$page', 'per_page': '100', 'sort_by': 'number', 'sort_order': 'desc', 'relations': ''});
      final rows = _rows(data);
      if (rows.isEmpty) break;
      result.addAll(rows.map((row) => _chapter(row, itemId)));
      if (rows.length < 100 && !_more(data)) break;
      if (!_more(data) && rows.length >= 100) break;
    }
    result.sort((a, b) => ((b['number'] as num?) ?? 0).compareTo((a['number'] as num?) ?? 0));
    print('MangaMello chapters: ${result.length}');
    return result;
  }

  Future<dynamic> _request(String path, Map<String, String> params, {String method = 'GET'}) async {
    final uri = Uri.parse('$_api$path').replace(queryParameters: params);
    final response = method == 'POST'
        ? await http.post(uri, headers: _headers).timeout(const Duration(seconds: 25))
        : await http.get(uri, headers: _headers).timeout(const Duration(seconds: 25));
    print('MangaMello ${method.toLowerCase()} $path: HTTP ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('MangaMello request failed');
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (text.trim().isEmpty) return const {};
    try { return jsonDecode(text); } catch (_) { return text; }
  }

  static const _headers = {'Accept': 'application/json', 'Accept-Language': 'ar,en-US;q=0.9,en;q=0.8', 'User-Agent': _ua};

  Map<String, dynamic> _item(Map<String, dynamic> raw) {
    final id = _first(raw, ['id', '_id', 'item_id']);
    if (id == null) return {};
    final description = HtmlParse.stripTags(_str(_first(raw, ['description', 'overview', 'synopsis', 'summary', 'story'])));
    final item = this.item(title: _str(_first(raw, ['title', 'name']), 'بدون عنوان'), url: _itemUrl('$id'), image: _image(raw['cover'] ?? raw['image'] ?? raw['poster'] ?? raw['thumbnail']), type: _str(_first(raw, ['type', 'format']), 'comic'), genres: _strings(raw['genres'] ?? raw['tags'] ?? raw['genre']), description: description, rating: _str(_first(raw, ['rating', 'score', 'rate'])));
    item.addAll({'manga_id': '$id', 'description': description, 'author': _str(_first(raw, ['author', 'authors'])), 'artist': _str(_first(raw, ['artist', 'artists'])), 'status': _str(_first(raw, ['status', 'state'])), 'updated_at': _str(_first(raw, ['updated_at', 'updatedAt', 'updated'])), 'total_chapters': raw['chapter_count'] ?? raw['chapters_count'] ?? ''});
    return item;
  }

  Map<String, dynamic> _chapter(Map<String, dynamic> raw, String itemId) {
    final id = _str(_first(raw, ['id', '_id', 'part_id', 'chapter_id']));
    final title = _str(_first(raw, ['title', 'name']), 'الفصل');
    final number = _number(raw['number'] ?? raw['chapter'] ?? raw['chapter_number'] ?? title) ?? 0;
    return {'id': id, 'chapter_id': id, 'title': title, 'number': number, 'chapter_number': number, 'volume': raw['volume'] ?? '', 'release_date': _str(_first(raw, ['published_at', 'publishedAt', 'release_date', 'date'])), 'url': _chapterUrl(itemId, id), 'downloadable': raw['downloadable'] ?? true};
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (value is Map) {
      for (final key in ['items', 'results', 'data', 'records', 'parts', 'chapters']) {
        final nested = value[key];
        if (nested is List) return _rows(nested);
        if (nested is Map) { final found = _rows(nested); if (found.isNotEmpty) return found; }
      }
    }
    return const [];
  }

  Map<String, dynamic> _record(dynamic value) {
    if (value is Map) {
      for (final key in ['item', 'data', 'result']) { if (value[key] is Map) return _record(value[key]); }
      return Map<String, dynamic>.from(value);
    }
    return {};
  }

  List<String> _images(dynamic value) {
    final result = <String>[];
    void visit(dynamic node) {
      if (node is List) { for (final e in node) visit(e); }
      else if (node is Map) { for (final e in node.entries) { final key = e.key.toString().toLowerCase(); if (e.value is String && (key.contains('image') || key.contains('url') || key == 'src')) { final url = _absolute(e.value); if (url.isNotEmpty && !result.contains(url)) result.add(url); } else if (e.value is Map || e.value is List) visit(e.value); } }
      else if (node is String && node.startsWith('http')) { if (!result.contains(node)) result.add(node); }
    }
    visit(value);
    return result;
  }

  bool _more(dynamic value) { if (value is! Map) return false; final v = value['has_next'] ?? value['hasNext'] ?? value['next_page'] ?? value['nextPage']; return v == true || (v != null && v.toString() != 'false' && v.toString() != 'null'); }
  dynamic _first(Map<String, dynamic> map, List<String> keys) { for (final key in keys) { if (map[key] != null && '${map[key]}'.isNotEmpty) return map[key]; } return null; }
  String _str(dynamic value, [String fallback = '']) { if (value == null || value is Map || value is List) return fallback; final s = value.toString().trim(); return s.isEmpty ? fallback : s; }
  List<String> _strings(dynamic value) { if (value is String) return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(); if (value is List) return value.map((e) => e is Map ? _str(e['name'] ?? e['title']) : _str(e)).where((e) => e.isNotEmpty).toList(); return const []; }
  String _image(dynamic value) { if (value is Map) return _image(value['url'] ?? value['src'] ?? value['original'] ?? value['large'] ?? value['medium']); if (value is List && value.isNotEmpty) return _image(value.first); return _absolute(_str(value)); }
  String _absolute(String value) => value.isEmpty ? '' : (Uri.tryParse(value)?.hasScheme == true ? value : Uri.parse(_site).resolve(value).toString());
  double? _number(dynamic value) { final m = RegExp(r'\d+(?:\.\d+)?').firstMatch(_str(value)); return m == null ? null : double.tryParse(m.group(0)!); }
  String _itemUrl(String id) => 'mellomello://item/$id';
  String _chapterUrl(String item, String chapter) => 'mellomello://chapter/$item/$chapter';
  _MelloIds? _parse(String url) { final m = RegExp(r'mellomello://(?:item|chapter)/([^/?]+)(?:/([^/?]+))?').firstMatch(url); return m == null ? null : _MelloIds(m.group(1)!, m.group(2)); }
}

class _MelloIds { final String item; final String? chapter; _MelloIds(this.item, this.chapter); }
