import 'html_client.dart';
import 'source_base.dart';

class Anime4UpSource extends ContentSource {
  static const String _base = 'https://w1.anime4up.rest';
  static const String _catalogBase = 'https://4b.1i2cqoi.shop';

  @override
  String get id => 'anime4up';
  @override
  String get name => 'Anime4Up';
  @override
  String get kind => 'anime';
  @override
  List<String> get hosts => ['anime4up.bond', 'anime4up.rest', '4b.1i2cqoi.shop', 'w1.anime4up.rest'];

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return const [];
    final encoded = Uri.encodeQueryComponent(value);
    final urls = [
      '$_base/?search_param=animes&s=$encoded',
      '$_catalogBase/?search_param=animes&s=$encoded',
      '$_base/?s=$encoded',
    ];
    for (final url in urls) {
      try {
        final items = _parseCards(await HtmlClient.getHtml(url));
        if (items.isNotEmpty) return items;
      } catch (_) {}
    }
    return const [];
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
    return const [];
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
    void add(String raw, String base) {
      final value = HtmlParse.absUrl(base, raw);
      if (value.isNotEmpty && !_isNoise(value) && !candidates.contains(value)) candidates.add(value);
    }

    for (final pattern in [
      RegExp(r'''<iframe[^>]+src=["']([^"']+)["']''', caseSensitive: false),
      RegExp(r'''data-(?:src|url|embed|link|video|watch)=["']([^"']+)["']''', caseSensitive: false),
      RegExp(r'''(?:file|src|source|url)\s*[:=]\s*["']([^"']+)["']''', caseSensitive: false),
    ]) {
      for (final match in pattern.allMatches(html)) add(match.group(1)!, url);
    }
    for (final media in SourceUtils.extractMediaUrls(html, url)) add(media, url);

    final direct = <String>{};
    for (final candidate in List<String>.from(candidates)) {
      if (_isDirect(candidate)) {
        direct.add(candidate);
        continue;
      }
      try {
        final embedded = await HtmlClient.getHtml(candidate);
        for (final media in SourceUtils.extractMediaUrls(embedded, candidate)) {
          if (_isDirect(media)) direct.add(media);
        }
        for (final pattern in [
          RegExp(r'''(?:file|src|source|url)\s*[:=]\s*["']([^"']+)["']''', caseSensitive: false),
          RegExp(r'''https?:\\?/\\?/[^"'\\s]+\.(?:mp4|m3u8|mov|webm)(?:\?[^"'\\s]*)?''', caseSensitive: false),
        ]) {
          for (final match in pattern.allMatches(embedded)) {
            final raw = match.groupCount > 0 && match.group(1) != null ? match.group(1)! : match.group(0)!;
            final media = HtmlParse.absUrl(candidate, raw.replaceAll('\\/', '/'));
            if (_isDirect(media)) direct.add(media);
          }
        }
      } catch (_) {}
    }

    final all = [...direct, ...candidates.where((value) => !_isDirect(value))];
    if (all.isEmpty) throw Exception('لم يتم العثور على خادم تشغيل لهذه الحلقة');
    final directLinks = direct.map((value) => {
      'quality': _quality(value),
      'url': value,
    }).toList();
    return {
      'source_id': id,
      'stream_url': direct.isNotEmpty ? direct.first : candidates.first,
      'direct_stream_urls': directLinks,
      'servers': all,
      'headers': {'Referer': url, 'User-Agent': HtmlClient.userAgent},
      'download_links': {
        if (directLinks.isNotEmpty) 'مباشر': directLinks.map((link) => {'host': 'Anime4Up', 'url': link['url']}).toList(),
      },
    };
  }

  List<Map<String, dynamic>> _parseCards(String html) {
    final items = <Map<String, dynamic>>[];
    final seen = <String>{};
    final links = RegExp(r'''<a\b[^>]+href=["']([^"']*/anime/[^"']+)["'][^>]*>([\s\S]*?)</a>''', caseSensitive: false);
    for (final match in links.allMatches(html)) {
      final rawUrl = match.group(1)!;
      final url = HtmlParse.absUrl(_base, rawUrl).split('#').first;
      if (!hosts.any((host) => Uri.tryParse(url)?.host.endsWith(host) == true) || !seen.add(url)) continue;
      final start = (match.start - 1400).clamp(0, html.length).toInt();
      final end = (match.end + 900).clamp(0, html.length).toInt();
      final context = html.substring(start, end);
      final image = _imageFromFragment(context, url);
      final title = _titleFromFragment(context, match.group(2) ?? '');
      if (title.isEmpty || _isUtility(url)) continue;
      items.add(item(title: title, url: url, image: image, type: 'anime'));
    }
    return items;
  }

  List<Map<String, dynamic>> _parseEpisodes(String html, String pageUrl) {
    final episodes = <Map<String, dynamic>>[];
    final seen = <String>{};
    void add(String raw, String label) {
      final url = HtmlParse.absUrl(pageUrl, raw).split('#').first;
      if (url.isEmpty || url == pageUrl || !seen.add(url)) return;
      final uri = Uri.tryParse(url);
      if (uri == null || !hosts.any((host) => uri.host.endsWith(host))) return;
      final text = HtmlParse.stripTags(label);
      final decoded = Uri.decodeComponent(url);
      final path = uri.path.toLowerCase();
      final looksLikeEpisode = path.contains('/episode') || path.contains('/watch') || path.contains('/play') ||
          decoded.contains('حلقة') || decoded.toLowerCase().contains('episode') ||
          text.contains('حلقة') || text.toLowerCase().contains('episode') || RegExp(r'\d+').hasMatch(text);
      if (!looksLikeEpisode || _isUtility(url)) return;
      final number = SourceUtils.episodeNumber('$text $decoded');
      episodes.add({
        'title': SourceUtils.episodeTitle(text.isEmpty ? decoded : text, number),
        'url': url,
        'number': number ?? episodes.length + 1,
      });
    }

    for (final match in RegExp(r'''<(?:a|button)[^>]+(?:href|data-url|data-href|data-link)=["']([^"']+)["'][^>]*>([\s\S]*?)</(?:a|button)>''', caseSensitive: false).allMatches(html)) {
      add(match.group(1)!, match.group(2) ?? '');
    }
    for (final link in HtmlParse.markdownLinks(html)) add(link['url'] ?? '', link['title'] ?? '');
    episodes.sort((a, b) => (a['number'] as int).compareTo(b['number'] as int));
    return episodes;
  }

  String _image(String html, String url) => HtmlParse.absUrl(url, HtmlParse.meta(html, 'og:image') ?? HtmlParse.meta(html, 'twitter:image') ?? _imageFromFragment(html, url));

  String _imageFromFragment(String fragment, String base) {
    final match = RegExp(r'''(?:data-image|data-src|data-lazy-src|data-original|src|content)=["']([^"']+)["']''', caseSensitive: false).firstMatch(fragment);
    final raw = match?.group(1) ?? RegExp(r'''background-image\s*:\s*url\(["']?([^"')]+)''', caseSensitive: false).firstMatch(fragment)?.group(1) ?? '';
    final image = HtmlParse.absUrl(base, raw);
    return image.toLowerCase().contains('logo') ? '' : image;
  }

  String _titleFromFragment(String fragment, String anchorText) {
    final aria = RegExp(r'''(?:aria-label|title)=["']([^"']+)["']''', caseSensitive: false).firstMatch(fragment)?.group(1);
    final heading = RegExp(r'''<h[1-6][^>]*>([\s\S]*?)</h[1-6]>''', caseSensitive: false).firstMatch(fragment)?.group(1);
    final alt = RegExp(r'''alt=["']([^"']+)["']''', caseSensitive: false).firstMatch(fragment)?.group(1);
    return HtmlParse.stripTags(aria ?? heading ?? alt ?? anchorText);
  }

  String _quality(String url) {
    final match = RegExp(r'(\d{3,4})p', caseSensitive: false).firstMatch(url);
    return match == null ? 'مباشر' : '${match.group(1)}p';
  }

  bool _isDirect(String value) => RegExp(r'\.(?:mp4|m3u8|mov|webm|mkv)(?:[?#].*)?$', caseSensitive: false).hasMatch(value) || value.contains('pixeldrain.com/api/file');
  bool _isNoise(String value) => value.contains('facebook.com') || value.contains('twitter.com') || value.contains('doubleclick.net');
  bool _isUtility(String value) => RegExp(r'/(page|forum|category|genre|tag|search|privacy|terms|contact)/', caseSensitive: false).hasMatch(value);
}
