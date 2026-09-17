import 'dart:convert';
import 'package:http/http.dart' as http;

class NovelService {
  static const _base = 'https://anitv-novel-bridge-manga-lord.vercel.app/api/novels';
  static final _client = http.Client();

  static Future<List<Map<String, dynamic>>> latest({int page = 1, String query = ''}) async {
    final uri = Uri.parse(_base).replace(queryParameters: {
      'action': query.trim().isEmpty ? 'latest' : 'search',
      'page': '$page',
      if (query.trim().isNotEmpty) 'q': query.trim(),
    });
    final response = await _client.get(uri).timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('تعذر تحميل الروايات');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['items'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<Map<String, dynamic>> details(String url) async {
    final uri = Uri.parse(_base).replace(queryParameters: {'action': 'details', 'url': url});
    final response = await _client.get(uri).timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('تعذر تحميل تفاصيل الرواية');
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  static Future<Map<String, dynamic>> chapter(String url) async {
    final uri = Uri.parse(_base).replace(queryParameters: {'action': 'chapter', 'url': url});
    final response = await _client.get(uri).timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('تعذر تحميل الفصل');
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }
}
