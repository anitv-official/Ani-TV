import 'html_client.dart';
import 'source_base.dart';

/// Anime Slayer HTML source.
///
/// The public site currently has no documented API. The historical web
/// catalogue exposes search pages, title pages, and episode pages; this
/// source deliberately parses those pages and returns an empty result when
/// the upstream is parked, redirected, or unavailable.
class AnimeSlayerSource extends ContentSource {
  static const String _base = 'https://video.anime-slayer.com';

  @override
  String get id => 'anime_slayer';

  @override
  String get name => 'Anime Slayer';

  @override
  String get kind => 'anime';

  @override
  List<String> get hosts => [
        'video.anime-slayer.com',
        'anime-slayer.com',
        'anslayer.com',
      ];

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final html = await HtmlClient.getHtml(
        '$_base/?search_param=animes&s=${Uri.encodeQueryComponent(query.trim())}',
      );
      return _parseCards(html);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    try {
      final suffix = page <= 1 ? '' : '&page=$page';
      final html = await HtmlClient.getHtml('$_base/?search_param=animes$suffix');
      return _parseCards(html);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final html = await HtmlClient.getHtml(url);
    final title = HtmlParse.stripTags(
      HtmlParse.meta(html, 'og:title') ??
          HtmlParse.firstMatch(html, [
            RegExp(r'<h1[^>]*>([\s\S]*?)</h1>', caseSensitive: false),
            RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false),
          ]) ??
          'بدون عنوان',
    );
    final image = HtmlParse.meta(html, 'og:image') ??
        HtmlParse.firstMatch(html, [
          RegExp(r'''<img[^>]+(?:src|data-src)=["']([^"']+)''',
              caseSensitive: false),
        ]) ??
        '';
    final description = HtmlParse.stripTags(
      HtmlParse.meta(html, 'og:description') ??
          HtmlParse.firstMatch(html, [
            RegExp(r'(?:description|synopsis|story)[^>]*>([\s\S]*?)</(?:div|p|span)>',
                caseSensitive: false),
          ]) ??
          '',
    );
    final genres = HtmlParse.all(
      html,
      RegExp(r'''href=["'][^"']*(?:genre|category)[^"']*["'][^>]*>([^<]+)<''',
          caseSensitive: false),
    );
    final episodes = _parseEpisodes(html, url);
    return {
      ...item(
        title: title,
        url: url,
        image: HtmlParse.absUrl(url, image),
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

    // Anime Slayer's episode page exposes servers through data-ep-url.
    for (final match in RegExp(
      r'''<[^>]+(?:id=["']episode-servers["'][^>]*[\s\S]*?)?<a[^>]+data-ep-url=["']([^"']+)["']''',
      caseSensitive: false,
    ).allMatches(html)) {
      add(match.group(1)!);
    }
    for (final match in RegExp(
      r'''data-ep-url=["']([^"']+)["']''',
      caseSensitive: false,
    ).allMatches(html)) {
      add(match.group(1)!);
    }
    for (final match in RegExp(
      r'''<iframe[^>]+src=["']([^"']+)["']''',
      caseSensitive: false,
    ).allMatches(html)) {
      add(match.group(1)!, 'مشغل');
    }
    for (final media in SourceUtils.extractMediaUrls(html, url)) {
      add(media, 'مباشر');
    }
    if (servers.isEmpty) {
      throw Exception('لم يتم العثور على خوادم تشغيل لهذه الحلقة');
    }
    final direct = servers
        .where((server) => RegExp(r'\.(?:mp4|m3u8)(?:\?|$)', caseSensitive: false)
            .hasMatch(server['url']!))
        .toList();
    return {
      'stream_url': (direct.isNotEmpty ? direct : servers).first['url'],
      'direct_stream_urls': direct.isNotEmpty ? direct : servers,
      'download_links': <String, dynamic>{},
    };
  }

  List<Map<String, dynamic>> _parseCards(String html) {
    final items = <Map<String, dynamic>>[];
    final seen = <String>{};
    final pattern = RegExp(
      r'''<div[^>]+class=["'][^"']*anime-list-content[^"']*["'][\s\S]*?<h3[^>]*>\s*<a[^>]+href=["']([^"']+)["'][^>]*>([\s\S]*?)</a>\s*</h3>''',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(html)) {
      final url = HtmlParse.absUrl(_base, match.group(1)!);
      final title = HtmlParse.stripTags(match.group(2) ?? '');
      if (title.isEmpty || !seen.add(url)) continue;
      items.add(item(title: title, url: url, type: 'anime'));
    }
    return items;
  }

  List<Map<String, dynamic>> _parseEpisodes(String html, String pageUrl) {
    final episodes = <Map<String, dynamic>>[];
    final seen = <String>{};
    final pattern = RegExp(
      r'''<h3[^>]*>\s*<a[^>]+href=["']([^"']+)["'][^>]*>([\s\S]*?)</a>\s*</h3>''',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(html)) {
      final url = HtmlParse.absUrl(pageUrl, match.group(1)!);
      if (!seen.add(url) || url == pageUrl) continue;
      final text = HtmlParse.stripTags(match.group(2) ?? '');
      final number = SourceUtils.episodeNumber('$text $url');
      if (number == null && !RegExp(r'\d+').hasMatch(text)) continue;
      episodes.add({
        'title': 'الحلقة ${number ?? episodes.length + 1}',
        'url': url,
        'number': number ?? episodes.length + 1,
      });
    }
    episodes.sort((a, b) => (a['number'] as int).compareTo(b['number'] as int));
    return episodes;
  }
}
