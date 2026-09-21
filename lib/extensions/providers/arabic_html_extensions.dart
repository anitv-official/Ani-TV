import 'dart:convert';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import '../extension_base.dart';
import '../../sources/source_base.dart';
import 'extension_http.dart';

abstract class ArabicHtmlExtension extends AniExtension {
  final http.Client client = http.Client();
  final Map<String, String> cookies = {};

  String get baseUrl;
  @override List<String> get hosts;

  Map<String, String> headers({String? referer}) => {
        'User-Agent': ExtensionHttp.userAgent,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'ar,en-US;q=0.9,en;q=0.8',
        if (referer != null) 'Referer': referer,
        if (cookies.isNotEmpty) 'Cookie': cookies.entries.map((e) => '${e.key}=${e.value}').join('; '),
      };

  Future<http.Response> get(String url, {String? referer}) async {
    final response = await client.get(Uri.parse(url), headers: headers(referer: referer)).timeout(const Duration(seconds: 25));
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null) {
      for (final part in setCookie.split(RegExp(r', (?=[^;,]+=)'))) {
        final pair = part.split(';').first.split('=');
        if (pair.length >= 2) cookies[pair.first.trim()] = pair.sublist(1).join('=').trim();
      }
    }
    return response;
  }

  Future<dom.Document?> document(String url, {String? referer}) async {
    try {
      final response = await get(url, referer: referer);
      if (response.statusCode < 200 || response.statusCode >= 400) return null;
      return html_parser.parse(utf8.decode(response.bodyBytes, allowMalformed: true));
    } catch (_) {
      return null;
    }
  }

  String abs(String url, String base) => Uri.parse(base).resolve(url.trim()).toString();
  String clean(String text) => SourceUtils.cleanTitle(text.replaceAll(RegExp(r'\s+'), ' '));
  String attr(dom.Element? element, String key) => element?.attributes[key]?.trim() ?? '';
  String image(dom.Element? element, String pageUrl) {
    final value = attr(element, 'data-src').isNotEmpty ? attr(element, 'data-src') : attr(element, 'src');
    return value.isEmpty ? '' : abs(value, pageUrl);
  }

  List<Map<String, dynamic>> cards(dom.Document doc, String pageUrl, {String selector = 'li.movieItem, article.postEp, .postDiv, .blockMovie, div.item'}) {
    final results = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final card in doc.querySelectorAll(selector)) {
      final anchor = card.querySelector('a[href]');
      if (anchor == null) continue;
      final url = abs(attr(anchor, 'href'), pageUrl);
      if (!handles(url) || !seen.add(url)) continue;
      final title = clean(attr(anchor, 'title').isNotEmpty ? attr(anchor, 'title') : card.querySelector('h1,h2,h3,h4,.title,.h1,.h4,.h5')?.text ?? anchor.text);
      if (title.length < 2 || _navigation(title)) continue;
      final kind = url.contains('/movie/') || url.contains('/movies/') ? 'movie' : url.contains('/series/') ? 'series' : 'series';
      results.add(item(title: title, url: url, image: image(card.querySelector('img'), pageUrl), type: kind));
      if (results.length >= 60) break;
    }
    return results;
  }

  bool _navigation(String text) => RegExp(r'^(home|search|login|register|تسجيل الدخول|دخول|الرئيسية|بحث|المزيد)$', caseSensitive: false).hasMatch(text.trim());

  Map<String, dynamic> episode(String url, String title, int number, {String imageUrl = '', int season = 1}) => {
        'id': '${season}_$number', 'title': title.isEmpty ? 'الحلقة $number' : title,
        'number': number, 'season': season, 'url': url, if (imageUrl.isNotEmpty) 'image': imageUrl,
      };

  List<Map<String, dynamic>> episodesFrom(Iterable<dom.Element> nodes, String pageUrl, {String? imageUrl}) {
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final node in nodes) {
      final a = node.localName == 'a' ? node : node.querySelector('a[href]');
      if (a == null) continue;
      final url = abs(attr(a, 'href'), pageUrl);
      if (!url.contains('/episode/') || !seen.add(url)) continue;
      final raw = clean(attr(a, 'title').isNotEmpty ? attr(a, 'title') : a.text);
      final number = SourceUtils.episodeNumber(raw) ?? result.length + 1;
      result.add(episode(url, raw.isEmpty ? 'الحلقة $number' : raw, number, imageUrl: imageUrl ?? ''));
    }
    result.sort((a, b) => (a['number'] as int).compareTo(b['number'] as int));
    return result;
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async {
    final doc = await document(url, referer: url);
    if (doc == null) return null;
    final links = <Map<String, String>>[];
    for (final source in doc.querySelectorAll('video source[src], video[src], source[src]')) {
      final value = attr(source, 'src');
      if (value.isEmpty) continue;
      links.add({'url': abs(value, url), 'quality': attr(source, 'size').isEmpty ? 'Auto' : attr(source, 'size'), 'name': name, 'label': name, 'type': 'video'});
    }
    for (final iframe in doc.querySelectorAll('iframe[src], [data-player]')) {
      final value = attr(iframe, 'src').isNotEmpty ? attr(iframe, 'src') : attr(iframe, 'data-player');
      if (value.isEmpty) continue;
      links.add({'url': abs(value, url), 'quality': 'Auto', 'name': name, 'label': name, 'type': 'embed'});
    }
    if (links.isEmpty) return null;
    return {'stream_url': links.first['url'], 'direct_stream_urls': links, 'headers': headers(referer: url), 'allowed_hosts': hosts};
  }
}

class KrmzyExtension extends ArabicHtmlExtension {
  @override String get id => 'krmzy';
  @override String get name => 'Krmzy';
  @override String get kind => 'drama';
  @override List<String> get hosts => const ['krmzi.org'];
  @override String get baseUrl => 'https://krmzi.org/';
  @override String get contentLabel => 'مسلسلات وأفلام';
  @override String get iconUrl => 'https://krmzi.org/favicon.ico';
  @override ExtensionStatus get status => ExtensionStatus.limited;
  @override String get statusMessage => 'HTML وEmbed مع حماية الموقع';

  @override Future<List<Map<String, dynamic>>> latest({int page = 1}) async => cards(await document('$baseUrl${page <= 1 ? 'series-list/' : 'series-list/page/$page/'}') ?? html_parser.parse(''), baseUrl, selector: 'article.postEp, div.block-post');
  @override Future<List<Map<String, dynamic>>> search(String query) async => cards(await document(Uri.parse(baseUrl).replace(queryParameters: {'s': query}).toString()) ?? html_parser.parse(''), baseUrl, selector: 'article.postEp, div.block-post');

  @override Future<Map<String, dynamic>> details(String url) async {
    final doc = await document(url) ?? html_parser.parse('');
    final title = clean(doc.querySelector('div.info h1, h1')?.text ?? name);
    final poster = image(doc.querySelector('div.cover img, .imgSer img, .imgBg img'), url);
    final eps = episodesFrom(doc.querySelectorAll('article.postEp, .episodes a, a[href*="/episode/"]'), url, imageUrl: poster);
    return {...item(title: title, url: url, image: poster, type: url.contains('/movies/') ? 'movie' : 'series'), 'episodes': url.contains('/movies/') ? <Map<String, dynamic>>[] : eps, 'total_episodes': eps.length};
  }
}

class AflaamExtension extends ArabicHtmlExtension {
  @override String get id => 'aflaam';
  @override String get name => 'Aflaam';
  @override String get kind => 'drama';
  @override List<String> get hosts => const ['aflaam.com'];
  @override String get baseUrl => 'https://aflaam.com/';
  @override String get contentLabel => 'أفلام ومسلسلات';
  @override String get iconUrl => 'https://aflaam.com/favicon.ico';
  @override ExtensionStatus get status => ExtensionStatus.limited;
  @override String get statusMessage => 'مصدر أفلام ومسلسلات HTML';

  @override Future<List<Map<String, dynamic>>> latest({int page = 1}) async => cards(await document('${baseUrl}search?section=2${page > 1 ? '&page=$page' : ''}') ?? html_parser.parse(''), baseUrl, selector: 'div.item');
  @override Future<List<Map<String, dynamic>>> search(String query) async => cards(await document(Uri.parse(baseUrl).replace(path: '/search', queryParameters: {'q': query}).toString()) ?? html_parser.parse(''), baseUrl, selector: 'div.item');

  @override Future<Map<String, dynamic>> details(String url) async {
    final doc = await document(url) ?? html_parser.parse('');
    final title = clean(doc.querySelector('h1.font-size-44, h1')?.text ?? name);
    final poster = image(doc.querySelector('a.movie-poster img, img.poster'), url);
    final eps = episodesFrom(doc.querySelectorAll('#movie-tab-1 .entry-box-3, a[href*="/episode/"]'), url, imageUrl: poster);
    final type = url.contains('/series/') ? 'series' : 'movie';
    return {...item(title: title, url: url, image: poster, type: type, description: clean(doc.querySelector('#movie-tab-2 p, .synopsis')?.text ?? '')), 'episodes': eps, 'total_episodes': eps.length};
  }

  @override Future<Map<String, dynamic>?> streams(String url) async {
    final doc = await document(url, referer: url);
    if (doc == null) return null;
    final links = <Map<String, String>>[];
    for (final quality in doc.querySelectorAll('div.qualities a.link-show, a.link-show')) {
      final watch = abs(attr(quality, 'href'), url);
      final watchDoc = await document(watch, referer: url);
      for (final source in watchDoc?.querySelectorAll('video#player source[src], video source[src]') ?? const <dom.Element>[]) {
        final src = attr(source, 'src');
        if (src.isNotEmpty) links.add({'url': abs(src, watch), 'quality': attr(source, 'size').isEmpty ? 'Auto' : attr(source, 'size'), 'name': name, 'label': name, 'type': 'video'});
      }
    }
    return links.isEmpty ? null : {'stream_url': links.first['url'], 'direct_stream_urls': links, 'headers': headers(referer: url)};
  }
}

class AkwamExtension extends ArabicHtmlExtension {
  @override String get id => 'akwam';
  @override String get name => 'Akwam';
  @override String get kind => 'drama';
  @override List<String> get hosts => const ['ak.sv', 'akwam.ss'];
  @override String get baseUrl => 'https://ak.sv/';
  @override String get contentLabel => 'أفلام ومسلسلات';
  @override String get iconUrl => 'https://ak.sv/favicon.ico';
  @override ExtensionStatus get status => ExtensionStatus.limited;
  @override String get statusMessage => 'مصدر متعدد الأقسام وروابط مباشرة';

  @override Future<List<Map<String, dynamic>>> latest({int page = 1}) async => cards(await document('$baseUrl${page <= 1 ? 'movies' : 'movies?page=$page'}') ?? html_parser.parse(''), baseUrl, selector: 'div.col-lg-auto.col-md-4.col-6, div.postDiv');
  @override Future<List<Map<String, dynamic>>> search(String query) async => cards(await document(Uri.parse(baseUrl).replace(queryParameters: {'s': query}).toString()) ?? html_parser.parse(''), baseUrl, selector: 'div.postDiv, article');

  @override Future<Map<String, dynamic>> details(String url) async {
    final doc = await document(url, referer: baseUrl) ?? html_parser.parse('');
    final title = clean(doc.querySelector('h1.entry-title, h1')?.text ?? name);
    final poster = image(doc.querySelector('img[data-src], img'), url);
    final eps = episodesFrom(doc.querySelectorAll('#series-episodes div.col-lg-4, #series-episodes div.col-md-6, a[href*="/episode/"]'), url, imageUrl: poster);
    return {...item(title: title, url: url, image: poster, type: eps.isEmpty ? 'movie' : 'series'), 'episodes': eps, 'total_episodes': eps.length};
  }

  @override Future<Map<String, dynamic>?> streams(String url) async {
    final doc = await document(url, referer: url);
    if (doc == null) return null;
    final links = <Map<String, String>>[];
    for (final source in doc.querySelectorAll('source[src], video[src]')) {
      final value = attr(source, 'src');
      if (value.isNotEmpty) links.add({'url': abs(value, url).replaceFirst('https://', 'http://'), 'quality': attr(source, 'size').isEmpty ? 'Auto' : attr(source, 'size'), 'name': name, 'label': name, 'type': 'video'});
    }
    return links.isEmpty ? null : {'stream_url': links.first['url'], 'direct_stream_urls': links, 'headers': headers(referer: url)};
  }
}

class FaselhdExtension extends ArabicHtmlExtension {
  @override String get id => 'faselhd';
  @override String get name => 'FASELHD';
  @override String get kind => 'drama';
  @override List<String> get hosts => const ['faselhdx.bid', 'fasel-hd.co', 'faselhd.co'];
  @override String get baseUrl => 'https://www.fasel-hd.co/main';
  @override String get contentLabel => 'أفلام ومسلسلات';
  @override String get iconUrl => 'https://www.fasel-hd.co/favicon.ico';
  @override ExtensionStatus get status => ExtensionStatus.limited;
  @override String get statusMessage => 'قد يتطلب تجاوز حماية Cloudflare';

  @override Future<List<Map<String, dynamic>>> latest({int page = 1}) async => cards(await document('$baseUrl${page > 1 ? '/page/$page' : ''}') ?? html_parser.parse(''), baseUrl, selector: '.postDiv, .blockMovie, article');
  @override Future<List<Map<String, dynamic>>> search(String query) async => cards(await document(Uri.parse(baseUrl).replace(queryParameters: {'s': query}).toString()) ?? html_parser.parse(''), baseUrl, selector: '.postDiv, article');

  @override Future<Map<String, dynamic>> details(String url) async {
    final doc = await document(url, referer: baseUrl) ?? html_parser.parse('');
    final title = clean(doc.querySelector('.singleInfo .title, h1.entry-title, h1')?.text ?? name);
    final poster = image(doc.querySelector('meta[itemprop="image"], .posterImg img, img'), url);
    final eps = episodesFrom(doc.querySelectorAll('#epAll a, a[href*="/episode/"]'), url, imageUrl: poster);
    return {...item(title: title, url: url, image: poster, type: eps.isEmpty ? 'movie' : 'series'), 'episodes': eps, 'total_episodes': eps.length};
  }
}
