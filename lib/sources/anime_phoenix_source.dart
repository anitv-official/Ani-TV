import 'html_client.dart';
import 'source_base.dart';

class AnimePhoenixSource extends ContentSource {
  static const String _base = 'https://anime-phoenix.com';

  @override
  String get id => 'phoenix';

  @override
  String get name => 'Anime Phoenix';

  @override
  String get kind => 'anime';

  @override
  List<String> get hosts => ['anime-phoenix.com'];

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    try {
      final html = await HtmlClient.getHtml('$_base/?s=${Uri.encodeQueryComponent(query)}');
      final cards = _parseCards(html);
      if (cards.isNotEmpty) return cards;
    } catch (_) {}
    return _searchViaWp(query);
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    try {
      final url = page <= 1 ? '$_base/' : '$_base/page/$page/';
      final html = await HtmlClient.getHtml(url);
      final cards = _parseCards(html);
      if (cards.isNotEmpty) return cards;
    } catch (_) {}
    return _searchViaWp('');
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final html = await HtmlClient.getHtml(url);
    final title = HtmlParse.stripTags(
      HtmlParse.meta(html, 'og:title') ??
          HtmlParse.firstMatch(html, [
            RegExp(r'<h1[^>]*>([\s\S]*?)</h1>', caseSensitive: false)
          ]) ??
          'بدون عنوان',
    );
    final image = HtmlParse.meta(html, 'og:image') ?? '';
    final description =
        HtmlParse.stripTags(HtmlParse.meta(html, 'og:description') ?? '');
    final genres = HtmlParse.all(
      html,
      RegExp(r'href="[^"]*(?:genre|category)[^"]*"[^>]*>([^<]+)<',
          caseSensitive: false),
    );
    final episodes = _parseEpisodes(html, url);
    return {
      ...item(
        title: title,
        url: url,
        image: image,
        type: 'anime',
        genres: genres.toSet().toList(),
        description: description,
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
      if (resolved.isEmpty || !seen.add(resolved)) return;
      servers.add({'quality': quality, 'url': resolved});
    }

    for (final match in RegExp(
      r'<iframe[^>]+src=["' "'" r']([^"' "'" r']+)["' "'" r']',
      caseSensitive: false,
    ).allMatches(html)) {
      add(match.group(1)!, 'مشغل');
    }
    for (final match in RegExp(
      r'data-(?:src|url|embed)=["' "'" r']([^"' "'" r']+)["' "'" r']',
      caseSensitive: false,
    ).allMatches(html)) {
      add(match.group(1)!);
    }
    for (final media in SourceUtils.extractMediaUrls(html, url)) {
      add(media, 'مباشر');
    }
    if (servers.isEmpty) add(url, 'صفحة الحلقة');
    return {
      'stream_url': servers.first['url'],
      'direct_stream_urls': servers,
      'download_links': <String, dynamic>{},
    };
  }

  Future<List<Map<String, dynamic>>> _searchViaWp(String query) async {
    final data = await HtmlClient.getJson(
      '$_base/wp-json/wp/v2/posts?search=${Uri.encodeQueryComponent(query)}&_embed=1&per_page=20',
    ) as List<dynamic>;
    final items = <Map<String, dynamic>>[];
    for (final raw in data.whereType<Map>()) {
      final title = HtmlParse.stripTags((raw['title']?['rendered'] ?? '').toString());
      final link = (raw['link'] ?? '').toString();
      if (title.isEmpty || link.isEmpty) continue;
      var image = '';
      final embedded = raw['_embedded'];
      if (embedded is Map && embedded['wp:featuredmedia'] is List &&
          (embedded['wp:featuredmedia'] as List).isNotEmpty) {
        image = ((embedded['wp:featuredmedia'] as List).first['source_url'] ?? '').toString();
      }
      items.add(item(title: title, url: link, image: image, type: 'anime'));
    }
    return items;
  }

  List<Map<String, dynamic>> _parseCards(String html) {
    final items = <Map<String, dynamic>>[];
    final seen = <String>{};
    final movieItems = RegExp(
      r'<a[^>]+href="([^"]+)"[^>]*>[\s\S]{0,1500}?(?:url\(([^)]+)\)|(?:src|data-src)="([^"]+)")[\s\S]{0,400}?<h[1-6][^>]*>([\s\S]*?)</h[1-6]>',
      caseSensitive: false,
    );
    for (final match in movieItems.allMatches(html)) {
      final url = HtmlParse.absUrl(_base, match.group(1)!);
      if (!url.contains('anime-phoenix.com') || !seen.add(url)) continue;
      final image = (match.group(2) ?? match.group(3) ?? '')
          .replaceAll("'", '')
          .replaceAll('"', '');
      items.add(item(
        title: HtmlParse.stripTags(match.group(4) ?? ''),
        url: url,
        image: HtmlParse.absUrl(_base, image),
        type: 'anime',
      ));
    }
    if (items.isNotEmpty) return items;
    for (final link in HtmlParse.markdownLinks(html)) {
      final url = link['url'] ?? '';
      if (!url.contains('anime-phoenix.com') ||
          url.contains('/tag') ||
          !seen.add(url)) {
        continue;
      }
      items.add(item(title: link['title'] ?? url, url: url, type: 'anime'));
    }
    return items;
  }

  List<Map<String, dynamic>> _parseEpisodes(String html, String pageUrl) {
    final episodes = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final match in RegExp(
      r'<a[^>]+href="([^"]+)"[^>]*>([\s\S]*?)</a>',
      caseSensitive: false,
    ).allMatches(html)) {
      final url = HtmlParse.absUrl(pageUrl, match.group(1)!);
      if (!url.contains('anime-phoenix.com') ||
          url == pageUrl ||
          !seen.add(url)) {
        continue;
      }
      final text = HtmlParse.stripTags(match.group(2) ?? '');
      final decoded = Uri.decodeComponent(url);
      if (!decoded.contains('حلقة') &&
          !decoded.toLowerCase().contains('episode') &&
          !text.contains('حلقة') &&
          !RegExp(r'(ep|episode)\s*\d+', caseSensitive: false).hasMatch(text)) {
        continue;
      }
      final number = SourceUtils.episodeNumber('$text $decoded');
      episodes.add({
        'title': SourceUtils.episodeTitle(text.isEmpty ? decoded : text, number),
        'url': url,
        'number': number ?? episodes.length + 1,
      });
    }
    episodes.sort((a, b) => (a['number'] as int).compareTo(b['number'] as int));
    return episodes;
  }
}
