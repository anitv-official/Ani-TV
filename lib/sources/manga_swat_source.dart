import 'html_client.dart';
import 'source_base.dart';

class MangaSwatSource extends ContentSource {
  static const String _api = 'https://appswat.com/v2/api/v2';

  @override
  String get id => 'swat';

  @override
  String get name => 'Manga Swat';

  @override
  String get kind => 'manga';

  @override
  List<String> get hosts => ['meshmanga.com', 'appswat.com'];

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final data = await HtmlClient.getJson(
      '$_api/series/?search=${Uri.encodeQueryComponent(query)}',
    );
    return _mapSeriesList(data);
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final data = await HtmlClient.getJson('$_api/series/?page=$page');
    return _mapSeriesList(data);
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final id = _seriesId(url);
    if (id == null) throw Exception('تعذر تحميل المحتوى');
    final data = await HtmlClient.getJson('$_api/series/$id/') as Map;
    final chapters = await _allChapters(id);
    final poster = data['poster'];
    String image = '';
    if (poster is Map) {
      image = (poster['medium'] ?? poster['thumbnail'] ?? '').toString();
    }
    final genres = <String>[];
    if (data['genres'] is List) {
      for (final g in data['genres']) {
        if (g is Map && g['name'] != null) genres.add(g['name'].toString());
      }
    }
    final typeName = data['type'] is Map
        ? (data['type']['name'] ?? 'comic').toString()
        : 'comic';
    final description = HtmlParse.stripTags((data['story'] ?? '').toString());
    return {
      ...item(
        title: (data['title'] ?? '').toString(),
        url: _seriesUrl(id, (data['slug'] ?? '').toString()),
        image: image,
        type: typeName,
        genres: genres,
        description: description,
        rating: (data['rating'] ?? '').toString(),
      ),
      'synopsis': description,
      'chapters': chapters,
    };
  }

  @override
  Future<Map<String, dynamic>> chapterImages(String url) async {
    final id = _chapterId(url);
    if (id == null) throw Exception('تعذر تحميل المحتوى');
    final data = await HtmlClient.getJson('$_api/chapters/$id/images/');
    final images = <Map<String, dynamic>>[];
    if (data is List) {
      final sorted = [...data];
      sorted.sort((a, b) {
        final ao = a is Map ? (a['order'] as num? ?? 0) : 0;
        final bo = b is Map ? (b['order'] as num? ?? 0) : 0;
        return ao.compareTo(bo);
      });
      for (final img in sorted) {
        if (img is! Map) continue;
        final src = (img['image'] ?? '').toString();
        if (src.isEmpty) continue;
        images.add({'url': src});
      }
    }
    return {
      'title': 'الفصل',
      'images': images,
      'chapter_number': id,
    };
  }

  List<Map<String, dynamic>> _mapSeriesList(dynamic data) {
    final results = data is Map ? (data['results'] as List? ?? []) : <dynamic>[];
    final items = <Map<String, dynamic>>[];
    for (final raw in results) {
      if (raw is! Map) continue;
      final poster = raw['poster'];
      String image = '';
      if (poster is Map) {
        image = (poster['medium'] ?? poster['thumbnail'] ?? '').toString();
      }
      final typeName = raw['type'] is Map
          ? (raw['type']['name'] ?? 'comic').toString()
          : 'comic';
      final genres = <String>[];
      if (raw['genres'] is List) {
        for (final g in raw['genres']) {
          if (g is Map && g['name'] != null) genres.add(g['name'].toString());
        }
      }
      items.add(item(
        title: (raw['title'] ?? '').toString(),
        url: _seriesUrl(raw['id'], (raw['slug'] ?? '').toString()),
        image: image,
        type: typeName,
        genres: genres,
        rating: (raw['rating'] ?? '').toString(),
      ));
    }
    return items;
  }

  Future<List<Map<String, dynamic>>> _allChapters(dynamic seriesId) async {
    final chapters = <Map<String, dynamic>>[];
    String? next = '$_api/series/$seriesId/chapters/';
    var guard = 0;
    while (next != null && next.isNotEmpty && guard < 80) {
      guard++;
      final data = await HtmlClient.getJson(next);
      if (data is! Map) break;
      final results = data['results'] as List? ?? [];
      for (final raw in results) {
        if (raw is! Map) continue;
        final id = raw['id'];
        final number = (raw['chapter'] ?? '').toString();
        final title = (raw['title'] ?? 'الفصل $number').toString();
        chapters.add({
          'title': title,
          'url': 'swat://chapter/$id',
          'number': int.tryParse(number.split('.').first) ?? chapters.length + 1,
        });
      }
      next = data['next']?.toString();
      if (next == 'null') next = null;
    }
    chapters.sort((a, b) => (b['number'] as int).compareTo(a['number'] as int));
    return chapters;
  }

  String _seriesUrl(dynamic id, String slug) {
    return 'swat://series/$id/${slug.isEmpty ? id : slug}';
  }

  int? _seriesId(String url) {
    final match = RegExp(r'swat://series/(\d+)').firstMatch(url);
    if (match != null) return int.tryParse(match.group(1)!);
    final mesh = RegExp(r'meshmanga\.com/series/(\d+)').firstMatch(url);
    if (mesh != null) return int.tryParse(mesh.group(1)!);
    return int.tryParse(url);
  }

  int? _chapterId(String url) {
    final match = RegExp(r'swat://chapter/(\d+)').firstMatch(url);
    if (match != null) return int.tryParse(match.group(1)!);
    return int.tryParse(url);
  }

  @override
  bool handles(String url) {
    return url.startsWith('swat://') || super.handles(url);
  }
}
