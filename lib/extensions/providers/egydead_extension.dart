import 'dart:convert';
import 'package:http/http.dart' as http;
import '../extension_base.dart';
import 'extension_http.dart';

class EgyDeadExtension extends AniExtension {
  static const _base = 'https://tv10.egydead.live/';
  static const _host = 'tv10.egydead.live';

  @override String get id => 'egydead';
  @override String get name => 'EgyDead';
  @override String get kind => 'drama';
  @override List<String> get hosts => const [_host, 'egydead.live'];
  @override String get contentLabel => 'أفلام ومسلسلات';
  @override String get iconUrl => 'https://tv10.egydead.live/favicon.ico';
  @override ExtensionStatus get status => ExtensionStatus.limited;
  @override String get statusMessage => 'يتطلب استخراج السيرفرات أو WebView عند Cloudflare';

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final html = await ExtensionHttp.getText(_base);
    return _catalog(html);
  }

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return latest();
    final url = Uri.parse(_base).replace(queryParameters: {'s': value}).toString();
    return _catalog(await ExtensionHttp.getText(url));
  }

  List<Map<String, dynamic>> _catalog(String html) {
    final output = <Map<String, dynamic>>[];
    final seen = <String>{};
    final cards = RegExp(r'''<li[^>]*class=["'][^"']*movieItem[^"']*["'][^>]*>(.*?)</li>''', caseSensitive: false, dotAll: true);
    for (final match in cards.allMatches(html)) {
      final body = match.group(1) ?? '';
      final anchor = RegExp(r'''<a[^>]*href=["']([^"']+)["'][^>]*>(.*?)</a>''', caseSensitive: false, dotAll: true).firstMatch(body);
      if (anchor == null) continue;
      final url = Uri.parse(_base).resolve(anchor.group(1)!).toString();
      if (!seen.add(url)) continue;
      final image = RegExp(r'''(?:data-src|data-lazy-src|src)=["']([^"']+)''', caseSensitive: false).firstMatch(body)?.group(1) ?? '';
      final title = ExtensionHttp.text(anchor.group(2) ?? '');
      if (title.length < 2) continue;
      output.add(item(title: title, url: url, image: Uri.parse(_base).resolve(image).toString(), type: url.contains('/film/') ? 'movie' : 'series'));
      if (output.length >= 60) break;
    }
    return output;
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final html = await ExtensionHttp.getText(url, referer: _base);
    final title = HtmlMeta.first(html, ['og:title', 'title']) ?? name;
    final poster = HtmlMeta.meta(html, 'og:image') ?? '';
    final description = HtmlMeta.meta(html, 'og:description') ?? HtmlMeta.firstBlock(html, ['singleStory']) ?? '';
    final episodes = <Map<String, dynamic>>[];
    final links = ExtensionHttp.anchors(html, url);
    for (final link in links) {
      final lower = link['url']!.toLowerCase();
      final text = link['title'] ?? '';
      if (!lower.contains('/episode/') && !RegExp(r'(الحلقة|حلقة|episode|ep\.?\s*\d+)', caseSensitive: false).hasMatch(text)) continue;
      episodes.add({'title': text.isEmpty ? 'حلقة ${episodes.length + 1}' : text, 'number': SourceUtils.episodeNumber(text) ?? episodes.length + 1, 'url': link['url']});
    }
    if (episodes.isEmpty) episodes.add({'title': 'تشغيل', 'number': 1, 'url': url});
    return {...item(title: ExtensionHttp.text(title), url: url, image: poster, type: url.contains('/film/') ? 'movie' : 'series', description: ExtensionHttp.text(description)), 'episodes': episodes, 'total_episodes': episodes.length};
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async {
    final headers = ExtensionHttp.headers(referer: url);
    final watchUrl = Uri.parse(url).queryParameters.containsKey('view') ? url : '$url${url.contains('?') ? '&' : '?'}view=watch';
    String html = '';
    try {
      final response = await http.post(Uri.parse(watchUrl), headers: {...headers, 'X-Requested-With': 'XMLHttpRequest', 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8'}, body: 'View=1').timeout(const Duration(seconds: 20));
      html = utf8.decode(response.bodyBytes, allowMalformed: true);
    } catch (_) {
      html = await ExtensionHttp.getText(watchUrl, referer: url);
    }
    final links = <Map<String, String>>[];
    final media = RegExp(r'https?://[^\s"\'<>]+\.(?:m3u8|mp4)(?:\?[^\s"\'<>]+)?', caseSensitive: false).allMatches(html).map((m) => m.group(0)!.replaceAll('&amp;', '&'));
    for (final link in media) links.add({'url': link, 'quality': link.contains('hls') || link.endsWith('.m3u8') ? 'Auto' : 'Direct', 'name': 'EgyDead', 'label': 'EgyDead'});
    final embeds = RegExp(r'''(?:data-link|iframe[^>]+src|href)=["']([^"']+)["']''', caseSensitive: false).allMatches(html).map((m) => Uri.parse(watchUrl).resolve(m.group(1)!).toString());
    for (final link in embeds) {
      if (link.contains('javascript:') || links.any((e) => e['url'] == link)) continue;
      if (RegExp(r'(m3u8|mp4|player|embed|stream|vid)', caseSensitive: false).hasMatch(link)) links.add({'url': link, 'quality': 'Auto', 'name': 'EgyDead', 'label': 'Server'});
    }
    if (links.isEmpty) return null;
    return {'stream_url': links.first['url'], 'direct_stream_urls': links, 'headers': headers};
  }
}

class HtmlMeta {
  static String? meta(String html, String property) => RegExp('<meta[^>]+(?:property|name)=["\\\']$property["\\\'][^>]+content=["\\\']([^"\\\']+)', caseSensitive: false).firstMatch(html)?.group(1);
  static String? first(String html, List<String> names) {
    for (final name in names) {
      final value = meta(html, name);
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }
  static String? firstBlock(String html, List<String> classes) {
    for (final className in classes) {
      final match = RegExp('<[^>]+class=["\\\'][^"\\\']*$className[^"\\\']*["\\\'][^>]*>(.*?)</', caseSensitive: false, dotAll: true).firstMatch(html);
      if (match != null) return match.group(1);
    }
    return null;
  }
}
