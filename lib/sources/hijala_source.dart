import 'html_client.dart';
import 'source_base.dart';

class HijalaSource extends ContentSource {
  static const String _base = 'https://hijala.com';

  @override
  String get id => 'hijala';
  @override
  String get name => 'Hijala';
  @override
  String get kind => 'manga';
  @override
  List<String> get hosts => ['hijala.com', 'www.hijala.com'];

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final html = await HtmlClient.getHtml('$_base/?s=${Uri.encodeQueryComponent(query)}');
    return _parseSeries(html);
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final url = page <= 1 ? '$_base/' : '$_base/page/$page/';
    return _parseSeries(await HtmlClient.getHtml(url));
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final html = await HtmlClient.getHtml(url);
    final title = HtmlParse.stripTags(HtmlParse.meta(html, 'og:title') ?? HtmlParse.firstMatch(html, [
          RegExp("""<h1[^>]*>([\\s\\S]*?)</h1>""", caseSensitive: false),
          RegExp("""<title[^>]*>([\\s\\S]*?)</title>""", caseSensitive: false),
        ]) ?? url.split('/').where((part) => part.isNotEmpty).last);
    final description = HtmlParse.stripTags(HtmlParse.meta(html, 'og:description') ?? '');
    final genres = HtmlParse.all(html, RegExp("""href=[\"'][^\"']*/genres/[^\"']+[\"'][^>]*>([^<]+)<""", caseSensitive: false));
    final chapters = await _collectChapters(url, html);
    return {
      ...item(
        title: title,
        url: url,
        image: _coverImage(html, url),
        type: _typeFromHtml(html),
        genres: genres.toSet().toList(),
        description: description,
        rating: HtmlParse.firstMatch(html, [RegExp(r'([\d.]+)\s*/\s*10')]) ?? '',
      ),
      'synopsis': description,
      'chapters': chapters,
    };
  }

  @override
  Future<Map<String, dynamic>> chapterImages(String url) async {
    final html = await HtmlClient.getHtml(url);
    final images = <Map<String, dynamic>>[];
    final seen = <String>{};
    final pattern = RegExp("""<img[^>]+(?:data-src|data-lazy-src|data-original|src)=[\"']([^\"']+)[\"'][^>]*>""", caseSensitive: false);
    for (final match in pattern.allMatches(html)) {
      final src = HtmlParse.absUrl(url, match.group(1)!);
      if (src.isEmpty || !seen.add(src) || _isNoiseImage(src.toLowerCase())) continue;
      images.add({'url': src, 'alt': ''});
    }
    for (final image in RegExp(r'!\[[^\]]*\]\(([^)\s]+)', caseSensitive: false).allMatches(html)) {
      final src = HtmlParse.absUrl(url, image.group(1)!);
      if (src.isEmpty || !seen.add(src) || _isNoiseImage(src.toLowerCase())) continue;
      images.add({'url': src, 'alt': ''});
    }
    return {
      'title': 'الفصل ${SourceUtils.chapterNumber(url) ?? ''}'.trim(),
      'images': images,
      'chapter_number': SourceUtils.chapterNumber(url) ?? 0,
    };
  }

  List<Map<String, dynamic>> _parseSeries(String html) {
    final items = <Map<String, dynamic>>[];
    final seen = <String>{};
    final pattern = RegExp("""<a[^>]+href=[\"'](https?://(?:www\\.)?hijala\\.com/[^\"']+)[\"'][^>]*>[\\s\\S]{0,1200}?</a>""", caseSensitive: false);
    for (final match in pattern.allMatches(html)) {
      final url = match.group(1)!.split('#').first;
      if (!seen.add(url) || _isUtilityUrl(url)) continue;
      final block = match.group(0)!;
      final title = HtmlParse.stripTags(HtmlParse.firstMatch(block, [
            RegExp("""<h[1-4][^>]*>([\\s\\S]*?)</h[1-4]>""", caseSensitive: false),
            RegExp("""<img[^>]+(?:alt|title)=[\"']([^\"']+)""", caseSensitive: false),
          ]) ?? url.split('/').where((part) => part.isNotEmpty).last.replaceAll('-', ' '));
      if (title.isEmpty || _isUtilityTitle(title)) continue;
      items.add(item(title: title, url: url, image: _coverImage(block, url), type: 'comic'));
    }
    for (final link in HtmlParse.markdownLinks(html)) {
      final url = link['url'] ?? '';
      final title = HtmlParse.stripTags(link['title'] ?? '');
      if (!url.contains('hijala.com') || !seen.add(url) || _isUtilityUrl(url) || title.isEmpty) continue;
      items.add(item(title: title, url: url, image: _nearbyCover(html, url), type: 'comic'));
    }
    return items;
  }

  Future<List<Map<String, dynamic>>> _collectChapters(String seriesUrl, String html) async {
    final chapters = <String, Map<String, dynamic>>{};
    final slug = Uri.parse(seriesUrl).pathSegments.where((part) => part.isNotEmpty).last;
    final pages = <String>[seriesUrl];
    final visited = <String>{};
    for (var i = 0; i < 12 && pages.isNotEmpty; i++) {
      final page = pages.removeAt(0);
      if (!visited.add(page)) continue;
      if (page != seriesUrl) {
        try { html = await HtmlClient.getHtml(page); } catch (_) { continue; }
      }
      final pattern = RegExp("""href=[\"']([^\"']+)[\"']""", caseSensitive: false);
      for (final match in pattern.allMatches(html)) {
        final chapterUrl = HtmlParse.absUrl(seriesUrl, match.group(1)!);
        if (!chapterUrl.contains('hijala.com') || !chapterUrl.contains(slug)) continue;
        final number = _chapterNumber('${match.group(1)} ${_nearby(html, match.start)}');
        if (number == null || chapterUrl == seriesUrl) continue;
        chapters[chapterUrl] = {'title': 'الفصل ${_formatNumber(number)}', 'url': chapterUrl, 'number': number};
      }
      for (final link in HtmlParse.markdownLinks(html)) {
        final raw = link['url'] ?? '';
        if (!raw.contains('hijala.com') || !raw.contains(slug)) continue;
        final chapterUrl = HtmlParse.absUrl(seriesUrl, raw);
        final number = _chapterNumber('$raw ${link['title'] ?? ''}');
        if (number == null || chapterUrl == seriesUrl) continue;
        chapters[chapterUrl] = {'title': 'الفصل ${_formatNumber(number)}', 'url': chapterUrl, 'number': number};
      }
      final pagePattern = RegExp("""href=[\"']([^\"']*(?:/page/\\d+|[?&](?:paged|page)=\\d+)[^\"']*)[\"']""", caseSensitive: false);
      for (final match in pagePattern.allMatches(html)) {
        final next = HtmlParse.absUrl(seriesUrl, match.group(1)!);
        if (next.contains('hijala.com') && !visited.contains(next)) pages.add(next);
      }
    }
    final result = chapters.values.toList();
    result.sort((a, b) => (b['number'] as double).compareTo(a['number'] as double));
    return result;
  }

  String _coverImage(String html, String baseUrl) {
    final candidates = <String?>[
      HtmlParse.meta(html, 'og:image'),
      HtmlParse.firstMatch(html, [RegExp(r'''<img[^>]+data-src=["']([^"']+)["']''', caseSensitive: false)]),
      HtmlParse.firstMatch(html, [RegExp(r'''<img[^>]+data-lazy-src=["']([^"']+)["']''', caseSensitive: false)]),
      HtmlParse.firstMatch(html, [RegExp(r'''<img[^>]+data-original=["']([^"']+)["']''', caseSensitive: false)]),
      HtmlParse.firstMatch(html, [RegExp(r'''<img[^>]+src=["'](https?://[^"']+)["']''', caseSensitive: false)]),
      HtmlParse.firstMatch(html, [RegExp(r'!\[[^\]]*\]\((https?://[^)\s]+)', caseSensitive: false)]),
    ];
    for (final raw in candidates) {
      if (raw == null || raw.isEmpty || raw.startsWith('data:') || _isNoiseImage(raw.toLowerCase())) continue;
      return HtmlParse.absUrl(baseUrl, raw);
    }
    return '';
  }

  String _nearbyCover(String html, String url) {
    final index = html.indexOf(url);
    if (index < 0) return _coverImage(html, url);
    final start = index > 900 ? index - 900 : 0;
    final end = index + 900 < html.length ? index + 900 : html.length;
    return _coverImage(html.substring(start, end), url);
  }

  double? _chapterNumber(String value) {
    final match = RegExp(r'(?:الفصل|chapter|ch)[^\d]{0,8}(\d+(?:\.\d+)?)', caseSensitive: false).firstMatch(value) ?? RegExp(r'(?:/|[-_ ])(\d+(?:\.\d+)?)(?:/|[-_ .]|$)').firstMatch(value);
    return match == null ? null : double.tryParse(match.group(1)!);
  }

  String _nearby(String html, int offset) => html.substring(offset, offset + 500 < html.length ? offset + 500 : html.length);
  String _formatNumber(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toString();
  String _typeFromHtml(String html) => html.toLowerCase().contains('manhua') ? 'Manhua' : html.toLowerCase().contains('manga') ? 'Manga' : 'Manhwa';
  bool _isUtilityUrl(String url) => RegExp(r'/(genres|page|player|tag|author|wp-|search|call-us|privacy|terms)/', caseSensitive: false).hasMatch(url);
  bool _isUtilityTitle(String title) => RegExp(r'^(الرئيسية|بحث|الأعمال الشائعة|player)$', caseSensitive: false).hasMatch(title.trim());
  bool _isNoiseImage(String url) => url.contains('logo') || url.contains('avatar') || url.contains('icon') || url.contains('favicon');
}
