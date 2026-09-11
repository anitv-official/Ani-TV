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
    final html = await HtmlClient.getHtml(
      '$_base/?s=${Uri.encodeQueryComponent(query)}',
    );
    return _parseSeries(html);
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final url = page <= 1 ? _base : '$_base/page/$page/';
    return _parseSeries(await HtmlClient.getHtml(url));
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final html = await HtmlClient.getHtml(url);
    final title = HtmlParse.stripTags(
      HtmlParse.meta(html, 'og:title') ??
          HtmlParse.firstMatch(html, [
            RegExp(r'<h1[^>]*>([\s\S]*?)</h1>', caseSensitive: false),
            RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false),
          ]) ??
          url.split('/').where((part) => part.isNotEmpty).last,
    );
    final image = _coverImage(html, url);
    final description = HtmlParse.stripTags(
      HtmlParse.meta(html, 'og:description') ??
          HtmlParse.firstMatch(html, [
            RegExp(r'class=["\'][^"\']*(?:summary__content|description|synopsis)[^"\']*["\'][^>]*>([\s\S]*?)</', caseSensitive: false),
            RegExp(r'class=["\'][^"\']*entry-content[^"\']*["\'][^>]*>([\s\S]*?)</', caseSensitive: false),
          ]) ??
          '',
    );
    final genres = HtmlParse.all(
      html,
      RegExp(r'href=["\'][^"\']*/genres/[^"\']+["\'][^>]*>([^<]+)<', caseSensitive: false),
    );
    final chapters = await _collectChapters(url, html);
    return {
      ...item(
        title: title,
        url: url,
        image: image,
        type: _typeFromHtml(html),
        genres: genres.toSet().toList(),
        description: description,
        rating: HtmlParse.firstMatch(html, [
              RegExp(r'class=["\'][^"\']*(?:numscore|rating)[^"\']*["\'][^>]*>([\d.]+)', caseSensitive: false),
              RegExp(r'([\d.]+)\s*/\s*10'),
            ]) ??
            '',
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
    final pattern = RegExp(
      r'<img[^>]+(?:data-src|data-lazy-src|data-original|src)=["\']([^"\']+)["\'][^>]*>',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(html)) {
      final src = HtmlParse.absUrl(url, match.group(1)!);
      final lower = src.toLowerCase();
      if (src.isEmpty || !seen.add(src) || _isNoiseImage(lower)) continue;
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
    final cardPattern = RegExp(
      r'<(?:div|article)[^>]+class=["\'][^"\']*(?:bsx|listupd|page-item-detail|item-summary)[^"\']*["\'][\s\S]{0,2400}?</(?:div|article)>',
      caseSensitive: false,
    );
    final blocks = cardPattern.allMatches(html).map((m) => m.group(0)!).toList();
    final haystack = blocks.isEmpty ? html : blocks.join('\n');
    final linkPattern = RegExp(
      r'<a[^>]+href=["\'](https?://(?:www\.)?hijala\.com/(?!genres/|page/|player/|tag/|author/|wp-|search/)[^"\']+)["\'][^>]*>([\s\S]*?)</a>',
      caseSensitive: false,
    );
    for (final match in linkPattern.allMatches(haystack)) {
      final url = match.group(1)!.split('#').first;
      if (!seen.add(url) || _isUtilityUrl(url)) continue;
      final blockStart = match.start > 700 ? match.start - 700 : 0;
      final blockEnd = match.end + 1000 < haystack.length ? match.end + 1000 : haystack.length;
      final nearby = haystack.substring(blockStart, blockEnd);
      final title = HtmlParse.stripTags(
        match.group(2) ??
            HtmlParse.firstMatch(nearby, [
              RegExp(r'<h[1-4][^>]*>([\s\S]*?)</h[1-4]>', caseSensitive: false),
              RegExp(r'<img[^>]+(?:alt|title)=["\']([^"\']+)', caseSensitive: false),
            ]) ??
            url.split('/').where((p) => p.isNotEmpty).last.replaceAll('-', ' '),
      );
      if (title.isEmpty || _isUtilityTitle(title)) continue;
      items.add(item(title: title, url: url, image: _coverImage(nearby, url), type: 'comic'));
    }
    return items;
  }

  Future<List<Map<String, dynamic>>> _collectChapters(String seriesUrl, String firstHtml) async {
    final pages = <String>[seriesUrl];
    final visited = <String>{};
    final chapters = <String, Map<String, dynamic>>{};
    var html = firstHtml;
    for (var pass = 0; pass < 12 && pages.isNotEmpty; pass++) {
      final page = pages.removeAt(0);
      if (visited.contains(page)) continue;
      visited.add(page);
      if (page != seriesUrl) {
        try { html = await HtmlClient.getHtml(page); } catch (_) { continue; }
      }
      for (final chapter in _parseChapters(html, seriesUrl)) {
        chapters[chapter['url'].toString()] = chapter;
      }
      for (final match in RegExp("""href=["']([^"']*(?:/page/\\d+|[?&](?:paged|page)=\\d+)[^"']*)["']""", caseSensitive: false).allMatches(html)) {
        final next = HtmlParse.absUrl(seriesUrl, match.group(1)!);
        if (!visited.contains(next) && next.contains('hijala.com')) pages.add(next);
      }
    }
    final result = chapters.values.toList();
    result.sort((a, b) => (b['number'] as double).compareTo(a['number'] as double));
    return result;
  }

  List<Map<String, dynamic>> _parseChapters(String html, String seriesUrl) {
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};
    final slug = Uri.parse(seriesUrl).pathSegments.where((s) => s.isNotEmpty).last;
    final pattern = RegExp(
      """href=["']([^"']*hijala\\.com/""" + RegExp.escape(slug) + """(?:/|[-_])[^"']*?)(?:["'])""",
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(html)) {
      final url = HtmlParse.absUrl(seriesUrl, match.group(1)!);
      final number = _chapterNumber('${match.group(1)} ${_nearbyText(html, match.start)}');
      if (number == null || !seen.add(url) || url == seriesUrl) continue;
      result.add({'title': 'الفصل ${_formatNumber(number)}', 'url': url, 'number': number});
    }
    return result;
  }

  String _coverImage(String html, String baseUrl) {
    final raw = HtmlParse.meta(html, 'og:image') ?? HtmlParse.firstMatch(html, [
      RegExp("""<img[^>]+(?:data-src|data-lazy-src|src)=["']([^"']+)""", caseSensitive: false),
      RegExp("""background-image\\s*:\\s*url\\((["']?)([^)"']+)\\1\\)""", caseSensitive: false),
    ]) ?? '';
    final value = raw.trim();
    return value.isEmpty ? '' : HtmlParse.absUrl(baseUrl, value);
  }

  String _typeFromHtml(String html) {
    final lower = html.toLowerCase();
    if (lower.contains('manhua')) return 'Manhua';
    if (lower.contains('manga')) return 'Manga';
    return 'Manhwa';
  }

  double? _chapterNumber(String value) {
    final matches = RegExp(r'(?:الفصل|chapter|ch)[^\d]{0,8}(\d+(?:\.\d+)?)', caseSensitive: false).allMatches(value).toList();
    if (matches.isNotEmpty) return double.tryParse(matches.last.group(1)!);
    final numbers = RegExp(r'(?:/|[-_ ])(\d+(?:\.\d+)?)(?:/|[-_ .]|$)').allMatches(value).toList();
    return numbers.isEmpty ? null : double.tryParse(numbers.last.group(1)!);
  }

  String _nearbyText(String html, int offset) => html.substring(offset, offset + 500 < html.length ? offset + 500 : html.length);
  String _formatNumber(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toString();
  bool _isUtilityUrl(String url) => RegExp(r'/(genres|page|player|tag|author|wp-|search|call-us|privacy|terms)/', caseSensitive: false).hasMatch(url);
  bool _isUtilityTitle(String title) => RegExp(r'^(الرئيسية|بحث|الأعمال الشائعة|player)$', caseSensitive: false).hasMatch(title.trim());
  bool _isNoiseImage(String url) => url.contains('logo') || url.contains('avatar') || url.contains('icon') || url.contains('favicon');
}
