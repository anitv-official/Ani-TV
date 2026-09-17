import 'dart:convert';
import 'package:http/http.dart' as http;

class NovelService {
  static const _base = 'https://anitv-manga-lord.vercel.app/api/novels';
  static final _client = http.Client();

  static Future<List<Map<String, dynamic>>> latest({int page = 1, String query = ''}) async {
    final uri = Uri.parse(_base).replace(queryParameters: {
      'action': query.trim().isEmpty ? 'latest' : 'search',
      'page': '$page',
      if (query.trim().isNotEmpty) 'q': query.trim(),
    });
    final data = await _get(uri, 'تعذر تحميل الروايات');
    return _list(data['items']).map(_normalizeNovel).where((item) => item['url'].toString().isNotEmpty).toList();
  }

  static Future<Map<String, dynamic>> details(String url) async {
    final uri = Uri.parse(_base).replace(queryParameters: {'action': 'details', 'url': url});
    final data = await _get(uri, 'تعذر تحميل تفاصيل الرواية');
    final chapters = _list(data['chapters']).map(_normalizeChapter).where((chapter) => chapter['url'].toString().isNotEmpty).toList()
      ..sort((a, b) => (b['number'] as num).compareTo(a['number'] as num));
    return {..._normalizeNovel(data), 'chapters': chapters};
  }

  static Future<Map<String, dynamic>> chapter(String url) async {
    final uri = Uri.parse(_base).replace(queryParameters: {'action': 'chapter', 'url': url});
    final data = await _get(uri, 'تعذر تحميل الفصل');
    final content = _text(data['content']) ?? '';
    if (content.isEmpty) throw Exception('الفصل لا يحتوي على نص');
    return {...data, 'title': _text(data['title']) ?? _chapterTitleFromUrl(url) ?? 'فصل الرواية', 'content': content};
  }

  static Future<Map<String, dynamic>> _get(Uri uri, String error) async {
    final response = await _client.get(uri, headers: const {'Accept': 'application/json'}).timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception(error);
    final decoded = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
    if (decoded is! Map || decoded['error'] != null) throw Exception(decoded is Map ? (decoded['message']?.toString() ?? error) : error);
    return Map<String, dynamic>.from(decoded);
  }

  static List<Map<String, dynamic>> _list(dynamic value) => value is List
      ? value.whereType<Map>().map((entry) => Map<String, dynamic>.from(entry)).toList()
      : <Map<String, dynamic>>[];

  static Map<String, dynamic> _normalizeNovel(Map<String, dynamic> raw) => {
        ...raw,
        'title': _text(raw['title'] ?? raw['name']) ?? 'رواية بدون عنوان',
        'url': _text(raw['url'] ?? raw['link']) ?? '',
        'image_url': _text(raw['image_url'] ?? raw['image'] ?? raw['cover']) ?? '',
        'synopsis': _text(raw['synopsis'] ?? raw['description'] ?? raw['summary']) ?? '',
      };

  static Map<String, dynamic> _normalizeChapter(Map<String, dynamic> raw) {
    final title = _text(raw['title'] ?? raw['name'] ?? raw['chapter_title']) ?? '';
    final number = num.tryParse('${raw['number'] ?? raw['chapter_number'] ?? _numberFromTitle(title) ?? 0}') ?? 0;
    return {...raw, 'title': title.isEmpty ? (number > 0 ? 'الفصل ${_formatNumber(number)}' : 'فصل الرواية') : title, 'url': _text(raw['url'] ?? raw['link']) ?? '', 'number': number};
  }

  static String? _text(dynamic value) {
    final text = value?.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return text == null || text.isEmpty ? null : text;
  }

  static num? _numberFromTitle(String value) => num.tryParse(RegExp(r'(?:chapter|الفصل|فصل)\s*([0-9]+(?:\.[0-9]+)?)', caseSensitive: false).firstMatch(value)?.group(1) ?? '');
  static String? _chapterTitleFromUrl(String url) => RegExp(r'(?:chapter|chapter-|shaag/)([\w-]+)', caseSensitive: false).firstMatch(url)?.group(1)?.replaceAll('-', ' ');
  static String _formatNumber(num value) => value % 1 == 0 ? value.toInt().toString() : value.toString();
}
