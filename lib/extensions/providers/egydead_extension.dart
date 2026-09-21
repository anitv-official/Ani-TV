import 'dart:convert';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import '../extension_base.dart';
import '../../sources/source_base.dart';
import 'extension_http.dart';

class EgyDeadExtension extends AniExtension {
  static const _base = 'https://tv10.egydead.live/';
  static const _host = 'tv10.egydead.live';
  static const _userAgent = ExtensionHttp.userAgent;

  final http.Client _client = http.Client();
  final Map<String, String> _cookies = {};

  @override String get id => 'egydead';
  @override String get name => 'EgyDead';
  @override String get kind => 'drama';
  @override List<String> get hosts => const [_host, 'egydead.live'];
  @override String get contentLabel => 'أفلام ومسلسلات';
  @override String get iconUrl => 'https://tv10.egydead.live/favicon.ico';
  @override ExtensionStatus get status => ExtensionStatus.limited;
  @override String get statusMessage => 'روابط مباشرة وEmbed مع جلسة Cookies';

  Map<String, String> _headers({String? referer, bool post = false}) => {
        'User-Agent': _userAgent,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'ar,en-US;q=0.9,en;q=0.8',
        'Upgrade-Insecure-Requests': '1',
        if (referer != null) 'Referer': referer,
        if (_cookies.isNotEmpty) 'Cookie': _cookies.entries.map((e) => '${e.key}=${e.value}').join('; '),
        if (post) 'X-Requested-With': 'XMLHttpRequest',
        if (post) 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      };

  Future<http.Response> _get(String url, {String? referer}) async {
    final response = await _client.get(Uri.parse(url), headers: _headers(referer: referer)).timeout(const Duration(seconds: 25));
    _saveCookies(response);
    return response;
  }

  Future<http.Response> _post(String url, {required String referer}) async {
    final response = await _client.post(Uri.parse(url), headers: _headers(referer: referer, post: true), body: 'View=1').timeout(const Duration(seconds: 25));
    _saveCookies(response);
    return response;
  }

  void _saveCookies(http.Response response) {
    final values = response.headers['set-cookie'];
    if (values == null) return;
    for (final value in values.split(RegExp(r', (?=[^;,]+=)'))) {
      final pair = value.split(';').first.split('=');
      if (pair.length >= 2) _cookies[pair.first.trim()] = pair.sublist(1).join('=').trim();
    }
  }

  Future<dom.Document?> _document(String url, {String? referer}) async {
    try {
      final response = await _get(url, referer: referer);
      if (response.statusCode < 200 || response.statusCode >= 400) return null;
      return html_parser.parse(utf8.decode(response.bodyBytes, allowMalformed: true));
    } catch (_) {
      return null;
    }
  }

  String _resolve(String raw, String base) => Uri.parse(base).resolve(raw.trim()).toString();

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final document = await _document(_base);
    if (document == null) return [];
    final elements = <dom.Element>[
      ...document.querySelectorAll('div.pin-posts-list li.movieItem'),
      ...document.querySelectorAll('section.main-section li.movieItem'),
      ...document.querySelectorAll('ul.posts-list li.movieItem'),
    ];
    return _itemsFromElements(elements);
  }

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return latest();
    final url = Uri.parse(_base).replace(queryParameters: {'s': value}).toString();
    final document = await _document(url);
    return document == null ? [] : _itemsFromElements(document.querySelectorAll('ul.posts-list li.movieItem'));
  }

  List<Map<String, dynamic>> _itemsFromElements(Iterable<dom.Element> elements) {
    final output = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final element in elements) {
      final anchor = element.querySelector('a');
      final href = anchor?.attributes['href'];
      if (href == null || href.isEmpty) continue;
      final url = _resolve(href, _base);
      if (!handles(url) || !seen.add(url)) continue;
      final title = _clean(anchor?.attributes['title'] ?? element.querySelector('h1.BottomTitle')?.text ?? element.querySelector('h3')?.text ?? anchor?.text ?? '');
      if (title.length < 2 || _isNavigation(title)) continue;
      final image = element.querySelector('img')?.attributes['data-src'] ?? element.querySelector('img')?.attributes['src'] ?? '';
      output.add(item(title: title, url: url, image: image.isEmpty ? '' : _resolve(image, _base), type: url.contains('/film/') ? 'movie' : 'series'));
      if (output.length == 60) break;
    }
    return output;
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final document = await _document(url, referer: _base);
    if (document == null) throw Exception('تعذر تحميل تفاصيل EgyDead');
    final title = _clean(_meta(document, 'og:title') ?? document.querySelector('h1')?.text ?? name);
    final poster = _meta(document, 'og:image') ?? '';
    final description = _clean(_meta(document, 'og:description') ?? document.querySelector('div.singleStory')?.text ?? '');
    final isMovie = url.contains('/film/') || RegExp(r'\b(فيلم|movie|film)\b', caseSensitive: false).hasMatch(title);
    final isEpisode = url.contains('/episode/') || url.contains('/watch/') || RegExp(r'(الحلقة|episode|ep\.?\s*\d+)', caseSensitive: false).hasMatch(title);
    final episodes = isMovie || isEpisode
        ? [_episode(url, title, isEpisode ? (_episodeNumber(title) ?? _episodeNumber(url) ?? 1) : 1)]
        : await _loadSeriesEpisodes(document, url);
    return {
      ...item(title: title, url: url, image: poster, type: isMovie ? 'movie' : 'series', description: description),
      'episodes': episodes,
      'total_episodes': episodes.length,
    };
  }

  Future<List<Map<String, dynamic>>> _loadSeriesEpisodes(dom.Document document, String url) async {
    final seasonUrls = <String>{};
    for (final anchor in document.querySelectorAll('div.seasons-list a, div.seasons a, div.seasons-list li a, ul.seasons a, .season-list a, .seasons-list a, a[href*="/season/"]')) {
      final href = anchor.attributes['href'];
      if (href == null) continue;
      final resolved = _resolve(href, url);
      if (resolved.contains('/season/') || RegExp(r'(?:season|الموسم)', caseSensitive: false).hasMatch(resolved)) seasonUrls.add(resolved);
    }
    final pages = <String, dom.Document>{url: document};
    for (final seasonUrl in seasonUrls) {
      final seasonDoc = await _document(seasonUrl, referer: url);
      if (seasonDoc != null) pages[seasonUrl] = seasonDoc;
    }
    final episodes = <Map<String, dynamic>>[];
    for (final entry in pages.entries) episodes.addAll(_episodesFromDocument(entry.value, entry.key));
    if (episodes.isEmpty && url.contains('/episode/')) episodes.add(_episode(url, _clean(_meta(document, 'og:title') ?? 'الحلقة'), _episodeNumber(url) ?? 1));
    final seen = <String>{};
    final unique = episodes.where((episode) => seen.add(episode['url'].toString())).toList();
    unique.sort((a, b) {
      final season = (a['season'] as int? ?? 1).compareTo(b['season'] as int? ?? 1);
      return season == 0 ? (a['number'] as int).compareTo(b['number'] as int) : season;
    });
    return unique;
  }

  List<Map<String, dynamic>> _episodesFromDocument(dom.Document document, String pageUrl) {
    final containers = <dom.Element>[
      ...document.querySelectorAll('div.EpsList'),
      ...document.querySelectorAll('div.episodes-list'),
      ...document.querySelectorAll('ul.episodes'),
      ...document.querySelectorAll('.EpisodesList, .episodes-list, .all-episodes, .season-episodes, .watch-episodes'),
    ];
    if (containers.isEmpty && pageUrl.contains('/season/')) return [];
    final nodes = containers.isNotEmpty
        ? containers.expand((container) => container.querySelectorAll('li, a'))
        : document.querySelectorAll('a[href*="/episode/"], a[href*="/watch/"], a[href*="episode"], a[data-episode]');
    if (nodes.isEmpty && pageUrl.contains('/episode/')) {
      final title = _clean(_meta(document, 'og:title') ?? document.querySelector('h1')?.text ?? 'الحلقة');
      return [_episode(pageUrl, title, _episodeNumber(title) ?? _episodeNumber(pageUrl) ?? 1)];
    }
    final output = <Map<String, dynamic>>[];
    for (final node in nodes) {
      final anchor = node.localName == 'a' ? node : node.querySelector('a');
      if (anchor == null) continue;
      final href = anchor.attributes['href'];
      if (href == null) continue;
      final resolved = _resolve(href, pageUrl);
      final episodeLike = resolved.contains('/episode/') || resolved.contains('/watch/') || resolved.contains('episode') || anchor.attributes['data-episode'] != null;
      if (!episodeLike || resolved.contains('/season/') || resolved.contains('/film/')) continue;
      final title = _clean(anchor.attributes['title'] ?? anchor.text);
      final number = _episodeNumber(title) ?? _episodeNumber(resolved) ?? output.length + 1;
      output.add(_episode(resolved, title.isEmpty ? 'الحلقة $number' : title, number, season: _seasonNumber(title) ?? _seasonNumber(pageUrl) ?? 1));
    }
    return output;
  }

  Map<String, dynamic> _episode(String url, String title, int number, {int season = 1}) => {
        'id': '${season}_$number',
        'title': title.isEmpty ? 'الحلقة $number' : title,
        'number': number,
        'season': season,
        'url': url,
      };

  @override
  Future<Map<String, dynamic>?> streams(String url) async {
    await _get(url, referer: url); // establish cookies before the watch request
    final watchUrl = Uri.parse(url).queryParameters.containsKey('view') ? url : '$url${url.contains('?') ? '&' : '?'}view=watch';
    http.Response response;
    try {
      response = await _post(watchUrl, referer: url);
    } catch (_) {
      response = await _get(watchUrl, referer: url);
    }
    if (response.statusCode < 200 || response.statusCode >= 400) return null;
    final html = utf8.decode(response.bodyBytes, allowMalformed: true);
    final candidates = <_Candidate>[];
    void add(String? raw, String? server) {
      if (raw == null || raw.trim().isEmpty) return;
      final value = raw.trim().replaceAll('&amp;', '&');
      if (value.startsWith('#') || value.toLowerCase().startsWith('javascript:')) return;
      final resolved = _resolve(value, watchUrl);
      if (RegExp(r'(facebook|twitter|telegram|login|register|doubleclick|googlesyndication|adsystem)', caseSensitive: false).hasMatch(resolved)) return;
      if (!handles(resolved) && !resolved.startsWith('http')) return;
      if (candidates.any((candidate) => candidate.url == resolved)) return;
      candidates.add(_Candidate(resolved, server?.trim().isEmpty == true ? null : server?.trim()));
    }
    final document = html_parser.parse(html);
    for (final selector in ['ul.donwload-servers-list li', 'ul.download-servers-list li', 'div.donwload-servers-list li', 'ul.serversList li', 'ul.servers-list li', 'div.serversList li', 'div.servers-list li', '.servers a', '.server a', '[data-server]']) {
      for (final li in document.querySelectorAll(selector)) {
        add(li.attributes['data-link'] ?? li.querySelector('[data-link]')?.attributes['data-link'] ?? li.querySelector('button[data-link]')?.attributes['data-link'] ?? li.querySelector('a.ser-link')?.attributes['href'] ?? li.querySelector('a')?.attributes['href'], li.querySelector('p')?.text ?? li.querySelector('.ser-name')?.text ?? li.querySelector('span.ser-name')?.text ?? li.attributes['data-name'] ?? li.attributes['data-provider']);
      }
    }
    for (final element in document.querySelectorAll('[data-link], [data-url], [data-server-url]')) add(element.attributes['data-link'] ?? element.attributes['data-url'] ?? element.attributes['data-server-url'], element.attributes['data-name'] ?? element.attributes['data-provider'] ?? element.attributes['data-server']);
    for (final anchor in document.querySelectorAll('a')) {
      final href = anchor.attributes['href'];
      if (href != null && RegExp(r'(player|embed|download|drive|mp4|m3u8)', caseSensitive: false).hasMatch(href)) add(href, anchor.attributes['title'] ?? anchor.text);
    }
    for (final match in RegExp(r'''https?://[^\s"'<>]+\.(?:m3u8|mp4)(?:\?[^\s"'<>]+)?''', caseSensitive: false).allMatches(html)) add(match.group(0), 'Direct');
    if (candidates.isEmpty) {
      // The current site injects the real server iframe through JavaScript.
      // Returning the episode page lets the existing WebView execute that
      // script instead of selecting a trailer or a hidden ad iframe.
      return {
        'stream_url': url,
        'direct_stream_urls': [
          {'url': url, 'quality': 'Auto', 'name': 'EgyDead WebView', 'label': 'Episode page', 'type': 'embed'},
        ],
        'headers': _headers(referer: url),
        'allowed_hosts': [_host, 'cvt-s1.agl006.host', 'tv8.egydead.live'],
      };
    }
    final direct = candidates.where((candidate) => _isDirect(candidate.url)).map((candidate) => _link(candidate, direct: true)).toList();
    final embeds = candidates.where((candidate) => !_isDirect(candidate.url)).map((candidate) => _link(candidate, direct: false)).toList();
    final links = [...direct, ...embeds];
    final allowedHosts = candidates.map((candidate) => Uri.tryParse(candidate.url)?.host.toLowerCase().replaceFirst('www.', '')).whereType<String>().where((host) => host.isNotEmpty).toSet().toList();
    return {'stream_url': links.first['url'], 'direct_stream_urls': links, 'headers': _headers(referer: url), 'allowed_hosts': allowedHosts};
  }

  Map<String, String> _link(_Candidate candidate, {required bool direct}) => {
        'url': candidate.url,
        'quality': direct ? (_quality(candidate.url) == 0 ? 'Auto' : '${_quality(candidate.url)}p') : 'Auto',
        'name': candidate.server ?? 'EgyDead',
        'label': direct ? 'Direct' : 'Embed',
        'type': direct ? 'video' : 'embed',
      };

  bool _isDirect(String url) => RegExp(r'\.(?:m3u8|mp4)(?:[?#].*)?$', caseSensitive: false).hasMatch(url);
  int _quality(String url) => int.tryParse(RegExp(r'(\d{3,4})p', caseSensitive: false).firstMatch(url)?.group(1) ?? '') ?? 0;
  String? _meta(dom.Document document, String property) => document.querySelector('meta[property="$property"]')?.attributes['content'] ?? document.querySelector('meta[name="$property"]')?.attributes['content'];
  String _clean(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();
  bool _isNavigation(String value) => RegExp(r'^(home|search|login|register|تسجيل الدخول|دخول|الرئيسية|بحث|facebook|twitter|youtube|telegram)$', caseSensitive: false).hasMatch(value.trim());
  int? _episodeNumber(String value) => int.tryParse(RegExp(r'(?:الحلقة|حلقة|episode|ep)[\s:_\-.]*(\d+)', caseSensitive: false).firstMatch(value)?.group(1) ?? RegExp(r's\d+[\s._-]*e(\d+)', caseSensitive: false).firstMatch(value)?.group(1) ?? RegExp(r'(?:^|[^a-z])(\d{1,3})(?:[^a-z]|$)', caseSensitive: false).firstMatch(value)?.group(1) ?? '');
  int? _seasonNumber(String value) => int.tryParse(RegExp(r'(?:الموسم|season|s)[\s:_\-.]*(\d+)', caseSensitive: false).firstMatch(value)?.group(1) ?? '');
}

class _Candidate {
  final String url;
  final String? server;
  const _Candidate(this.url, this.server);
}
