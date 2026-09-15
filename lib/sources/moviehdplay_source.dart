import 'dart:convert';

import 'package:http/http.dart' as http;

import 'html_client.dart';
import 'source_base.dart';

/// MovieHDPlay/123Movies HTML source.
///
/// The site exposes catalogue and detail pages as server-rendered HTML. The
/// source intentionally extracts only links published in those pages; it does
/// not attempt to bypass login, CAPTCHA, or protected playback endpoints.
class MovieHdPlaySource extends ContentSource {
  static const String _base = 'https://moviehdplay.xyz';
  static const Duration _timeout = Duration(seconds: 15);
  static final http.Client _client = http.Client();

  @override
  String get id => 'moviehdplay';

  @override
  String get name => 'MovieHDPlay';

  @override
  String get kind => 'drama';

  @override
  List<String> get hosts => const ['moviehdplay.xyz'];

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return const [];
    final encoded = Uri.encodeComponent(value).replaceAll('%20', '+');
    final url = '$_base/search/$encoded.html';
    return _parseCards(await _getHtml(url));
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final url = page <= 1 ? '$_base/movies/' : '$_base/movies/$page/';
    try {
      return _parseCards(await _getHtml(url));
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final pageUrl = HtmlParse.absUrl(_base, url);
    final html = await _getHtml(pageUrl);
    final title = HtmlParse.stripTags(HtmlParse.meta(html, 'og:title') ??
        _first(html, [
          RegExp(r'''<h1[^>]*>([\s\S]*?)</h1>''', caseSensitive: false),
          RegExp(r'''<title[^>]*>([\s\S]*?)</title>''', caseSensitive: false),
        ]) ?? _slugTitle(pageUrl));
    final description = HtmlParse.stripTags(HtmlParse.meta(html, 'og:description') ??
        HtmlParse.meta(html, 'description') ??
        _first(html, [
          RegExp(r'''<p[^>]+class=["'][^"']*(?:f-desc|description|desc)[^"']*["'][^>]*>([\s\S]*?)</p>''', caseSensitive: false),
        ]) ?? '');
    final image = _image(html, pageUrl);
    final rating = _first(html, [
          RegExp(r'''class=["'][^"']*(?:imdb|rating)[^"']*["'][^>]*>[^<]*([0-9]+(?:\.[0-9]+)?)''', caseSensitive: false),
          RegExp(r'''IMDb\s*:\s*([0-9]+(?:\.[0-9]+)?)''', caseSensitive: false),
        ]) ?? '';
    final year = RegExp(r'\b(19\d{2}|20\d{2})\b').firstMatch(title)?.group(1) ?? '';
    final trailer = _first(html, [
          RegExp(r'''<input[^>]+name=["']trailer_url["'][^>]+value=["']([^"']+)''', caseSensitive: false),
          RegExp(r'''<iframe[^>]+src=["']([^"']+youtube[^"']*)''', caseSensitive: false),
        ]) ?? '';
    final servers = _serverLinks(html, pageUrl);
    return {
      ...item(title: title, url: pageUrl, image: image, type: 'drama', description: description, rating: rating),
      'synopsis': description,
      'poster': image,
      'backdrop': image,
      'year': year,
      'trailer': HtmlParse.absUrl(pageUrl, trailer),
      'episodes': <Map<String, dynamic>>[
        {
          'title': title,
          'name': title,
          'url': pageUrl,
          'number': 1,
          'episode_number': 1,
          'thumbnail': image,
        },
      ],
      'total_episodes': 1,
      'servers': servers,
      'source_url': pageUrl,
    };
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async {
    final pageUrl = HtmlParse.absUrl(_base, url);
    final html = await _getHtml(pageUrl);
    final candidates = <String>{};
    for (final raw in [
      ..._all(html, RegExp(r'''<iframe[^>]+src=["']([^"']+)["']''', caseSensitive: false)),
      ..._all(html, RegExp(r'''(?:data-?(?:url|embed|src)|href)=["']([^"']+)["']''', caseSensitive: false)),
      ...SourceUtils.extractMediaUrls(html, pageUrl),
    ]) {
      final value = HtmlParse.absUrl(pageUrl, raw);
      if (value.isEmpty || value.contains('youtube.com') || value.contains('youtube-nocookie.com')) continue;
      if (_isNoise(value)) continue;
      candidates.add(value);
    }
    final direct = candidates.where(_isDirect).toList();
    if (candidates.isEmpty) return null;
    final directLinks = direct.map((value) => {'quality': _quality(value), 'url': value}).toList();
    return {
      'source_id': id,
      'stream_url': direct.isNotEmpty ? direct.first : candidates.first,
      'direct_stream_urls': directLinks,
      'servers': candidates.toList(),
      'headers': {'Referer': pageUrl, 'User-Agent': HtmlClient.userAgent},
      'download_links': <String, dynamic>{},
    };
  }

  Future<String> _getHtml(String url) async {
    final response = await _client.get(Uri.parse(url), headers: {'User-Agent': HtmlClient.userAgent, 'Accept': 'text/html'})
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('MovieHDPlay HTTP ${response.statusCode}');
    }
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  List<Map<String, dynamic>> _parseCards(String html) {
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};
    final pattern = RegExp(r'''<a[^>]+href=["']([^"']*/movie/[^"']+)["'][^>]*>([\s\S]*?)</a>''', caseSensitive: false);
    for (final match in pattern.allMatches(html)) {
      final url = HtmlParse.absUrl(_base, match.group(1)!).split('#').first;
      if (!seen.add(url)) continue;
      final fragment = match.group(2) ?? '';
      final title = _first(fragment, [
            RegExp(r'''title=["']([^"']+)["']''', caseSensitive: false),
            RegExp(r'''<h[1-6][^>]*>([\s\S]*?)</h[1-6]>''', caseSensitive: false),
            RegExp(r'''alt=["']([^"']+)["']''', caseSensitive: false),
          ]) ?? _slugTitle(url);
      final image = _first(fragment, [
            RegExp(r'''(?:data-original|data-src|src)=["']([^"']+)["']''', caseSensitive: false),
            RegExp(r'''background-image\s*:\s*url\(["']?([^"')]+)''', caseSensitive: false),
          ]) ?? '';
      final rating = _first(fragment, [RegExp(r'''(?:IMDb|imdb)[^0-9]*([0-9]+(?:\.[0-9]+)?)''', caseSensitive: false)]) ?? '';
      result.add(item(title: HtmlParse.stripTags(title), url: url, image: HtmlParse.absUrl(url, image), type: 'drama', rating: rating));
    }
    return result;
  }

  List<String> _serverLinks(String html, String pageUrl) => _all(html, RegExp(r'''<iframe[^>]+src=["']([^"']+)["']''', caseSensitive: false))
      .map((raw) => HtmlParse.absUrl(pageUrl, raw))
      .where((url) => url.isNotEmpty && !url.contains('youtube.com'))
      .toList();

  String _image(String html, String base) => HtmlParse.absUrl(base, HtmlParse.meta(html, 'og:image') ?? HtmlParse.meta(html, 'twitter:image') ?? '');

  String? _first(String text, List<RegExp> patterns) {
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.groupCount > 0) return HtmlParse.decode(match.group(1)!.trim());
    }
    return null;
  }

  List<String> _all(String text, RegExp pattern) => pattern.allMatches(text).map((m) => HtmlParse.decode(m.group(1) ?? '')).where((v) => v.isNotEmpty).toList();

  String _slugTitle(String url) {
    final last = Uri.decodeComponent(Uri.tryParse(url)?.pathSegments.last ?? url).replaceAll(RegExp(r'[-_]+'), ' ');
    return last.replaceFirst(RegExp(r'\s+\d+$'), '').trim();
  }

  bool _isDirect(String value) => RegExp(r'\.(?:mp4|m3u8|mov|webm|mkv)(?:[?#].*)?$', caseSensitive: false).hasMatch(value);
  bool _isNoise(String value) => value.contains('facebook.com') || value.contains('twitter.com') || value.contains('pinterest.com') || value.contains('doubleclick.net');
  String _quality(String value) {
    final match = RegExp(r'(\d{3,4})p', caseSensitive: false).firstMatch(value);
    return match == null ? 'مباشر' : '${match.group(1)}p';
  }
}
