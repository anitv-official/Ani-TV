import 'dart:convert';

import 'package:http/http.dart' as http;

import 'html_client.dart';
import 'source_base.dart';

/// MovieBox web adapter.
///
/// MovieBox renders catalogue and detail pages as UTF-8 SSR HTML. Search and
/// detail data are therefore read from the public pages rather than relying on
/// an undocumented, unauthenticated API. The site's playback endpoint is
/// called only when a caller supplies a valid MovieBox JWT; no token is stored
/// in the application.
class MovieBoxSource extends ContentSource {
  static const String _base = 'https://movie-box.co';
  static const String _apiBase = 'https://h5-api.aoneroom.com';
  static const Duration _timeout = Duration(seconds: 15);
  static final http.Client _client = http.Client();

  @override
  String get id => 'moviebox';

  @override
  String get name => 'MovieBox';

  @override
  String get kind => 'drama';

  @override
  List<String> get hosts => const ['movie-box.co', 'moviebox.ph'];

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return const [];
    final uri = Uri.parse('$_base/web/searchResult').replace(
      queryParameters: {'keyword': value, 'page': '1'},
    );
    final html = await _getHtml(uri.toString());
    return _parseCards(html);
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final url = page <= 1 ? '$_base/' : '$_base/web/searchResult?page=$page';
    try {
      return _parseCards(await _getHtml(url));
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final pageUrl = _normalizeUrl(url);
    final html = await _getHtml(pageUrl);
    final title = _first(html, [
          RegExp(r'''<h1[^>]*>([\s\S]*?)</h1>''', caseSensitive: false),
          RegExp(r'''<title[^>]*>([\s\S]*?)</title>''', caseSensitive: false),
          RegExp(r'''<meta[^>]+property=["\']og:title["\'][^>]+content=["\']([^"\']+)''', caseSensitive: false),
        ]) ?? _slugTitle(pageUrl);
    final cleanTitle = HtmlParse.stripTags(title);
    final description = HtmlParse.stripTags(_first(html, [
          RegExp(r'''<div[^>]+class=["\'][^"\']*description[^"\']*["\'][^>]*>([\s\S]*?)</div>''', caseSensitive: false),
          RegExp(r'''<meta[^>]+(?:name|property)=["\']og:description["\'][^>]+content=["\']([^"\']+)''', caseSensitive: false),
        ]) ?? '');
    final poster = _poster(html, pageUrl);
    final genres = _all(html, RegExp(r'''<[^>]+class=["\'][^"\']*pc-genre-tag[^"\']*["\'][^>]*>([\s\S]*?)</[^>]+>''', caseSensitive: false))
        .map(HtmlParse.stripTags)
        .where((value) => value.isNotEmpty)
        .toList();
    final episodes = _episodes(html, pageUrl);
    final year = RegExp(r'''\b(19\d{2}|20\d{2})\b''').firstMatch(
          HtmlParse.stripTags(_first(html, [RegExp(r'''<main[\s\S]*?</main>''', caseSensitive: false)]) ?? html),
        )?.group(1) ?? '';
    final rating = _first(html, [
          RegExp(r'''class=["\'][^"\']*rate[^"\']*["\'][^>]*>([0-9]+(?:\.[0-9]+)?)<''', caseSensitive: false),
          RegExp(r'''"imdbRatingValue":"?([0-9]+(?:\.[0-9]+)?)''', caseSensitive: false),
        ]) ?? '';
    final subjectId = _subjectId(html, cleanTitle);
    return {
      ...item(
        title: cleanTitle,
        url: pageUrl,
        image: poster,
        type: 'drama',
        genres: genres,
        description: description,
        rating: rating,
      ),
      'synopsis': description,
      'poster': poster,
      'backdrop': _backdrop(html, poster),
      'year': year,
      'country': _first(html, [RegExp(r'''class=["\'][^"\']*country[^"\']*["\'][^>]*>([\s\S]*?)</''', caseSensitive: false)]) ?? '',
      'moviebox_subject_id': subjectId,
      'seasons': _seasonNumbers(episodes),
      'episodes': episodes,
      'total_episodes': episodes.length,
      'source_url': pageUrl,
    };
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final season = int.tryParse(uri.queryParameters['se'] ?? '') ?? 1;
    final episode = int.tryParse(uri.queryParameters['ep'] ?? '') ?? 1;
    final detailPath = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    final html = await _getHtml(_normalizeUrl(url).split('?').first);
    final title = HtmlParse.stripTags(_first(html, [RegExp(r'''<h1[^>]*>([\s\S]*?)</h1>''', caseSensitive: false)]) ?? '');
    final subjectId = _subjectId(html, title);
    if (subjectId.isEmpty) return null;

    final endpoint = Uri.parse('$_apiBase/wefeed-h5api-bff/subject/play').replace(queryParameters: {
      'subjectId': subjectId,
      'se': '$season',
      'ep': '$episode',
      'detailPath': detailPath,
      'streamSignType': '1',
    });
    try {
      final response = await _client.get(endpoint, headers: const {
        'Accept': 'application/json',
        'X-Request-Lang': 'en',
        'X-Vip-Restrict': '0',
      }).timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final data = decoded is Map ? decoded['data'] : null;
      if (data is! Map) return null;
      final links = <Map<String, dynamic>>[];
      for (final key in ['hls', 'dash', 'streams']) {
        final values = data[key];
        if (values is List) {
          for (final raw in values.whereType<Map>()) {
            final map = Map<String, dynamic>.from(raw);
            final media = (map['url'] ?? map['playUrl'] ?? map['videoUrl'] ?? '').toString();
            if (media.isNotEmpty) {
              links.add({'quality': (map['resolution'] ?? map['definition'] ?? key).toString(), 'url': media});
            }
          }
        }
      }
      if (links.isEmpty) return null;
      return {
        'source_id': id,
        'stream_url': links.first['url'],
        'direct_stream_urls': links,
        'headers': {'Referer': _base, 'User-Agent': HtmlClient.userAgent},
        'download_links': <String, dynamic>{},
      };
    } catch (_) {
      return null;
    }
  }

  Future<String> _getHtml(String url) async => HtmlClient.getHtml(url, useReaderFallback: false);

  List<Map<String, dynamic>> _parseCards(String html) {
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};
    // Search cards render their cover through a client-side lazy component,
    // so the <a> fragment itself has no <img>. The SSR payload still contains
    // the cover URLs in the same catalogue order as the cards.
    final catalogImages = RegExp(r'''https://pbcdnw?\.aoneroom\.com/image/[^" ]+''', caseSensitive: false)
        .allMatches(html)
        .map((match) => HtmlParse.decode(match.group(0)!).replaceAll(RegExp(r'''\?x-oss-process=.*$'''), ''))
        .toList();
    final cardPattern = RegExp(r'''<a\b[^>]+href=["\']([^"\']*/detail/[^"\']+)["\'][^>]*>([\s\S]*?)</a>''', caseSensitive: false);
    for (final match in cardPattern.allMatches(html)) {
      final url = HtmlParse.absUrl(_base, match.group(1)!);
      if (!seen.add(url)) continue;
      final fragment = match.group(2) ?? '';
      final title = _first(fragment, [
            RegExp(r'''<h2[^>]+title=["\']([^"\']+)''', caseSensitive: false),
            RegExp(r'''<h2[^>]*>([\s\S]*?)</h2>''', caseSensitive: false),
          ]) ?? _slugTitle(url);
      final rating = _first(fragment, [RegExp(r'''class=["\'][^"\']*rate[^"\']*["\'][^>]*>([^<]+)''', caseSensitive: false)]) ?? '';
      final image = _first(fragment, [
            RegExp(r'''<img[^>]+(?:src|data-src)=["\']([^"\']+)''', caseSensitive: false),
          ]) ?? (result.length < catalogImages.length ? catalogImages[result.length] : '');
      result.add(item(title: HtmlParse.stripTags(title), url: url, image: image, type: 'drama', rating: rating));
    }
    return result;
  }

  List<Map<String, dynamic>> _episodes(String html, String pageUrl) {
    final result = <Map<String, dynamic>>[];
    final seasonPattern = RegExp(r'''\{\s*"se"\s*:\s*(?:"?)(\d+)(?:"?)\s*,\s*"maxEp"\s*:\s*(?:"?)(\d+)(?:"?)''', caseSensitive: false);
    final added = <String>{};
    for (final match in seasonPattern.allMatches(html)) {
      final parsedSeason = int.tryParse(match.group(1)!) ?? 1;
      // Nuxt's devalue payload may encode a string-table reference (for
      // example 61 for the string "1") instead of the resolved season value.
      final season = parsedSeason > 20 ? 1 : parsedSeason;
      final max = int.tryParse(match.group(2)!) ?? 0;
      for (var number = 1; number <= max; number++) {
        if (!added.add('$season:$number')) continue;
        result.add({
          'title': 'الحلقة $number',
          'name': 'الحلقة $number',
          'url': '$pageUrl?se=$season&ep=$number',
          'number': number,
          'episode_number': number,
          'season': season,
          'season_number': season,
          'thumbnail': _poster(html, pageUrl),
        });
      }
    }
    return result;
  }

  List<int> _seasonNumbers(List<Map<String, dynamic>> episodes) => episodes.map((e) => e['season'] as int).toSet().toList()..sort();

  String _subjectId(String html, String title) {
    final values = RegExp(r'''"(\d{16,20})",\d+,"''').allMatches(html).map((m) => m.group(1)!).toList();
    return values.isEmpty ? '' : values.first;
  }

  String _poster(String html, String base) {
    final raw = _first(html, [
      RegExp(r'''<img[^>]+src=["\'](https?://pbcdn[^"\']+)''', caseSensitive: false),
      RegExp(r'''"(https://pbcdnw?\.aoneroom\.com/image/[^" ]+)"''', caseSensitive: false),
      RegExp(r'''<meta[^>]+(?:property|name)=["\']og:image["\'][^>]+content=["\']([^"\']+)''', caseSensitive: false),
    ]) ?? '';
    return HtmlParse.absUrl(base, raw).replaceAll(RegExp(r'''\?x-oss-process=.*$'''), '');
  }

  String _backdrop(String html, String fallback) => _first(html, [
        RegExp(r'''<video[^>]+poster=["\']([^"\']+)''', caseSensitive: false),
        RegExp(r'''"(https://pbcdnw?\.aoneroom\.com/media/[^" ]+\.jpg)"''', caseSensitive: false),
      ]) ?? fallback;

  String? _first(String text, List<RegExp> patterns) {
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.groupCount >= 1) return HtmlParse.decode(match.group(1)!.trim());
    }
    return null;
  }

  List<String> _all(String text, RegExp pattern) => pattern.allMatches(text).map((m) => m.group(1) ?? '').toList();

  String _normalizeUrl(String url) => url.startsWith('/') ? '$_base$url' : url;

  String _slugTitle(String url) {
    final last = Uri.decodeComponent(Uri.tryParse(url)?.pathSegments.last ?? url);
    final parts = last.split('-');
    if (parts.length <= 1) return last;
    return parts.sublist(0, parts.length - 1).join(' ');
  }
}
