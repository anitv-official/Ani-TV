import 'dart:convert';

import 'package:http/http.dart' as http;

import 'html_client.dart';
import 'source_base.dart';

/// CimaLight HTML source for movies and episodic video pages.
class CimaLightSource extends ContentSource {
  static const String _base = 'https://e.cimalight.co';
  static const Duration _timeout = Duration(seconds: 15);
  static final http.Client _client = http.Client();

  @override
  String get id => 'cimalight';

  @override
  String get name => 'CimaLight';

  @override
  String get kind => 'drama';

  @override
  List<String> get hosts => const ['e.cimalight.co', 'cimalight.co'];

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return const [];
    final html = await _getHtml('$_base/search.php?keywords=${Uri.encodeQueryComponent(value)}');
    return parseCards(html, _base);
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final path = page <= 1 ? '$_base/movies.php' : '$_base/movies.php?page=$page';
    try {
      return parseCards(await _getHtml(path), _base);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final pageUrl = HtmlParse.absUrl(_base, url);
    final html = await _getHtml(pageUrl);
    final title = _first(html, [
          RegExp(r'<meta[^>]+property=["\']og:title["\'][^>]+content=["\']([^"\']+)', caseSensitive: false),
          RegExp(r'<h1[^>]*>([\s\S]*?)</h1>', caseSensitive: false),
          RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false),
        ]) ?? 'بدون عنوان';
    final description = _first(html, [
          RegExp(r'<meta[^>]+name=["\']description["\'][^>]+content=["\']([^"\']+)', caseSensitive: false),
          RegExp(r'<meta[^>]+property=["\']og:description["\'][^>]+content=["\']([^"\']+)', caseSensitive: false),
          RegExp(r'<div[^>]+class=["\'][^"\']*(?:desc|description|story)[^"\']*["\'][^>]*>([\s\S]*?)</div>', caseSensitive: false),
        ]) ?? '';
    final image = HtmlParse.absUrl(pageUrl, _first(html, [
          RegExp(r'<meta[^>]+property=["\']og:image["\'][^>]+content=["\']([^"\']+)', caseSensitive: false),
          RegExp(r'<img[^>]+(?:src|data-src)=["\']([^"\']+)', caseSensitive: false),
        ]) ?? '');
    final episode = <String, dynamic>{
      'title': title,
      'name': title,
      'url': pageUrl,
      'number': 1,
      'episode_number': 1,
      'thumbnail': image,
    };
    return {
      ...item(title: title, url: pageUrl, image: image, type: 'drama', description: description),
      'synopsis': description,
      'poster': image,
      'backdrop': image,
      'episodes': [episode],
      'total_episodes': 1,
      'source_url': pageUrl,
    };
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async {
    final pageUrl = HtmlParse.absUrl(_base, url);
    final html = await _getHtml(pageUrl);
    final candidates = <String>{};
    for (final raw in [
      ..._all(html, RegExp(r'<iframe[^>]+src=["\']([^"\']+)', caseSensitive: false)),
      ..._all(html, RegExp(r'(?:data-(?:url|embed|src)|href)=["\']([^"\']+)', caseSensitive: false)),
      ...SourceUtils.extractMediaUrls(html, pageUrl),
    ]) {
      final value = HtmlParse.absUrl(pageUrl, raw);
      if (value.isEmpty || _isNoise(value) || value == pageUrl) continue;
      candidates.add(value);
    }
    if (candidates.isEmpty) return null;
    final direct = candidates.where(_isDirect).toList();
    final links = (direct.isNotEmpty ? direct : candidates.toList())
        .map((value) => {'quality': _quality(value), 'url': value})
        .toList();
    return {
      'source_id': id,
      'stream_url': links.first['url'],
      'direct_stream_urls': links,
      'servers': candidates.toList(),
      'headers': {'Referer': pageUrl, 'User-Agent': HtmlClient.userAgent},
      'download_links': <String, dynamic>{},
    };
  }

  static List<Map<String, dynamic>> parseCards(String html, String base) {
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};
    final pattern = RegExp(r'<a[^>]+href=["\']([^"\']*watch\.php\?vid=[^"\']+)["\'][^>]*>([\s\S]*?)</a>', caseSensitive: false);
    for (final match in pattern.allMatches(html)) {
      final url = HtmlParse.absUrl(base, match.group(1)!).split('#').first;
      if (!seen.add(url)) continue;
      final fragment = match.group(2) ?? '';
      final title = _first(fragment, [
            RegExp(r'title=["\']([^"\']+)', caseSensitive: false),
            RegExp(r'alt=["\']([^"\']+)', caseSensitive: false),
          ]) ?? _first(html.substring(match.start, match.end), [RegExp(r'>\s*([^<]{3,})\s*</a>', caseSensitive: false)]) ?? 'بدون عنوان';
      final image = HtmlParse.absUrl(base, _first(fragment, [RegExp(r'(?:src|data-src)=["\']([^"\']+)', caseSensitive: false)]) ?? '');
      result.add({
        'title': HtmlParse.stripTags(title),
        'url': url,
        'image_url': image,
        'type': 'drama',
        'category': 'drama',
        'source': 'CimaLight',
        'source_id': 'cimalight',
        'genres': const <dynamic>[],
        'description': '',
        'rating': '',
      });
    }
    return result;
  }

  Future<String> _getHtml(String url) async {
    final response = await _client.get(Uri.parse(url), headers: {'User-Agent': HtmlClient.userAgent, 'Accept': 'text/html'}).timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('CimaLight HTTP ${response.statusCode}');
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  static String? _first(String text, List<RegExp> patterns) {
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.groupCount > 0) return HtmlParse.stripTags(HtmlParse.decode(match.group(1)!.trim()));
    }
    return null;
  }

  List<String> _all(String text, RegExp pattern) => pattern.allMatches(text).map((m) => HtmlParse.decode(m.group(1) ?? '')).where((v) => v.isNotEmpty).toList();
  bool _isDirect(String value) => RegExp(r'\.(?:mp4|m3u8|mov|webm|mkv)(?:[?#].*)?$', caseSensitive: false).hasMatch(value);
  bool _isNoise(String value) => value.contains('facebook.com') || value.contains('twitter.com') || value.contains('pinterest.com') || value.contains('doubleclick.net') || value.contains('youtube.com') || value.contains('google.com');
  String _quality(String value) => RegExp(r'(2160|1440|1080|720|480|360)p?', caseSensitive: false).firstMatch(value)?.group(1) ?? 'مباشر';
}
