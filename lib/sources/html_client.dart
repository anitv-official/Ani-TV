import 'dart:convert';
import 'package:http/http.dart' as http;

class HtmlClient {
  static const Duration timeout = Duration(seconds: 10);
  static const Duration readerTimeout = Duration(seconds: 8);
  static const Duration cacheDuration = Duration(minutes: 3);
  static final Map<String, _CachedHtml> _cache = {};
  static const String userAgent =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36';

  static const Map<String, String> _headers = {
    'User-Agent': userAgent,
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,application/json;q=0.8,*/*;q=0.7',
    'Accept-Language': 'ar,en-US;q=0.9,en;q=0.8',
    'Cache-Control': 'no-cache',
  };

  static Future<String> getHtml(String url, {bool useReaderFallback = true}) async {
    final cached = _cache[url];
    if (cached != null && DateTime.now().difference(cached.createdAt) < cacheDuration) {
      return cached.body;
    }
    final direct = await _tryGet(url);
    if (direct != null && !_isBlocked(direct)) {
      final body = _unwrap(direct);
      _cache[url] = _CachedHtml(body);
      return body;
    }
    if (!useReaderFallback) {
      throw Exception('تعذر تحميل المحتوى');
    }
    final reader = await _tryGet(_readerUrl(url), timeoutOverride: readerTimeout);
    if (reader != null && !_isBlocked(reader) && reader.length > 200) {
      final body = _unwrap(reader);
      _cache[url] = _CachedHtml(body);
      return body;
    }
    throw Exception('تعذر تحميل المحتوى');
  }

  static Future<dynamic> getJson(String url, {Map<String, String>? headers}) async {
    final response = await http
        .get(Uri.parse(url), headers: {..._headers, ...?headers})
        .timeout(timeoutOverride ?? timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('تعذر تحميل المحتوى');
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  static Future<bool> urlExists(String url) async {
    try {
      final response = await http
          .head(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode >= 200 && response.statusCode < 400) return true;
      if (response.statusCode == 405 || response.statusCode == 501) {
        final get = await http
            .get(Uri.parse(url), headers: _headers)
            .timeout(const Duration(seconds: 8));
        return get.statusCode >= 200 && get.statusCode < 400;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> _tryGet(String url, {Duration? timeoutOverride}) async {
    try {
      final response =
          await http.get(Uri.parse(url), headers: _headers).timeout(timeoutOverride ?? timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      return utf8.decode(response.bodyBytes, allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  static String _unwrap(String body) {
    final trimmed = body.trim();
    if (trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map && decoded['data'] is Map) {
          final data = decoded['data'] as Map;
          final content = data['content']?.toString() ?? '';
          if (content.length > 80) return content;
        }
      } catch (_) {}
    }
    return body;
  }

  static bool _isBlocked(String body) {
    final lower = body.toLowerCase();
    return lower.contains('just a moment') ||
        lower.contains('cf-mitigated') ||
        lower.contains('challenge-platform') ||
        lower.contains('performing security verification') ||
        (lower.contains('enable javascript and cookies to continue') &&
            body.length < 8000);
  }

  static void clearCache() => _cache.clear();

  static String _readerUrl(String url) {
    final uri = Uri.parse(url);
    final httpUrl = uri.replace(scheme: 'http').toString();
    return 'https://r.jina.ai/$httpUrl';
  }
}

class _CachedHtml {
  final String body;
  final DateTime createdAt = DateTime.now();
  _CachedHtml(this.body);
}

class HtmlParse {
  static String decode(String value) {
    var text = value
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#x27;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');
    text = text.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
      final code = int.tryParse(match.group(1) ?? '');
      return code == null ? match.group(0)! : String.fromCharCode(code);
    });
    text = text.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
      final code = int.tryParse(match.group(1) ?? '', radix: 16);
      return code == null ? match.group(0)! : String.fromCharCode(code);
    });
    return text;
  }

  static String stripTags(String value) {
    return decode(value.replaceAll(RegExp(r'<[^>]+>'), ' '))
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String absUrl(String base, String value) {
    final raw = decode(value.trim());
    if (raw.isEmpty) return '';
    if (raw.startsWith('//')) return 'https:$raw';
    final resolved = Uri.parse(base).resolve(raw);
    return resolved.toString();
  }

  static String? meta(String html, String property) {
    final patterns = [
      RegExp(
          '<meta[^>]+(?:property|name)=["\']$property["\'][^>]+content=["\']([^"\']+)["\']',
          caseSensitive: false),
      RegExp(
          '<meta[^>]+content=["\']([^"\']+)["\'][^>]+(?:property|name)=["\']$property["\']',
          caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match != null) return decode(match.group(1)!);
    }
    return null;
  }

  static String? firstMatch(String html, List<RegExp> patterns, [int group = 1]) {
    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match != null && match.groupCount >= group) {
        final value = match.group(group);
        if (value != null && value.trim().isNotEmpty) return decode(value.trim());
      }
    }
    return null;
  }

  static List<String> all(String html, RegExp pattern, [int group = 1]) {
    return pattern
        .allMatches(html)
        .map((m) => decode((m.group(group) ?? '').trim()))
        .where((v) => v.isNotEmpty)
        .toList();
  }

  static String hostOf(String url) {
    try {
      return Uri.parse(url).host.toLowerCase().replaceFirst('www.', '');
    } catch (_) {
      return '';
    }
  }

  static String slugify(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  static List<Map<String, String>> markdownLinks(String markdown) {
    final results = <Map<String, String>>[];
    final seen = <String>{};
    final pattern = RegExp(r'\[([^\]]*)\]\((https?:[^)\s]+)(?:\s+"([^"]*)")?\)');
    for (final match in pattern.allMatches(markdown)) {
      final url = match.group(2) ?? '';
      if (url.isEmpty || seen.contains(url)) continue;
      seen.add(url);
      results.add({
        'title': decode(match.group(3) ?? match.group(1) ?? '').trim(),
        'url': url,
      });
    }
    return results;
  }
}
