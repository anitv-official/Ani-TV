import 'html_client.dart';
import 'source_base.dart';

class RistoAnimeSource extends ContentSource {
  static const String _base = 'https://ristoanime.me';

  @override
  String get id => 'risto';

  @override
  String get name => 'Risto Anime';

  @override
  String get kind => 'anime';

  @override
  List<String> get hosts => ['ristoanime.me'];

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final html = await HtmlClient.getHtml(
        '$_base/?s=${Uri.encodeQueryComponent(query)}');
    final cards = _parseMovieItems(html);
    if (cards.isNotEmpty) return _dedupeSeries(cards);
    return _searchViaWp(query);
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final html = await HtmlClient.getHtml('$_base/series/page/$page/');
    final cards = _parseMovieItems(html);
    if (cards.isNotEmpty) return cards;
    return _searchViaWp('');
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final html = await HtmlClient.getHtml(url);
    final title = HtmlParse.stripTags(
      HtmlParse.meta(html, 'og:title') ??
          HtmlParse.firstMatch(html, [
            RegExp(r'<h1[^>]*>(.*?)</h1>', caseSensitive: false, dotAll: true)
          ]) ??
          HtmlParse.firstMatch(html, [
            RegExp(r'<title[^>]*>(.*?)</title>',
                caseSensitive: false, dotAll: true)
          ]) ??
          'بدون عنوان',
    );
    final image = HtmlParse.meta(html, 'og:image') ??
        HtmlParse.firstMatch(html, [
              RegExp(r'class="poster"[^>]*url\(([^)]+)\)', caseSensitive: false),
            ]) ??
            '';
    final description = HtmlParse.stripTags(
      HtmlParse.meta(html, 'og:description') ??
          HtmlParse.firstMatch(html, [
            RegExp(r'class="StoryArea"[^>]*>([\s\S]*?)</div>',
                caseSensitive: false),
            RegExp(r'class="story"[^>]*>([\s\S]*?)</(?:div|p)>',
                caseSensitive: false),
          ]) ??
          '',
    );
    final genres = HtmlParse.all(
        html, RegExp(r'class="genre"[^>]*>([^<]+)<', caseSensitive: false));
    if (genres.isEmpty) {
      genres.addAll(HtmlParse.all(
        html,
        RegExp(r'href="[^"]*genre[^"]*"[^>]*>([^<]+)<', caseSensitive: false),
      ));
    }
    final rating = HtmlParse.firstMatch(html, [
          RegExp(r'class="release-year"[^>]*>[\s\S]*?([\d.]+)\s*/\s*10',
              caseSensitive: false),
          RegExp(r'(\d+(?:\.\d+)?)\s*/\s*10'),
        ]) ??
        '';
    final episodes = await _collectEpisodes(url, html);
    return {
      ...item(
        title: title,
        url: url,
        image: image,
        type: 'anime',
        genres: genres.toSet().toList(),
        description: description,
        rating: rating,
      ),
      'synopsis': description,
      'total_episodes': episodes.length,
      'episodes': episodes,
    };
  }

  @override
  Future<Map<String, dynamic>> streams(String url) async {
    final html = await HtmlClient.getHtml(url);
    final servers = <Map<String, String>>[];
    final seen = <String>{};

    void add(String raw, [String quality = 'خادم']) {
      final resolved = HtmlParse.absUrl(url, raw);
      if (resolved.isEmpty || seen.contains(resolved)) return;
      if (resolved.contains('facebook.com') || resolved.contains('twitter.com')) {
        return;
      }
      seen.add(resolved);
      servers.add({'quality': quality, 'url': resolved});
    }

    for (final match in RegExp(
      r'<iframe[^>]+src=["' "'" r']([^"' "'" r']+)["' "'" r']',
      caseSensitive: false,
    ).allMatches(html)) {
      add(match.group(1)!, 'مشغل');
    }
    for (final match in RegExp(
      r'data-(?:src|url|embed|link)=["' "'" r']([^"' "'" r']+)["' "'" r']',
      caseSensitive: false,
    ).allMatches(html)) {
      add(match.group(1)!);
    }
    for (final match in RegExp(
      r'https?://[^\s"<>]+(?:ok\.ru|dood|mp4upload|vidmoly|uqload|streamtape|filemoon|voe|mixdrop|yourupload|goload|sbfull|sbplay|krakenfiles|pixeldrain|vudeo|lulustream|vidhide)[^\s"<>]*',
      caseSensitive: false,
    ).allMatches(html)) {
      add(match.group(0)!);
    }
    for (final match in RegExp(
      r'https?://[^\s"<>]+\.(?:mp4|m3u8)[^\s"<>]*',
      caseSensitive: false,
    ).allMatches(html)) {
      add(match.group(0)!, 'مباشر');
    }

    if (servers.isEmpty) {
      add(url, 'صفحة الحلقة');
    }

    final direct = servers
        .where((s) =>
            s['url']!.contains('.mp4') ||
            s['url']!.contains('.m3u8') ||
            s['url']!.contains('pixeldrain'))
        .toList();
    return {
      'stream_url': servers.first['url'],
      'direct_stream_urls': direct.isNotEmpty ? direct : servers,
      'download_links': <String, dynamic>{},
    };
  }

  Future<List<Map<String, dynamic>>> _searchViaWp(String query) async {
    final encoded = Uri.encodeQueryComponent(query);
    final data = await HtmlClient.getJson(
      '$_base/wp-json/wp/v2/posts?search=$encoded&_embed=1&per_page=20',
    ) as List<dynamic>;
    final items = <Map<String, dynamic>>[];
    for (final raw in data) {
      if (raw is! Map) continue;
      final title =
          HtmlParse.stripTags((raw['title']?['rendered'] ?? '').toString());
      final link = (raw['link'] ?? '').toString();
      if (title.isEmpty || link.isEmpty) continue;
      String image = '';
      final embedded = raw['_embedded'];
      if (embedded is Map &&
          embedded['wp:featuredmedia'] is List &&
          (embedded['wp:featuredmedia'] as List).isNotEmpty) {
        image = ((embedded['wp:featuredmedia'] as List)
                    .first['source_url'] ??
                '')
            .toString();
      }
      items.add(item(title: title, url: link, image: image, type: 'anime'));
    }
    return _dedupeSeries(items);
  }

  List<Map<String, dynamic>> _parseMovieItems(String html) {
    final items = <Map<String, dynamic>>[];
    final seen = <String>{};
    final pattern = RegExp(
      r'class="MovieItem">\s*<a href="([^"]+)">([\s\S]*?)</a>',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(html)) {
      final url = HtmlParse.absUrl(_base, match.group(1)!);
      if (url.contains('/page/') || url.contains('/feed') || !seen.add(url)) {
        continue;
      }
      final block = match.group(2) ?? '';
      final title = HtmlParse.stripTags(
        HtmlParse.firstMatch(block, [
              RegExp(r'<h4[^>]*>([\s\S]*?)</h4>', caseSensitive: false)
            ]) ??
            '',
      );
      if (title.isEmpty) continue;
      final image = HtmlParse.firstMatch(block, [
            RegExp(r'url\(([^)]+)\)', caseSensitive: false),
            RegExp(r'src="([^"]+)"', caseSensitive: false),
          ]) ??
          '';
      final genre = HtmlParse.firstMatch(
          block, [RegExp(r'class="genre"[^>]*>([^<]+)<', caseSensitive: false)]);
      final rating =
          HtmlParse.firstMatch(block, [RegExp(r'([\d.]+)\s*/\s*10')]) ?? '';
      items.add(item(
        title: title,
        url: url,
        image: image.replaceAll("'", '').replaceAll('"', ''),
        type: 'anime',
        genres: genre == null || genre.isEmpty ? [] : [genre],
        rating: rating,
      ));
    }
    return items;
  }

  List<Map<String, dynamic>> _dedupeSeries(List<Map<String, dynamic>> items) {
    final grouped = <String, Map<String, dynamic>>{};
    for (final entry in items) {
      final url = (entry['url'] ?? '').toString();
      final isSeries = url.contains('/series/');
      final key =
          isSeries ? url : SourceUtils.seriesKey(entry['title']?.toString() ?? '');
      if (key.isEmpty) continue;
      final existing = grouped[key];
      if (existing == null ||
          (isSeries &&
              !(existing['url'] ?? '').toString().contains('/series/'))) {
        grouped[key] = {
          ...entry,
          'title': isSeries
              ? entry['title']
              : SourceUtils.seriesKey(entry['title']?.toString() ?? ''),
        };
      }
    }
    return grouped.values.toList();
  }

  Future<List<Map<String, dynamic>>> _collectEpisodes(
      String seriesUrl, String firstHtml) async {
    final collected = <String, Map<String, dynamic>>{};
    var html = firstHtml;
    for (var page = 1; page <= 40; page++) {
      _parseEpisodesFromHtml(html, collected);
      final nextPage = page + 1;
      if (!html.contains('/page/$nextPage/')) break;
      final nextUrl = seriesUrl.endsWith('/')
          ? '${seriesUrl}page/$nextPage/'
          : '$seriesUrl/page/$nextPage/';
      try {
        html = await HtmlClient.getHtml(nextUrl);
      } catch (_) {
        break;
      }
    }
    final episodes = collected.values.toList();
    episodes.sort((a, b) {
      final an = a['number'] as int? ?? 0;
      final bn = b['number'] as int? ?? 0;
      return an.compareTo(bn);
    });
    return episodes
        .map((e) => {
              'title': e['title'],
              'url': e['url'],
              'number': e['number'],
            })
        .toList();
  }

  void _parseEpisodesFromHtml(
      String html, Map<String, Map<String, dynamic>> collected) {
    final pattern = RegExp(
      r'<a[^>]+href="(https://ristoanime\.me/[^"]+)"[^>]*>([\s\S]*?)</a>',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(html)) {
      final url = match.group(1)!;
      if (url.contains('/series/') ||
          url.contains('/page/') ||
          url.contains('/feed') ||
          url.contains('/movies')) {
        continue;
      }
      final text = HtmlParse.stripTags(match.group(2) ?? '');
      final decodedUrl = Uri.decodeComponent(url);
      if (!decodedUrl.contains('حلقة') &&
          !decodedUrl.toLowerCase().contains('episode') &&
          !text.contains('حلقة') &&
          !text.toLowerCase().contains('episode')) {
        continue;
      }
      if (collected.containsKey(url)) continue;
      final number = SourceUtils.episodeNumber('$text $decodedUrl');
      collected[url] = {
        'title': text.isNotEmpty
            ? SourceUtils.episodeTitle(text, number)
            : SourceUtils.episodeTitle(decodedUrl, number),
        'url': url,
        'number': number ?? collected.length + 1,
      };
    }
  }
}
