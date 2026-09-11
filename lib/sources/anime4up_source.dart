import 'html_client.dart';
import 'source_base.dart';

class Anime4UpSource extends ContentSource {
  // The .bond host is now only a landing page. The catalogue and episode
  // pages are served from the current WordPress host, while the list page is
  // also available through the rotating 4b gateway.
  static const String _base = 'https://w1.anime4up.rest';
  static const String _catalogBase = 'https://4b.1i2cqoi.shop';

  @override String get id => 'anime4up';
  @override String get name => 'Anime4Up';
  @override String get kind => 'anime';
  @override List<String> get hosts => ['anime4up.bond', 'anime4up.rest', '4b.1i2cqoi.shop', 'w1.anime4up.rest'];

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final urls = [
      '$_base/?search_param=animes&s=${Uri.encodeQueryComponent(query)}',
      '$_catalogBase/?search_param=animes&s=${Uri.encodeQueryComponent(query)}',
      '$_base/?s=${Uri.encodeQueryComponent(query)}',
    ];
    for (final url in urls) {
      try {
        final items = _parseCards(await HtmlClient.getHtml(url));
        if (items.isNotEmpty) return items;
      } catch (_) {}
    }
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final urls = page <= 1
        ? ['$_catalogBase/قائمة-الانمي/', '$_base/قائمة-الانمي/', '$_base/home8/']
        : ['$_catalogBase/قائمة-الانمي/page/$page/', '$_base/قائمة-الانمي/page/$page/', '$_base/page/$page/'];
    for (final url in urls) {
      try {
        final items = _parseCards(await HtmlClient.getHtml(url));
        if (items.isNotEmpty) return items;
      } catch (_) {}
    }
    return [];
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final html = await HtmlClient.getHtml(url);
    final title = HtmlParse.stripTags(HtmlParse.meta(html, 'og:title') ?? HtmlParse.firstMatch(html, [
      RegExp(r'<h1[^>]*>([\s\S]*?)</h1>', caseSensitive: false),
      RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false),
    ]) ?? url.split('/').where((p) => p.isNotEmpty).last);
    final image = _image(html, url);
    final description = HtmlParse.stripTags(HtmlParse.meta(html, 'og:description') ?? HtmlParse.firstMatch(html, [
      RegExp(r'(?:story|description|synopsis)[^>]*>([\s\S]*?)</(?:div|p|span)>', caseSensitive: false),
    ]) ?? '');
    final episodes = _parseEpisodes(html, url);
    return {
      ...item(title: title, url: url, image: image, type: 'anime', description: description),
      'synopsis': description,
      'total_episodes': episodes.length,
      'episodes': episodes,
    };
  }

  @override
  Future<Map<String, dynamic>> streams(String url) async {
    final html = await HtmlClient.getHtml(url);
    final candidates = <String>[];
    void collect(RegExp pattern) {
      for (final match in pattern.allMatches(html)) {
        final value = match.group(1);
        if (value != null && value.isNotEmpty) candidates.add(HtmlParse.absUrl(url, value));
      }
    }
    collect(RegExp(r'''<iframe[^>]+src=["']([^"']+)["']''', caseSensitive: false));
    collect(RegExp(r'''data-(?:src|url|embed|link|video|watch)=["']([^"']+)["']''', caseSensitive: false));
    candidates.addAll(SourceUtils.extractMediaUrls(html, url));
    final seen = <String>{};
    final servers = candidates.where((value) => value.isNotEmpty && seen.add(value) && !_isNoise(value)).toList();
    for (final candidate in List<String>.from(servers)) {
      if (_isDirect(candidate)) continue;
      try {
        final embedded = await HtmlClient.getHtml(candidate);
        servers.addAll([
          ...SourceUtils.extractMediaUrls(embedded, candidate),
          ...RegExp(r'''(?:file|src|source|url)\s*[:=]\s*["']([^"']+\.(?:mp4|m3u8)(?:\?[^"']*)?)["']''', caseSensitive: false)
              .allMatches(embedded).map((m) => HtmlParse.absUrl(candidate, m.group(1)!)),
        ].where(_isDirect).where(seen.add));
      } catch (_) {}
    }
    if (servers.isEmpty) throw Exception('لم يتم العثور على خادم تشغيل لهذه الحلقة');
    String playUrl = servers.first;
    for (final candidate in servers) {
      if (_isDirect(candidate)) { playUrl = candidate; break; }
    }
    return {
      'source_id': id,
      'stream_url': playUrl,
      'direct_stream_urls': servers.where(_isDirect).map((url) => {'quality': 'مباشر', 'url': url}).toList(),
      'headers': {'Referer': url, 'User-Agent': HtmlClient.userAgent},
      'download_links': {
        if (servers.any(_isDirect)) 'مباشر': servers.where(_isDirect).map((url) => {'host': 'Anime4Up', 'url': url}).toList(),
      },
    };
  }

  List<Map<String, dynamic>> _parseCards(String html) {
    final items = <Map<String, dynamic>>[];
    final seen = <String>{};
    // Current Anime4up cards use .anime-card-themex and keep the poster in
    // data-image. Restrict parsing to /anime/ links so gateway/navigation
    // links cannot be displayed as anime titles.
    final pattern = RegExp(r'''<div[^>]+class=["'][^"']*anime-card-themex[^"']*["'][\s\S]{0,2600}?data-image=["']([^"']+)["'][\s\S]{0,700}?<a[^>]+href=["']([^"']*/anime/[^"']+)["'][^>]*(?:aria-label=["']([^"']+)["']|>[\s\S]*?<h3[^>]*>[\s\S]*?<a[^>]*>([\s\S]*?)</a>)''', caseSensitive: false);
    for (final match in pattern.allMatches(html)) {
      final url = HtmlParse.absUrl(_base, match.group(2)!);
      if (!hosts.any((host) => url.contains(host)) || !url.contains('/anime/') || !seen.add(url)) continue;
      final image = HtmlParse.absUrl(url, match.group(1)!);
      final title = HtmlParse.stripTags(match.group(3) ?? match.group(4) ?? '');
      if (title.isEmpty || image.toLowerCase().contains('logo')) continue;
      items.add(item(title: title, url: url, image: HtmlParse.absUrl(url, image), type: 'anime'));
    }
    for (final link in HtmlParse.markdownLinks(html)) {
      final url = link['url'] ?? '';
      if (!hosts.any((host) => url.contains(host)) || !url.contains('/anime/') || !seen.add(url)) continue;
      items.add(item(title: link['title'] ?? url, url: url, type: 'anime'));
    }
    return items;
  }

  List<Map<String, dynamic>> _parseEpisodes(String html, String pageUrl) {
    final episodes = <Map<String, dynamic>>[];
    final seen = <String>{};
    void add(String raw, String label) {
      final url = HtmlParse.absUrl(pageUrl, raw).split('#').first;
      final text = HtmlParse.stripTags(label);
      final decoded = Uri.decodeComponent(url);
      if (url.isEmpty || !hosts.any((host) => url.contains(host)) || url == pageUrl || !seen.add(url)) return;
      if (!decoded.toLowerCase().contains('episode') && !decoded.contains('حلقة') && !text.toLowerCase().contains('episode') && !text.contains('حلقة') && !RegExp(r'\d+').hasMatch(text)) return;
      final number = SourceUtils.episodeNumber('$text $decoded');
      episodes.add({'title': SourceUtils.episodeTitle(text.isEmpty ? decoded : text, number), 'url': url, 'number': number ?? episodes.length + 1});
    }
    for (final match in RegExp(r'''<a[^>]+href=["']([^"']+)["'][^>]*>([\s\S]*?)</a>''', caseSensitive: false).allMatches(html)) add(match.group(1)!, match.group(2) ?? '');
    for (final link in HtmlParse.markdownLinks(html)) add(link['url'] ?? '', link['title'] ?? '');
    episodes.sort((a, b) => (a['number'] as int).compareTo(b['number'] as int));
    return episodes;
  }

  String _image(String html, String url) => HtmlParse.absUrl(url, HtmlParse.meta(html, 'og:image') ?? HtmlParse.firstMatch(html, [RegExp(r'''<img[^>]+(?:src|data-src)=["']([^"']+)["']''', caseSensitive: false)]) ?? '');
  bool _isDirect(String value) => RegExp(r'\.(?:mp4|m3u8|mov|webm)(?:[?#].*)?$', caseSensitive: false).hasMatch(value) || value.contains('pixeldrain.com/api/file');
  bool _isNoise(String value) => value.contains('facebook.com') || value.contains('twitter.com') || value.contains('anime4up.bond');
  bool _isUtility(String value) => RegExp(r'/(page|forum|category|genre|tag|search|privacy|terms|contact)/', caseSensitive: false).hasMatch(value);
}
