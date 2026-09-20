import 'html_client.dart';
import 'source_base.dart';

/// Defensive HTML adapter for server-rendered catalog sites.
class WebCatalogSource extends ContentSource {
  final String sourceId;
  final String sourceName;
  final String sourceKind;
  final List<String> sourceHosts;
  final String baseUrl;
  final String? searchParam;

  WebCatalogSource({
    required this.sourceId,
    required this.sourceName,
    required this.sourceKind,
    required this.sourceHosts,
    required this.baseUrl,
    this.searchParam = 's',
  });

  @override String get id => sourceId;
  @override String get name => sourceName;
  @override String get kind => sourceKind;
  @override List<String> get hosts => sourceHosts;

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    return _catalog(await HtmlClient.getHtml(page <= 1 ? baseUrl : _pageUrl(page)));
  }

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return latest();
    final uri = Uri.parse(baseUrl);
    final params = Map<String, String>.from(uri.queryParameters);
    if (searchParam != null) params[searchParam!] = value;
    return _catalog(await HtmlClient.getHtml(uri.replace(queryParameters: params).toString()));
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final html = await HtmlClient.getHtml(url);
    final title = HtmlParse.meta(html, 'og:title') ??
        HtmlParse.firstMatch(html, [
          RegExp(r'<h1[^>]*>(.*?)</h1>', caseSensitive: false, dotAll: true),
          RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false, dotAll: true),
        ]) ?? sourceName;
    final description = HtmlParse.meta(html, 'og:description') ?? '';
    return {
      ...item(
        title: SourceUtils.cleanTitle(title),
        url: url,
        image: HtmlParse.meta(html, 'og:image') ?? '',
        type: sourceKind == 'anime' ? 'anime' : 'فيلم',
        description: SourceUtils.cleanTitle(description),
      ),
      'episodes': _episodeLinks(html, url),
      'videos': <Map<String, dynamic>>[],
    };
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async {
    final html = await HtmlClient.getHtml(url);
    final candidates = <String>{
      ...SourceUtils.extractMediaUrls(html, url),
      ..._embedLinks(html, url),
    };
    final playable = candidates.where(_looksPlayable).toList(growable: false);
    final links = playable.isEmpty ? [url] : playable;
    return {
      'stream_url': links.first,
      'direct_stream_urls': links.map((link) => {
        'url': link, 'label': sourceName, 'name': sourceName, 'type': 'embed',
      }).toList(),
      'title': sourceName,
    };
  }

  List<Map<String, dynamic>> _catalog(String html) {
    final results = <Map<String, dynamic>>[];
    final seen = <String>{};
    final pattern = RegExp(
      r'''<a\b([^>]*href=["'][^"']+["'][^>]*)>(.*?)</a>''',
      caseSensitive: false,
      dotAll: true,
    );
    for (final match in pattern.allMatches(html)) {
      final attrs = match.group(1) ?? '';
      final body = match.group(2) ?? '';
      final href = HtmlParse.firstMatch(attrs, [RegExp(r'''href=["']([^"']+)''', caseSensitive: false)]);
      if (href == null || !_isContentLink(href)) continue;
      final title = _title(body, attrs);
      if (title.length < 2 || _isNavigation(title)) continue;
      final resolved = HtmlParse.absUrl(baseUrl, href);
      if (!seen.add(resolved)) continue;
      final image = HtmlParse.firstMatch(body, [
        RegExp(r'''(?:data-src|data-lazy-src|src)=["']([^"']+)''', caseSensitive: false),
      ]) ?? '';
      results.add(item(
        title: title,
        url: resolved,
        image: HtmlParse.absUrl(baseUrl, image),
        type: sourceKind == 'anime' ? 'anime' : 'فيلم',
      ));
      if (results.length >= 60) break;
    }
    return results;
  }

  List<Map<String, dynamic>> _episodeLinks(String html, String pageUrl) {
    final results = <Map<String, dynamic>>[];
    final seen = <String>{};
    final pattern = RegExp(
      r'''<a\b([^>]*href=["'][^"']+["'][^>]*)>(.*?)</a>''',
      caseSensitive: false,
      dotAll: true,
    );
    for (final match in pattern.allMatches(html)) {
      final attrs = match.group(1) ?? '';
      final text = SourceUtils.cleanTitle(match.group(2) ?? '');
      if (!RegExp(r'(الحلقة|حلقة|episode|ep\.?\s*\d+|مشاهدة|watch)', caseSensitive: false).hasMatch(text)) continue;
      final href = HtmlParse.firstMatch(attrs, [RegExp(r'''href=["']([^"']+)''', caseSensitive: false)]);
      if (href == null) continue;
      final resolved = HtmlParse.absUrl(pageUrl, href);
      if (!seen.add(resolved)) continue;
      results.add({
        'title': text.isEmpty ? 'حلقة' : text,
        'url': resolved,
        'number': SourceUtils.episodeNumber(text) ?? results.length + 1,
      });
      if (results.length >= 100) break;
    }
    return results;
  }

  List<String> _embedLinks(String html, String pageUrl) {
    final values = <String>{};
    for (final match in RegExp(
      r'''(?:iframe|embed|data-embed|data-player)[^>]+(?:src|data-src)=["']([^"']+)''',
      caseSensitive: false,
    ).allMatches(html)) {
      values.add(HtmlParse.absUrl(pageUrl, match.group(1)!));
    }
    return values.toList();
  }

  String _pageUrl(int page) => '$baseUrl${baseUrl.contains('?') ? '&' : '?'}page=$page';

  bool _isContentLink(String url) {
    final full = HtmlParse.absUrl(baseUrl, url);
    final host = HtmlParse.hostOf(full);
    if (host.isEmpty || !sourceHosts.any((h) => host == h || host.endsWith('.$h'))) return false;
    final path = Uri.tryParse(full)?.path.toLowerCase() ?? '';
    return (path.length > 2 && !path.endsWith('/')) || path.split('/').length > 2;
  }

  bool _looksPlayable(String url) {
    final value = url.toLowerCase();
    return RegExp(r'\.(mp4|m3u8|webm|mpd)(?:[?#].*)?$').hasMatch(value) ||
        RegExp(r'(iframe|embed|player|vid|stream|watch)', caseSensitive: false).hasMatch(value);
  }

  String _title(String body, String attrs) {
    final text = SourceUtils.cleanTitle(body);
    if (text.isNotEmpty) return text;
    return HtmlParse.firstMatch(attrs, [
      RegExp(r'''(?:title|aria-label)=["']([^"']+)''', caseSensitive: false),
    ]) ?? '';
  }

  bool _isNavigation(String value) => RegExp(
    r'^(home|search|menu|login|تسجيل|الرئيسية|بحث|المزيد)$',
    caseSensitive: false,
  ).hasMatch(value.trim());
}

class AnimeWitcherSource extends WebCatalogSource {
  AnimeWitcherSource() : super(
    sourceId: 'anime_witcher', sourceName: 'Anime Witcher', sourceKind: 'anime',
    sourceHosts: const ['animewitcher.com'], baseUrl: 'https://www.animewitcher.com/', searchParam: 'q',
  );
}

class Anime3rbSource extends WebCatalogSource {
  Anime3rbSource() : super(
    sourceId: 'anime3rb', sourceName: 'Anime3rb', sourceKind: 'anime',
    sourceHosts: const ['anime3rb.com'], baseUrl: 'https://anime3rb.com/', searchParam: 's',
  );
}

class WecimaSource extends WebCatalogSource {
  WecimaSource() : super(
    sourceId: 'wecima', sourceName: 'Wecima', sourceKind: 'movie',
    sourceHosts: const ['wecima.show', 'wecima.tube', 'wecima.video', 'wecima.mov'],
    baseUrl: 'https://wecima.show/', searchParam: 's',
  );
}

class KormozSource extends WebCatalogSource {
  KormozSource() : super(
    sourceId: 'kormoz', sourceName: 'كُرْمُزِي (Kormoz)', sourceKind: 'movie',
    sourceHosts: const ['kormoz.com', 'kormozi.com', 'kormozy.com'],
    baseUrl: 'https://kormoz.com/', searchParam: 's',
  );
}
