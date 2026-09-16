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
          HtmlParse.firstMatch(html, [RegExp(r'<h1[^>]*>([\s\S]*?)</h1>', caseSensitive: false)]) ??
          HtmlParse.firstMatch(html, [RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false)]) ??
          'بدون عنوان',
    );
    final image = HtmlParse.meta(html, 'og:image') ??
        HtmlParse.firstMatch(html, [RegExp(r'<img[^>]+(?:data-src|src)="([^"]+)"', caseSensitive: false)]) ??
        '';
    final description = HtmlParse.stripTags(
      HtmlParse.meta(html, 'og:description') ??
          HtmlParse.firstMatch(html, [RegExp(r'(?:story|description|synopsis)[^>]*>([\s\S]*?)</(?:div|p|span)>', caseSensitive: false)]) ??
          '',
    );
    final genres = HtmlParse.all(html, RegExp(r'href="[^"]*(?:genre|category)[^"]*"[^>]*>([^<]+)<', caseSensitive: false));
    final episodes = _parseEpisodes(html, url);
    return {
      ...item(title: title, url: url, image: image, type: 'anime', genres: genres.toSet().toList(), description: description),
      'synopsis': description,
      'total_episodes': episodes.length,
      'episodes': episodes,
    };
  }

  @override
  Future<Map<String, dynamic>> streams(String url) async {
    // Playback extraction must use the real episode/player HTML. Do not use
    // r.jina.ai here because it strips the scripts and signed media URLs that
    // the native video player needs.
    final html = await HtmlClient.getHtml(url, useReaderFallback: false);
    final servers = <Map<String, String>>[];
    final directServers = <Map<String, String>>[];
    final seen = <String>{};
    final directSeen = <String>{};

    void add(String raw, [String quality = 'خادم']) {
      final resolved = HtmlParse.absUrl(url, _normalizeEscapedUrl(raw));
      if (resolved.isEmpty || !seen.add(resolved)) return;
      final host = HtmlParse.hostOf(resolved);
      final path = Uri.tryParse(resolved)?.path.toLowerCase() ?? '';
      if ((host.contains('anime3rb.com') && !path.startsWith('/embed/')) ||
          host.contains('facebook.com') || host.contains('twitter.com')) return;
      servers.add({'quality': quality, 'url': resolved});
      if (_isDirectMedia(resolved) && directSeen.add(resolved)) {
        directServers.add({'quality': quality, 'url': resolved});
      }
    }

    for (final match in RegExp(r'https?://(?:video\.)?vid3rb\.com/(?:video|embed|e)/[A-Za-z0-9_-]+', caseSensitive: false).allMatches(html)) {
      add(match.group(0)!, 'Anime3rb • Vid3rb');
    }
    for (final match in RegExp(r'''<iframe[^>]+src=["']([^"']+)["']''', caseSensitive: false).allMatches(html)) {
      add(match.group(1)!, 'مشغل');
    }
    for (final match in RegExp(r'''data-(?:src|url|embed|link|video)=["']([^"']+)["']''', caseSensitive: false).allMatches(html)) {
      add(match.group(1)!);
    }
    for (final match in RegExp(r'''<a[^>]+href=["']([^"']+)["'][^>]*>''', caseSensitive: false).allMatches(html)) {
      final candidate = HtmlParse.absUrl(url, _normalizeEscapedUrl(match.group(1)!));
      if (_looksLikePlayerUrl(candidate)) add(candidate, 'مشغل/جودة');
    }
    for (final media in extractDirectMediaUrls(html, url)) {
      add(media, 'مباشر');
    }

    // The page may expose only a player/embed URL. Probe that page directly
    // and promote any real MP4/M3U8 it contains to a native-player source.
    for (final server in List<Map<String, String>>.from(servers)) {
      final candidate = server['url']!;
      if (_isDirectMedia(candidate)) continue;
      try {
        final embedded = await HtmlClient.getHtml(candidate, useReaderFallback: false);
        for (final media in extractDirectMediaUrls(embedded, candidate)) {
          add(media, 'Anime3rb • مباشر');
        }
      } catch (_) {}
    }

    if (directServers.isEmpty) {
      throw Exception('Anime3rb: لم يتم العثور على رابط MP4 أو M3U8 مباشر للحلقة');
    }

    final directLinks = directServers
        .map((server) => {'quality': server['quality'] ?? 'مباشر', 'url': server['url']!})
        .toList();
    return {
      'source_id': id,
      'stream_url': directServers.first['url'],
      'direct_stream_urls': directLinks,
      'headers': {'Referer': url, 'User-Agent': HtmlClient.userAgent},
      'download_links': _downloadLinks(directServers),
    };
  }

  static List<String> extractDirectMediaUrls(String html, String pageUrl) {
    final normalized = _normalizeEscapedUrl(html);
    final urls = <String>{};

    void add(String raw) {
      final value = HtmlParse.absUrl(pageUrl, _normalizeEscapedUrl(raw));
      if (value.isNotEmpty && _isDirectMediaUrl(value)) urls.add(value);
    }

    for (final match in RegExp(r'''(?:src|data-src|data-url|file|source|url|hls|playlist)\s*[:=]\s*["']([^"']+)["']''', caseSensitive: false).allMatches(normalized)) {
      add(match.group(1)!);
    }
    for (final match in RegExp(r'''https?://[^\s"'<>]+\.(?:mp4|m3u8|mov|webm)(?:\?[^\s"'<>]*)?''', caseSensitive: false).allMatches(normalized)) {
      add(match.group(0)!);
    }
    return urls.toList();
  }

  static String _normalizeEscapedUrl(String value) {
    return value
        .replaceAll(r'\/', '/')
        .replaceAll(r'\"', '"')
        .replaceAll(r'\u0026', '&')
        .replaceAll(r'\u003F', '?')
        .replaceAll(r'\u003f', '?')
        .replaceAll(r'\u003D', '=')
        .replaceAll(r'\u003d', '=');
  }

  Map<String, dynamic> _downloadLinks(List<Map<String, String>> servers) {
    final links = <String, dynamic>{};
    for (final server in servers) {
      (links['مباشر'] ??= <Map<String, dynamic>>[]).add({'host': server['quality'] ?? 'Anime3rb', 'url': server['url']});
    }
    return links;
  }

  bool _isDirectMedia(String value) => _isDirectMediaUrl(value);

  static bool _isDirectMediaUrl(String value) {
    final lower = value.toLowerCase();
    return RegExp(r'\.(?:mp4|m3u8|mov|webm)(?:[?#].*)?$').hasMatch(lower) || lower.contains('pixeldrain.com/api/file');
  }

  bool _looksLikePlayerUrl(String value) {
    final lower = value.toLowerCase();
    if (_isDirectMedia(lower)) return true;
    return lower.contains('vid3rb') || lower.contains('3rbcdn') || lower.contains('vidmoly') ||
        lower.contains('streamtape') || lower.contains('filemoon') || lower.contains('uqload') || lower.contains('/embed/');
  }

  List<Map<String, dynamic>> _parseCards(String html) {
    final current = <Map<String, dynamic>>[];
    final currentSeen = <String>{};
    final currentPattern = RegExp(r'''<div[^>]+class=["'][^"']*title-card[^"']*["'][\s\S]*?<a[^>]+href=["']([^"']*/titles/[^"']+)["'][\s\S]*?<img[^>]+(?:src|data-src)=["']([^"']+)["'][^>]*>[\s\S]*?<h2[^>]+class=["'][^"']*title-name[^"']*["'][^>]*>([\s\S]*?)</h2>''', caseSensitive: false);
    for (final match in currentPattern.allMatches(html)) {
      final url = HtmlParse.absUrl(_base, match.group(1)!);
      if (!url.contains('/titles/') || !currentSeen.add(url)) continue;
      final title = HtmlParse.stripTags(match.group(3) ?? '');
      if (title.isEmpty) continue;
      current.add(item(title: title, url: url, image: HtmlParse.absUrl(_base, match.group(2)!), type: 'anime'));
    }
    if (current.isNotEmpty) return current;

    final modern = <Map<String, dynamic>>[];
    final modernSeen = <String>{};
    final modernPattern = RegExp(r'''<a[^>]+href=[\"'](https?://anime3rb\.com/titles/[^\"']+)[\"'][\s\S]{0,500}?<img[^>]+(?:src|data-src)=[\"']([^\"']+)[\"'][\s\S]{0,350}?(?:alt=[\"']([^\"']+)[\"']|<h2[^>]*>([\s\S]*?)</h2>)''', caseSensitive: false);
    for (final match in modernPattern.allMatches(html)) {
      final url = match.group(1)!;
      if (!modernSeen.add(url)) continue;
      final rawTitle = match.group(3) ?? match.group(4) ?? url.split('/').last;
      modern.add(item(title: HtmlParse.stripTags(rawTitle), url: url, image: HtmlParse.absUrl(_base, match.group(2)!), type: 'anime'));
    }
    if (modern.isNotEmpty) return modern;

    final items = <Map<String, dynamic>>[];
    final seen = <String>{};
    final pattern = RegExp(r'<a[^>]+href="(https?://[^"]+|/?[^"]+)"[^>]*>[\s\S]{0,1200}?(?:src|data-src)="([^"]+)"[\s\S]{0,400}?(?:alt|title)="([^"]+)"', caseSensitive: false);
    for (final match in pattern.allMatches(html)) {
      final url = HtmlParse.absUrl(_base, match.group(1)!);
      if (!url.contains('anime3rb.com') || url.contains('/tag') || url.contains('/genre') || url.contains('/page') || !seen.add(url)) continue;
      items.add(item(title: HtmlParse.stripTags(match.group(3)!), url: url, image: HtmlParse.absUrl(_base, match.group(2)!), type: 'anime'));
    }
    if (items.isNotEmpty) return items;
    for (final link in HtmlParse.markdownLinks(html)) {
      final url = link['url'] ?? '';
      if (!url.contains('anime3rb.com') || url.contains('/tag') || url.contains('/genre') || !seen.add(url)) continue;
      items.add(item(title: link['title'] ?? url, url: url, type: 'anime'));
    }
    return items;
  }

  List<Map<String, dynamic>> _parseGeneric(String html, String query) {
    final items = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final match in RegExp(r'''href=["'](https?://anime3rb\.com/titles/[^"']+)["'][^>]*>([\s\S]*?)</a>''', caseSensitive: false).allMatches(html)) {
      final url = match.group(1)!;
      final title = HtmlParse.stripTags(match.group(2) ?? '');
      if (title.isEmpty || !seen.add(url)) continue;
      if (url.endsWith('/titles/list')) continue;
      if (query.isNotEmpty && !title.toLowerCase().contains(query.toLowerCase()) && !url.toLowerCase().contains(query.toLowerCase())) continue;
      items.add(item(title: title, url: url, type: 'anime'));
    }
    return items;
  }

  List<Map<String, dynamic>> _parseEpisodes(String html, String pageUrl) {
    final episodes = <Map<String, dynamic>>[];
    final seen = <String>{};
    final count = _episodeCount(html);
    final titleMatch = RegExp(r'/titles/([^/?#]+)', caseSensitive: false).firstMatch(pageUrl);
    if (count != null && titleMatch != null) {
      final slug = titleMatch.group(1)!;
      for (var number = 1; number <= count; number++) {
        episodes.add({'title': 'الحلقة $number', 'name': 'الحلقة $number', 'url': '$_base/episode/$slug/$number', 'number': number});
      }
      return episodes;
    }

    void addEpisode(String rawUrl, String text) {
      final url = HtmlParse.absUrl(pageUrl, rawUrl).split('#').first;
      final path = Uri.tryParse(url)?.path ?? '';
      if (!url.contains('anime3rb.com') || !seen.add(url) || url == pageUrl) return;
      final isEpisodePath = RegExp(r'^/episode/[^/]+/[^/]+/?$', caseSensitive: false).hasMatch(path);
      final decoded = Uri.decodeComponent(url);
      final looksLikeEpisode = decoded.contains('حلقة') || decoded.toLowerCase().contains('episode') || text.contains('حلقة') || text.toLowerCase().contains('episode') || RegExp(r'\d+').hasMatch(text);
      if (!isEpisodePath && !(path.contains('/episode/') && looksLikeEpisode)) return;
      final number = SourceUtils.episodeNumber('$text $decoded');
      if (number == null) return;
      episodes.add({'title': 'الحلقة $number', 'name': 'الحلقة $number', 'url': url, 'number': number});
    }

    for (final match in RegExp(r'''<a[^>]+href=["']([^"']+)["'][^>]*>([\s\S]*?)</a>''', caseSensitive: false).allMatches(html)) {
      addEpisode(match.group(1)!, HtmlParse.stripTags(match.group(2) ?? ''));
    }
    for (final link in HtmlParse.markdownLinks(html)) addEpisode(link['url'] ?? '', link['title'] ?? '');
    episodes.sort((a, b) => (a['number'] as int).compareTo(b['number'] as int));
    return episodes;
  }

  int? _episodeCount(String html) {
    final candidates = <int>[];
    for (final pattern in [
      RegExp(r'(?:عدد الحلقات|عدد حلقات|episodes?|episode_count)[^0-9]{0,80}(\d+)', caseSensitive: false),
      RegExp(r'''class=["'][^"']*text-lg[^"']*leading-relaxed[^"']*["'][^>]*>\s*(\d+)\s*<''', caseSensitive: false),
      RegExp(r'"(?:episodes|episode_count|episodes_count)"\s*:\s*(\d+)', caseSensitive: false),
    ]) {
      candidates.addAll(pattern.allMatches(html).map((m) => int.tryParse(m.group(1)!)).whereType<int>());
    }
    final count = candidates.where((value) => value > 0 && value <= 2000).fold<int>(0, (max, value) => value > max ? value : max);
    return count > 0 ? count : null;
  }
}
