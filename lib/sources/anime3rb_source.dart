import 'dart:convert';

import 'package:http/http.dart' as http;

import 'html_client.dart';
import 'source_base.dart';

class Anime3rbSource extends ContentSource {
  static const String _base = 'https://anime3rb.com';

  @override
  String get id => 'anime3rb';
  @override
  String get name => 'Anime3rb';
  @override
  String get kind => 'anime';
  @override
  List<String> get hosts => ['anime3rb.com', 'www.anime3rb.com'];

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final html = await HtmlClient.getHtml('$_base/titles/list?q=${Uri.encodeQueryComponent(query)}&page=1');
    final cards = _parseCards(html);
    return cards.isNotEmpty ? cards : _parseGeneric(html, query);
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final urls = page <= 1
        ? ['$_base/titles/list', '$_base/titles/list/tv', '$_base/']
        : ['$_base/titles/list?page=$page', '$_base/titles/list/tv?page=$page'];
    for (final pageUrl in urls) {
      try {
        final html = await HtmlClient.getHtml(pageUrl);
        final cards = _parseCards(html);
        if (cards.isNotEmpty) return cards;
        final generic = _parseGeneric(html, '');
        if (generic.isNotEmpty) return generic;
      } catch (_) {}
    }
    return [];
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final html = await HtmlClient.getHtml(url);
    final title = HtmlParse.stripTags(
      HtmlParse.meta(html, 'og:title') ??
          HtmlParse.firstMatch(html, [RegExp(r'<h1[^>]*>([\s\S]*?)</h1>', caseSensitive: false)]) ??
          HtmlParse.firstMatch(html, [RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false)]) ??
          'بدون عنوان',
    );
    final image = HtmlParse.meta(html, 'og:image') ??
        HtmlParse.firstMatch(html, [RegExp(r'<img[^>]+(?:data-src|src)=["\']([^"\']+)', caseSensitive: false)]) ??
        '';
    final description = HtmlParse.stripTags(
      HtmlParse.meta(html, 'og:description') ??
          HtmlParse.firstMatch(html, [RegExp(r'(?:story|description|synopsis)[^>]*>([\s\S]*?)</(?:div|p|span)>', caseSensitive: false)]) ??
          '',
    );
    final genres = HtmlParse.all(html, RegExp(r'href=["\'][^"\']*(?:genre|category)[^"\']*["\'][^>]*>([^<]+)<', caseSensitive: false));
    final episodes = _parseEpisodes(html, url);
    return {
      ...item(title: title, url: url, image: image, type: 'anime', genres: genres.toSet().toList(), description: description),
      'synopsis': description,
      'total_episodes': episodes.length,
      'episodes': episodes,
    };
  }

  @override
  Future<Map<String, dynamic>> streams(String episodeUrl) async {
    final page = await _getPage(episodeUrl, referer: _base);
    if (page == null || _isBlocked(page.body)) {
      throw Exception('Anime3rb: تعذر الوصول إلى صفحة الحلقة');
    }

    final candidates = <String>[];
    final seenCandidates = <String>{};
    void addCandidate(String raw) {
      final value = _absolute(episodeUrl, _normalize(raw));
      if (value.isEmpty || !seenCandidates.add(value)) return;
      final host = HtmlParse.hostOf(value);
      if (host.contains('facebook.com') || host.contains('twitter.com')) return;
      candidates.add(value);
    }

    for (final value in extractDirectMediaUrls(page.body, episodeUrl)) addCandidate(value);
    for (final value in extractServerUrls(page.body, episodeUrl)) addCandidate(value);

    final direct = <Map<String, String>>[];
    final seenDirect = <String>{};
    String? referer;
    void addDirect(String raw, String sourcePage, [String quality = 'مباشر']) {
      final value = _absolute(sourcePage, _normalize(raw));
      if (!_isDirectMediaUrl(value) || !seenDirect.add(value)) return;
      direct.add({'quality': quality, 'url': value});
      referer ??= sourcePage;
    }

    for (final candidate in candidates) {
      if (_isDirectMediaUrl(candidate)) {
        addDirect(candidate, episodeUrl);
        continue;
      }
      final response = await _getPage(candidate, referer: episodeUrl);
      if (response == null || _isBlocked(response.body)) continue;
      for (final media in extractDirectMediaUrls(response.body, candidate)) {
        addDirect(media, candidate, 'Anime3rb • مباشر');
      }
    }

    if (direct.isEmpty) {
      throw Exception('Anime3rb: لم يتم العثور على رابط HLS أو MP4 مباشر');
    }
    return {
      'source_id': id,
      'stream_url': direct.first['url'],
      'direct_stream_urls': direct.map((e) => {'quality': e['quality'], 'url': e['url']}).toList(),
      'headers': {'Referer': referer ?? episodeUrl, 'User-Agent': HtmlClient.userAgent},
      'download_links': {'مباشر': direct.map((e) => {'host': e['quality'], 'url': e['url']}).toList()},
    };
  }

  static Future<_Anime3rbResponse?> _getPage(String url, {required String referer}) async {
    try {
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': HtmlClient.userAgent,
        'Referer': referer,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'ar,en-US;q=0.9,en;q=0.8',
      }).timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      return _Anime3rbResponse(utf8.decode(response.bodyBytes, allowMalformed: true), response.statusCode);
    } catch (_) {
      return null;
    }
  }

  static List<String> extractServerUrls(String html, String pageUrl) {
    final normalized = _normalize(html);
    final urls = <String>{};
    void add(String raw) {
      final url = _absolute(pageUrl, _normalize(raw));
      if (url.isNotEmpty && !_isDirectMediaUrl(url)) urls.add(url);
    }
    for (final match in RegExp(r'''onclick\s*=\s*["'][^"']*(https?://[^"']+)[^"']*["']''', caseSensitive: false).allMatches(normalized)) {
      add(match.group(1)!);
    }
    for (final match in RegExp(r'''(?:data-(?:url|src|embed|link)|href)\s*=\s*["']([^"']+)["']''', caseSensitive: false).allMatches(normalized)) {
      final value = match.group(1)!;
      if (_looksLikeServer(value)) add(value);
    }
    for (final match in RegExp(r'''https?://[^\s"'<>]+(?:vid3rb|3rbcdn|vidmoly|streamtape|filemoon|uqload|/embed/)[^\s"'<>]*''', caseSensitive: false).allMatches(normalized)) {
      add(match.group(0)!);
    }
    return urls.toList();
  }

  static List<String> extractDirectMediaUrls(String html, String pageUrl) {
    final normalized = _normalize(html);
    final urls = <String>{};
    void add(String raw) {
      final url = _absolute(pageUrl, _normalize(raw));
      if (_isDirectMediaUrl(url)) urls.add(url);
    }
    for (final match in RegExp(r'''(?:src|data-src|data-url|file|source|url|hls|playlist)\s*[:=]\s*["']([^"']+)["']''', caseSensitive: false).allMatches(normalized)) {
      add(match.group(1)!);
    }
    for (final match in RegExp(r'''(?:https?:)?//[^\s"'<>]+\.m3u8(?:\?[^\s"'<>]*)?''', caseSensitive: false).allMatches(normalized)) {
      add(match.group(0)!);
    }
    for (final match in RegExp(r'''https?://[^\s"'<>]+\.(?:mp4|mov|webm)(?:\?[^\s"'<>]*)?''', caseSensitive: false).allMatches(normalized)) {
      add(match.group(0)!);
    }
    return urls.toList();
  }

  static String _normalize(String value) => value
      .replaceAll(r'\/', '/')
      .replaceAll(r'\"', '"')
      .replaceAll(r'\u0026', '&')
      .replaceAll(r'\u003F', '?')
      .replaceAll(r'\u003f', '?')
      .replaceAll(r'\u003D', '=')
      .replaceAll(r'\u003d', '=');

  static String _absolute(String base, String raw) {
    if (raw.trim().isEmpty) return '';
    try {
      final value = raw.trim();
      if (value.startsWith('//')) return 'https:$value';
      return Uri.parse(base).resolve(value).toString();
    } catch (_) {
      return '';
    }
  }

  static bool _isDirectMediaUrl(String value) {
    final lower = value.toLowerCase();
    return RegExp(r'\.(?:mp4|m3u8|mov|webm)(?:[?#].*)?$').hasMatch(lower) || lower.contains('pixeldrain.com/api/file');
  }

  static bool _looksLikeServer(String value) {
    final lower = value.toLowerCase();
    return lower.contains('vid3rb') || lower.contains('3rbcdn') || lower.contains('vidmoly') || lower.contains('streamtape') || lower.contains('filemoon') || lower.contains('uqload') || lower.contains('/embed/') || lower.contains('/server');
  }

  bool _isBlocked(String body) {
    final lower = body.toLowerCase();
    return lower.contains('just a moment') || lower.contains('cf-mitigated') || (lower.contains('challenge-platform') && body.length < 20000);
  }

  List<Map<String, dynamic>> _parseCards(String html) {
    final items = <Map<String, dynamic>>[];
    final seen = <String>{};
    final pattern = RegExp(r'''<a[^>]+href=["']([^"']*/titles/[^"']+)["'][\s\S]{0,900}?(?:alt|title)=["']([^"']+)["']''', caseSensitive: false);
    for (final match in pattern.allMatches(html)) {
      final url = _absolute(_base, match.group(1)!);
      if (!seen.add(url)) continue;
      items.add(item(title: HtmlParse.stripTags(match.group(2)!), url: url, type: 'anime'));
    }
    return items;
  }

  List<Map<String, dynamic>> _parseGeneric(String html, String query) {
    final items = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final match in RegExp(r'''href=["'](https?://anime3rb\.com/titles/[^"']+)["'][^>]*>([\s\S]*?)</a>''', caseSensitive: false).allMatches(html)) {
      final title = HtmlParse.stripTags(match.group(2) ?? '');
      final url = match.group(1)!;
      if (title.isEmpty || !seen.add(url)) continue;
      if (query.isNotEmpty && !title.toLowerCase().contains(query.toLowerCase()) && !url.toLowerCase().contains(query.toLowerCase())) continue;
      items.add(item(title: title, url: url, type: 'anime'));
    }
    return items;
  }

  List<Map<String, dynamic>> _parseEpisodes(String html, String pageUrl) {
    final episodes = <Map<String, dynamic>>[];
    final seen = <String>{};
    final titleMatch = RegExp(r'/titles/([^/?#]+)', caseSensitive: false).firstMatch(pageUrl);
    final count = _episodeCount(html);
    if (titleMatch != null && count != null) {
      for (var i = 1; i <= count; i++) {
        episodes.add({'title': 'الحلقة $i', 'name': 'الحلقة $i', 'url': '$_base/episode/${titleMatch.group(1)}/$i', 'number': i});
      }
      return episodes;
    }
    for (final match in RegExp(r'''<a[^>]+href=["']([^"']+/episode/[^"']+)["'][^>]*>([\s\S]*?)</a>''', caseSensitive: false).allMatches(html)) {
      final url = _absolute(pageUrl, match.group(1)!);
      if (!seen.add(url)) continue;
      final number = SourceUtils.episodeNumber('${match.group(2)} $url');
      if (number == null) continue;
      episodes.add({'title': 'الحلقة $number', 'name': 'الحلقة $number', 'url': url, 'number': number});
    }
    episodes.sort((a, b) => (a['number'] as int).compareTo(b['number'] as int));
    return episodes;
  }

  int? _episodeCount(String html) {
    final values = <int>[];
    for (final pattern in [
      RegExp(r'(?:عدد الحلقات|عدد حلقات|episodes?|episode_count)[^0-9]{0,80}(\d+)', caseSensitive: false),
      RegExp(r'"(?:episodes|episode_count|episodes_count)"\s*:\s*(\d+)', caseSensitive: false),
    ]) {
      values.addAll(pattern.allMatches(html).map((m) => int.tryParse(m.group(1)!)).whereType<int>());
    }
    final count = values.where((n) => n > 0 && n <= 2000).fold(0, (a, b) => b > a ? b : a);
    return count == 0 ? null : count;
  }
}

class _Anime3rbResponse {
  final String body;
  final int statusCode;
  const _Anime3rbResponse(this.body, this.statusCode);
}
