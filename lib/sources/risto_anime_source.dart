import 'html_client.dart';
import 'source_base.dart';

class RistoAnimeSource extends ContentSource {
  static const String _base = 'https://ristoanime.me';
  static const String _logoMarker = 'dfhsfdhsf';

  @override
  String get id => 'risto';

  @override
  String get name => 'Risto Anime';

  @override
  String get kind => 'anime';

  @override
  List<String> get hosts => [
        'ristoanime.me',
        'www.ristoanime.me',
        'ristoanime.co',
      ];

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
    final url = page <= 1 ? '$_base/series/' : '$_base/series/page/$page/';
    final html = await HtmlClient.getHtml(url);
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
    final image = _detailsCover(html, url);
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
    final watchUrl = _watchPageUrl(url);
    String html;
    try {
      html = await HtmlClient.getHtml(watchUrl);
    } catch (_) {
      html = await HtmlClient.getHtml(url);
    }
    if (!_hasWatchServers(html)) {
      try {
        html = await HtmlClient.getHtml(_watchQueryUrl(url));
      } catch (_) {}
    }

    final servers = <Map<String, String>>[];
    final seen = <String>{};

    Future<void> add(String raw, [String quality = 'خادم']) async {
      var resolved = HtmlParse.absUrl(url, raw);
      if (resolved.isEmpty || !seen.add(resolved)) return;
      if (!_isDirectMedia(resolved)) {
        try {
          final embedded = await HtmlClient.getHtml(resolved);
          for (final media in SourceUtils.extractMediaUrls(embedded, resolved)) {
            if (_isDirectMedia(media)) {
              resolved = media;
              break;
            }
          }
        } catch (_) {}
      }
      if (!_isDirectMedia(resolved)) return;
      if (resolved.contains('facebook.com') ||
          resolved.contains('twitter.com') ||
          resolved.contains('x.com') ||
          resolved.contains('ristoanime.me') ||
          resolved.contains('ristoanime.co')) {
        return;
      }
      servers.add({'quality': quality, 'url': resolved});
    }

    var index = 1;
    for (final match in RegExp(
      r'''data-watch=["']([^"']+)["']''',
      caseSensitive: false,
    ).allMatches(html)) {
      await add(match.group(1)!, 'سيرفر $index');
      index++;
    }
    for (final match in RegExp(
      r'''<iframe[^>]+src=["']([^"']+)["']''',
      caseSensitive: false,
    ).allMatches(html)) {
      await add(match.group(1)!, 'مشغل');
    }
    for (final match in RegExp(
      r'''data-(?:src|url|embed|link)=["']([^"']+)["']''',
      caseSensitive: false,
    ).allMatches(html)) {
      await add(match.group(1)!);
    }
    for (final match in RegExp(
      r'https?://[^\s"<>]+(?:\.mp4|\.m3u8)[^\s"<>]*',
      caseSensitive: false,
    ).allMatches(html)) {
      await add(match.group(0)!);
    }
    for (final match in RegExp(
      r'https?://[^\s"<>]+\.(?:mp4|m3u8)[^\s"<>]*',
      caseSensitive: false,
    ).allMatches(html)) {
      await add(match.group(0)!, 'مباشر');
    }
    for (final media in SourceUtils.extractMediaUrls(html, url)) {
      await add(media, 'مباشر');
    }

    if (servers.isEmpty) {
      throw Exception('لم يتم العثور على خوادم تشغيل لهذه الحلقة');
    }

    final playUrl = servers.first['url']!;
    final directLinks = servers.where((server) => _isDirectMedia(server['url']!)).toList();
    return {
      'source_id': id,
      'stream_url': playUrl,
      'direct_stream_urls': directLinks.map((s) => {'quality': s['quality'] ?? 'مباشر', 'url': s['url']!}).toList(),
      'headers': {
        'Referer': watchUrl,
        'User-Agent': HtmlClient.userAgent,
      },
      'download_links': {
        if (directLinks.isNotEmpty) 'مباشر': directLinks.map((s) => {'host': s['quality'] ?? 'Risto Anime', 'url': s['url']!}).toList(),
      },
    };
  }

  bool _isDirectMedia(String value) {
    final lower = value.toLowerCase();
    return RegExp(r'\.(?:mp4|m3u8|mov|webm)(?:[?#].*)?$').hasMatch(lower) ||
        lower.contains('pixeldrain.com/api/file');
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
      if (_isLogo(image)) image = '';
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
      final pathParts =
          Uri.tryParse(url)?.pathSegments.where((p) => p.isNotEmpty).toList() ??
              [];
      if (url.contains('/page/') ||
          url.contains('/feed') ||
          !url.contains('/series/') ||
          pathParts.length < 2 ||
          !seen.add(url)) {
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
      var image = HtmlParse.firstMatch(block, [
            RegExp(r'url\(([^)]+)\)', caseSensitive: false),
            RegExp(r'''(?:src|data-src)=["']([^"']+)["']''',
                caseSensitive: false),
          ]) ??
          '';
      image = image.replaceAll("'", '').replaceAll('"', '').trim();
      if (_isLogo(image)) image = '';
      if (image.isNotEmpty) image = HtmlParse.absUrl(_base, image);
      final genre = HtmlParse.firstMatch(
          block, [RegExp(r'class="genre"[^>]*>([^<]+)<', caseSensitive: false)]);
      final rating =
          HtmlParse.firstMatch(block, [RegExp(r'([\d.]+)\s*/\s*10')]) ?? '';
      items.add(item(
        title: title,
        url: url,
        image: image,
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
    final listBlock = RegExp(
      r'class="EpisodesList"[^>]*>([\s\S]*?)</div>',
      caseSensitive: false,
    ).firstMatch(html);
    final haystack = listBlock?.group(1) ?? html;
    final pattern = RegExp(
      r'''<a[^>]+href=["'](https?://(?:www\.)?ristoanime\.(?:me|co)/[^"']+)["'][^>]*>([\s\S]*?)</a>''',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(haystack)) {
      final url = match.group(1)!;
      if (url.contains('/series/') ||
          url.contains('/page/') ||
          url.contains('/feed') ||
          url.contains('/movies') ||
          url.contains('/genre') ||
          url.contains('/category') ||
          url.contains('/watch')) {
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
      final normalized = url.split('?').first;
      if (collected.containsKey(normalized)) continue;
      final number = SourceUtils.episodeNumber('$text $decodedUrl');
      collected[normalized] = {
        'title': text.isNotEmpty
            ? SourceUtils.episodeTitle(text, number)
            : SourceUtils.episodeTitle(decodedUrl, number),
        'url': normalized,
        'number': number ?? collected.length + 1,
      };
    }
  }

  String _detailsCover(String html, String pageUrl) {
    final candidates = <String>[
      HtmlParse.firstMatch(html, [
            RegExp(
                r'class="InnerPoster"[\s\S]*?<img[^>]+src="([^"]+)"',
                caseSensitive: false),
          ]) ??
          '',
      HtmlParse.firstMatch(html, [
            RegExp(r'class="BG"[^>]*url\(([^)]+)\)', caseSensitive: false),
          ]) ??
          '',
      HtmlParse.firstMatch(html, [
            RegExp(
                r'class="singleCover"[\s\S]{0,400}?url\(([^)]+)\)',
                caseSensitive: false),
          ]) ??
          '',
      HtmlParse.meta(html, 'og:image') ?? '',
    ];
    for (var raw in candidates) {
      raw = raw.replaceAll("'", '').replaceAll('"', '').trim();
      if (raw.isEmpty || _isLogo(raw)) continue;
      return HtmlParse.absUrl(pageUrl, raw);
    }
    return '';
  }

  bool _isLogo(String url) {
    final lower = url.toLowerCase();
    return lower.contains(_logoMarker) ||
        lower.contains('header-logo') ||
        lower.contains('/logo') ||
        lower.endsWith('logo.png');
  }

  bool _hasWatchServers(String html) {
    return html.contains('data-watch=') || html.contains('id="watch"');
  }

  String _watchPageUrl(String url) {
    final uri = Uri.parse(url);
    final path = uri.path.endsWith('/')
        ? '${uri.path}watch/'
        : '${uri.path}/watch/';
    return uri.replace(path: path, query: '').toString();
  }

  String _watchQueryUrl(String url) {
    final uri = Uri.parse(url);
    return uri.replace(queryParameters: {'watch': '1'}).toString();
  }
}
