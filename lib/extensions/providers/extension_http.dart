import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../sources/html_client.dart';

class ExtensionHttp {
  static const userAgent =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 Chrome/122.0 Mobile Safari/537.36';

  static Map<String, String> headers({String? referer, bool json = false}) => {
        'User-Agent': userAgent,
        'Accept': json
            ? 'application/json'
            : 'text/html,application/xhtml+xml,application/json;q=0.8,*/*;q=0.7',
        'Accept-Language': 'ar,en-US;q=0.9,en;q=0.8',
        if (referer != null && referer.isNotEmpty) 'Referer': referer,
      };

  static Future<String> getText(String url, {String? referer}) async {
    final response = await http
        .get(Uri.parse(url), headers: headers(referer: referer))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 400) {
      throw Exception('HTTP ${response.statusCode}');
    }
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  static Future<dynamic> getJson(String url, {String? referer}) async {
    final response = await http
        .get(Uri.parse(url), headers: headers(referer: referer, json: true))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 400) {
      throw Exception('HTTP ${response.statusCode}');
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  static String text(String value) => HtmlParse.stripTags(value);

  static String? attr(String attrs, String name) => HtmlParse.firstMatch(
        attrs,
        [RegExp('$name=["\\\']([^"\\\']+)', caseSensitive: false)],
      );

  static List<Map<String, String>> anchors(String html, String baseUrl) {
    final result = <Map<String, String>>[];
    final seen = <String>{};
    final pattern = RegExp(
      r'''<a\b([^>]*href=["'][^"']+["'][^>]*)>(.*?)</a>''',
      caseSensitive: false,
      dotAll: true,
    );
    for (final match in pattern.allMatches(html)) {
      final attrs = match.group(1) ?? '';
      final href = attr(attrs, 'href');
      if (href == null) continue;
      final url = HtmlParse.absUrl(baseUrl, href);
      if (url.isEmpty || !seen.add(url)) continue;
      result.add({'url': url, 'title': text(match.group(2) ?? '')});
    }
    return result;
  }
}

String? extractBalancedJson(String source, String marker) {
  final markerIndex = source.indexOf(marker);
  if (markerIndex < 0) return null;
  final start = source.indexOf('{', markerIndex + marker.length);
  if (start < 0) return null;
  var depth = 0;
  var quoted = false;
  var escaped = false;
  for (var i = start; i < source.length; i++) {
    final char = source[i];
    if (quoted) {
      if (escaped) {
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (char == '"') {
        quoted = false;
      }
      continue;
    }
    if (char == '"') quoted = true;
    if (char == '{') depth++;
    if (char == '}') {
      depth--;
      if (depth == 0) return source.substring(start, i + 1);
    }
  }
  return null;
}
