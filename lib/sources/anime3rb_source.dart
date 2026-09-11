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
    final html = await HtmlClient.getHtml(
        '$_base/titles/list?q=${Uri.encodeQueryComponent(query)}&page=1');
    final items = _parseCards(html);
    if (items.isNotEmpty) return items;
    return _parseGeneric(html, query);
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final urls = page <= 1
        ? ['$_base/titles/list', '$_base/titles/list/tv', '$_base/']
        : ['$_base/titles/list?page=$page', '$_base/titles/list/tv?page=$page'];
    for (final url in urls) {
      try {
        final html = await HtmlClient.getHtml(url);
        final items = _parseCards(html);
        if (items.isNotEmpty) return items;
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
          HtmlParse.firstMatch(html, [
            RegExp(r'<h1[^>]*>([\s\S]*?)</h1>', caseSensitive: false)
          ]) ??
          HtmlParse.firstMatch(html, [
            RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false)
          ]) ??
          'بدون عنوان',
    );
    final image = HtmlParse.meta(html, 'og:image') ??
        HtmlParse.firstMatch(html, [
              RegExp(r'<img[^>]+(?:data-src|src)="([^"]+)"',
                  caseSensitive: false)
            ]) ??
            '';
    final description = HtmlParse.stripTags(
      HtmlParse.meta(html, 'og:description') ??
          HtmlParse.firstMatch(html, [
            RegExp(
                r'(?:story|description|synopsis)[^>]*>([\s\S]*?)</(?:div|p|span)>',
                caseSensitive: false),
          ]) ??
          '',
    );
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
      final host = HtmlParse.hostOf(resolved);
      if (host.contains('anime3rb.com') ||
          host.contains('facebook.com') ||
          host.contains('twitter.com')) {
        return;
      }
      servers.add({'quality': quality, 'url': resolved});
    }

    for (final match in RegExp(
      r'https?://(?:video\.)?vid3rb\.com/(?:video|embed|e)/[A-Za-z0-9_-]+',
      caseSensitive: false,
    ).allMatches(html)) {
      add(match.group(0)!, 'Anime3rb • Vid3rb');
    }
    for (final match in RegExp(
      r'''<iframe[^>]+src=["']([^"']+)["']''',
      caseSensitive: false,
    ).allMatches(html)) {
      add(match.group(1)!, 'مشغل');
    }
    for (final match in RegExp(
      r'''data-(?:src|url|embed|link|video)=["']([^"']+)["']''',
      caseSensitive: false,
    ).allMatches(html)) {
      add(match.group(1)!);
    }
    for (final media in SourceUtils.extractMediaUrls(html, url)) {
      add(media, 'مباشر');
    }
    if (servers.isEmpty) {
      throw Exception('Anime3rb: لم يتم العثور على رابط تشغيل صالح للحلقة');
    }
    final vid3rb = servers
        .where((s) => s['url']!.toLowerCase().contains('vid3rb'))
        .toList();
    final playable = vid3rb.isNotEmpty ? vid3rb : servers;
    return {
      'source_id': id,
      'stream_url': playable.first['url'],
      'direct_stream_urls': playable,
      'headers': {'Referer': url, 'User-Agent': HtmlClient.userAgent},
      'download_links': <String, dynamic>{},
    };
  }

  List<Map<String, dynamic>> _parseCards(String html) {
    // Current Anime3rb markup uses a title-card wrapper. The previous
    // expression assumed a much shorter image/title layout and could miss
    // every card after the site redesign.
    final current = <Map<String, dynamic>>[];
    final currentSeen = <String>{};
    final currentPattern = RegExp(
      r'''<div[^>]+class=["'][^"']*title-card[^"']*["'][\s\S]*?<a[^>]+href=["']([^"']*/titles/[^"']+)["'][\s\S]*?<img[^>]+(?:src|data-src)=["']([^"']+)["'][^>]*>[\s\S]*?<h2[^>]+class=["'][^"']*title-name[^"']*["'][^>]*>([\s\S]*?)</h2>''',
      caseSensitive: false,
    );
    for (final match in currentPattern.allMatches(html)) {
      final url = HtmlParse.absUrl(_base, match.group(1)!);
      if (!url.contains('/titles/') || !currentSeen.add(url)) continue;
      final title = HtmlParse.stripTags(match.group(3) ?? '');
      if (title.isEmpty) continue;
      current.add(item(
        title: title,
        url: url,
        image: HtmlParse.absUrl(_base, match.group(2)!),
        type: 'anime',
      ));
    }
    if (current.isNotEmpty) return current;

    final modern = <Map<String, dynamic>>[];
    final modernSeen = <String>{};
    final modernPattern = RegExp(
      r'''<a[^>]+href=[\"'](https?://anime3rb\.com/titles/[^\"']+)[\"'][\s\S]{0,500}?<img[^>]+(?:src|data-src)=[\"']([^\"']+)[\"'][\s\S]{0,350}?(?:alt=[\"']([^\"']+)[\"']|<h2[^>]*>([\s\S]*?)</h2>)''',
      caseSensitive: false,
    );
    for (final match in modernPattern.allMatches(html)) {
      final url = match.group(1)!;
      if (!modernSeen.add(url)) continue;
      final rawTitle = match.group(3) ?? match.group(4) ?? url.split('/').last;
      modern.add(item(title: HtmlParse.stripTags(rawTitle), url: url,
          image: HtmlParse.absUrl(_base, match.group(2)!), type: 'anime'));
    }
    if (modern.isNotEmpty) return modern;
    final items = <Map<String, dynamic>>[];
    final seen = <String>{};
    final pattern = RegExp(
      r'<a[^>]+href="(https?://[^"]+|/?[^"]+)"[^>]*>[\s\S]{0,1200}?(?:src|data-src)="([^"]+)"[\s\S]{0,400}?(?:alt|title)="([^"]+)"',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(html)) {
      final url = HtmlParse.absUrl(_base, match.group(1)!);
      if (!url.contains('anime3rb.com')) continue;
      if (url.contains('/tag') || url.contains('/genre') || url.contains('/page')) {
        continue;
      }
      if (!seen.add(url)) continue;
      items.add(item(
        title: HtmlParse.stripTags(match.group(3)!),
        url: url,
        image: HtmlParse.absUrl(_base, match.group(2)!),
        type: 'anime',
      ));
    }
    if (items.isNotEmpty) return items;
    for (final link in HtmlParse.markdownLinks(html)) {
      final url = link['url'] ?? '';
      if (!url.contains('anime3rb.com') || !seen.add(url)) continue;
      if (url.contains('/tag') || url.contains('/genre')) continue;
      items.add(item(title: link['title'] ?? url, url: url, type: 'anime'));
    }
    return items;
  }

  List<Map<String, dynamic>> _parseGeneric(String html, String query) {
    final items = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final match in RegExp(
      r'''href=["'](https?://anime3rb\.com/titles/[^"']+)["'][^>]*>([\s\S]*?)</a>''',
      caseSensitive: false,
    ).allMatches(html)) {
      final url = match.group(1)!;
      final title = HtmlParse.stripTags(match.group(2) ?? '');
      if (title.isEmpty || !seen.add(url)) continue;
      if (url.endsWith('/titles/list')) continue;
      if (query.isNotEmpty &&
          !title.toLowerCase().contains(query.toLowerCase()) &&
          !url.toLowerCase().contains(query.toLowerCase())) {
        continue;
      }
      items.add(item(title: title, url: url, type: 'anime'));
    }
    return items;
  }

  List<Map<String, dynamic>> _parseEpisodes(String html, String pageUrl) {
    final episodes = <Map<String, dynamic>>[];
    final seen = <String>{};

    void addEpisode(String rawUrl, String text) {
      final url = HtmlParse.absUrl(pageUrl, rawUrl).split('#').first;
      final path = Uri.tryParse(url)?.path ?? '';
      if (!url.contains('anime3rb.com') || !seen.add(url) || url == pageUrl) {
        return;
      }
      final isEpisodePath = RegExp(
        r'^/episode/[^/]+/[^/]+/?$',
        caseSensitive: false,
      ).hasMatch(path);
      final decoded = Uri.decodeComponent(url);
      final looksLikeEpisode = decoded.contains('حلقة') ||
          decoded.toLowerCase().contains('episode') ||
          text.contains('حلقة') ||
          text.toLowerCase().contains('episode') ||
          RegExp(r'\d+').hasMatch(text);
      if (!isEpisodePath && !(path.contains('/episode/') && looksLikeEpisode)) {
        return;
      }
      if (!looksLikeEpisode && !isEpisodePath) return;
      final number = SourceUtils.episodeNumber('$text $decoded');
      episodes.add({
        'title': SourceUtils.episodeTitle(text.isEmpty ? decoded : text, number),
        'url': url,
        'number': number ?? episodes.length + 1,
      });
    }

    for (final match in RegExp(
      r'''<a[^>]+href=["']([^"']+)["'][^>]*>([\s\S]*?)</a>''',
      caseSensitive: false,
    ).allMatches(html)) {
      addEpisode(match.group(1)!, HtmlParse.stripTags(match.group(2) ?? ''));
    }
    for (final link in HtmlParse.markdownLinks(html)) {
      addEpisode(link['url'] ?? '', link['title'] ?? '');
    }
    episodes.sort((a, b) => (a['number'] as int).compareTo(b['number'] as int));
    return episodes;
  }
}
