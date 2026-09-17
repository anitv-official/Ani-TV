import 'dart:convert';
import 'package:http/http.dart' as http;
import 'source_base.dart';

class WecimaSource extends ContentSource {
  static const _api = 'https://anitv-manga-lord.vercel.app/api/wecima';
  final http.Client _client = http.Client();
  @override String get id => 'wecima';
  @override String get name => 'Wecima';
  @override String get kind => 'movie';
  @override List<String> get hosts => const ['wecima.cx', 'wecima.show', 'wecima.watch', 'wec.im', 'wecimamax.com'];

  @override Future<List<Map<String, dynamic>>> latest({int page = 1}) => _catalog('latest', page: page);
  @override Future<List<Map<String, dynamic>>> search(String query) => _catalog('search', query: query);
  Future<List<Map<String, dynamic>>> _catalog(String action, {int page = 1, String query = ''}) async {
    final uri = Uri.parse(_api).replace(queryParameters: {'action': action, 'page': '$page', if (query.trim().isNotEmpty) 'q': query.trim()});
    final data = await _get(uri);
    return (data['items'] as List? ?? const []).whereType<Map>().map((raw) => item(title: _text(raw['title'], 'بدون عنوان'), url: _text(raw['url'], ''), image: _text(raw['image_url'], ''), type: _text(raw['type'], 'فيلم'), description: _text(raw['description'], ''))).where((x) => x['url'].toString().isNotEmpty).toList();
  }
  @override Future<Map<String, dynamic>> details(String url) async => Map<String, dynamic>.from(await _get(Uri.parse(_api).replace(queryParameters: {'action': 'details', 'url': url})))..['source_id'] = id;
  @override Future<Map<String, dynamic>?> streams(String url) async {
    final data = await _get(Uri.parse(_api).replace(queryParameters: {'action': 'servers', 'url': url}));
    final servers = (data['servers'] as List? ?? const []).whereType<Map>().map((server) => {'url': _text(server['url'], ''), 'label': _text(server['name'], 'سيرفر'), 'name': _text(server['name'], 'سيرفر')}).where((x) => x['url'].toString().isNotEmpty).toList();
    if (servers.isEmpty) return null;
    return {'stream_url': servers.first['url'], 'direct_stream_urls': servers, 'servers': servers, 'title': 'مصادر Wecima'};
  }
  Future<Map<String, dynamic>> _get(Uri uri) async {
    final response = await _client.get(uri, headers: const {'Accept': 'application/json'}).timeout(const Duration(seconds: 35));
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('تعذر الاتصال بمصدر Wecima');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
    if (decoded is! Map || decoded['error'] != null) throw Exception(decoded is Map ? (decoded['message'] ?? 'تعذر تحميل بيانات Wecima') : 'استجابة غير صالحة');
    return Map<String, dynamic>.from(decoded);
  }
  String _text(dynamic value, String fallback) => value == null || value.toString().trim().isEmpty ? fallback : value.toString().trim();
}
