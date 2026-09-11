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
  List<String> get hosts => ['anime3rb.com'];

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final html = await HtmlClient.getHtml(
        '$_base/?s=${Uri.encodeQueryComponent(query)}');
    final items = _parseCards(html);
    if (items.isNotEmpty) return items;
    return _parseGeneric(html, query);
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final urls = page <= 1
        ? ['$_base/', '$_base/animes', '$_base/episodes']
        : ['$_base/page/$page/', '$_base/animes/page/$page/'];
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
    for (final match in RegExp(
      r'https?://[^\s"<>]+(?:ok\.ru|dood|mp4upload|vidmoly|uqload|streamtape|filemoon|voe|mixdrop|yourupload|goload|sbfull|sbplay|krakenfiles|pixeldrain)[^\s"<>]*',
      caseSensitive: false,
    ).allMatches(html)) {
      add(match.group(0)!);
    }
    if (servers.isEmpty) add(url, 'صفحة الحلقة');
    return {
      'stream_url': servers.first['url'],
      'direct_stream_urls': servers,
      'download_links': <String, dynamic>{},
    };
  }

  List<Map<String, dynamic>> _parseCards(String html) {
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
      r'href="(https?://anime3rb\.com/[^"]+)"[^>]*>([\s\S]*?)</a>',
      caseSensitive: false,
    ).allMatches(html)) {
      final url = match.group(1)!;
      final title = HtmlParse.stripTags(match.group(2) ?? '');
      if (title.isEmpty || !seen.add(url)) continue;
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
    for (final match in RegExp(
      r'<a[^>]+href="([^"]+)"[^>]*>([\s\S]*?)</a>',
      caseSensitive: false,
    ).allMatches(html)) {
      final url = HtmlParse.absUrl(pageUrl, match.group(1)!);
      if (!url.contains('anime3rb.com') || !seen.add(url)) continue;
      final text = HtmlParse.stripTags(match.group(2) ?? '');
      final decoded = Uri.decodeComponent(url);
      if (!decoded.contains('حلقة') &&
          !decoded.toLowerCase().contains('episode') &&
          !text.contains('حلقة') &&
          !RegExp(r'\d+').hasMatch(text)) {
        continue;
      }
      if (url == pageUrl) continue;
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
