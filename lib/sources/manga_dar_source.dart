import 'html_client.dart';
import 'source_base.dart';

/// HTML adapter for the Manga Dar WordPress-style website.
class MangaDarSource extends ContentSource {
  static const _site = 'https://mangadar.com';

  @override
  String get id => 'manga_dar';

  @override
  String get name => 'Manga Dar';

  @override
  String get kind => 'manga';

  @override
  List<String> get hosts => const ['mangadar.com'];

  @override
  bool handles(String url) => url.startsWith('mangadar://') || super.handles(url);

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return const [];
    final html = await HtmlClient.getHtml('$_site/?s=${Uri.encodeQueryComponent(value)}');
    return _parseCards(html, '$_site/');
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final url = page <= 1 ? '$_site/manga/' : '$_site/manga/page/$page/';
    return _parseCards(await HtmlClient.getHtml(url), url);
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    var pageUrl = _mangaUrl(url);
    var html = await HtmlClient.getHtml(pageUrl);
    final canonical = _canonicalMangaUrl(html, pageUrl);
    if (canonical.isNotEmpty && canonical != pageUrl) {
      pageUrl = canonical;
      html = await HtmlClient.getHtml(pageUrl);
    }
    final slug = _slug(pageUrl);
    final chapters = _chapters(html, pageUrl, slug);
    final description = HtmlParse.stripTags(HtmlParse.meta(html, 'og:description') ?? '');
    final result = item(
      title: _title(html, slug.replaceAll('-', ' ')),
      url: pageUrl,
      image: _image(html, pageUrl),
      type: _first(html, [r'مانغا', r'مانهوا', r'مانها', r'manhwa', r'manhua', r'manga']) ?? 'comic',
      genres: _genres(html),
      description: description,
      rating: _first(html, [r'(?:rating|التقييم)[^\d]{0,30}(\d+(?:\.\d+)?)']) ?? '',
    );
    result.addAll({'manga_id': slug, 'description': description, 'chapters': chapters, 'total_chapters': chapters.length, 'status': _first(html, [r'مستمر', r'مكتمل', r'متوقف', r'ongoing', r'completed']) ?? ''});
    return result;
  }

  @override
  Future<Map<String, dynamic>?> chapterImages(String url) async {
    final pageUrl = _chapterUrl(url);
    final html = await HtmlClient.getHtml(pageUrl);
    final images = <String>[];
    final seen = <String>{};
    for (final match in RegExp(r'<img\b[^>]*>', caseSensitive: false).allMatches(html)) {
      final tag = match.group(0) ?? '';
      final raw = _attribute(tag, ['data-src', 'data-lazy-src', 'data-original', 'src']);
      final image = raw.isEmpty ? '' : HtmlParse.absUrl(pageUrl, raw);
      if (_isPageImage(image) && seen.add(image)) images.add(image);
    }
    if (images.isEmpty) return null;
    return {'title': _title(html, 'الفصل'), 'images': images.map((url) => {'url': url}).toList(), 'pages': images, 'url': url};
  }

  List<Map<String, dynamic>> _parseCards(String html, String base) {
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};
    final pattern = RegExp(r'''<a\b[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)</a>''', caseSensitive: false);
    for (final match in pattern.allMatches(html)) {
      final href = HtmlParse.absUrl(base, match.group(1) ?? '');
      final title = HtmlParse.stripTags(match.group(2) ?? '');
      if (!_isMangaUrl(href) || title.length < 2 || _isNoise(title)) continue;
      final page = _mangaUrl(href);
      if (!seen.add(page)) continue;
      final start = match.start > 800 ? match.start - 800 : 0;
      final context = html.substring(start, match.end);
      result.add(item(title: title, url: page, image: _image(context, base), type: _first(context, [r'مانغا', r'مانهوا', r'مانها', r'manhwa', r'manhua', r'manga']) ?? 'comic', rating: _first(context, [r'(?:rating|التقييم)[^\d]{0,20}(\d+(?:\.\d+)?)']) ?? ''));
    }
    return result.take(60).toList();
  }

  List<Map<String, dynamic>> _chapters(String html, String base, String slug) {
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};
    void addChapter(String rawUrl, String rawTitle) {
      final href = HtmlParse.absUrl(base, rawUrl);
      final text = HtmlParse.stripTags(rawTitle);
      if (!_isChapterUrl(href, slug) || _number('$text $href') == null) return;
      final chapter = _chapterUrl(href);
      if (!seen.add(chapter)) return;
      final number = _number('$text $chapter')!;
      result.add({'id': chapter, 'chapter_id': chapter, 'title': text.isEmpty ? 'الفصل $number' : text, 'number': number, 'chapter_number': number, 'url': chapter, 'chapter_url': chapter});
    }
    final pattern = RegExp(r'''<a\b[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)</a>''', caseSensitive: false);
    for (final match in pattern.allMatches(html)) {
      addChapter(match.group(1) ?? '', match.group(2) ?? '');
    }
    for (final link in HtmlParse.markdownLinks(html)) {
      addChapter(link['url'] ?? '', link['title'] ?? '');
    }
    final chapterPattern = RegExp(
      r'''(?:https?://(?:www\.)?mangadar\.com)?/manga/''' +
          RegExp.escape(slug) +
          r'''/([0-9]+(?:\.[0-9]+)?)/?''',
      caseSensitive: false,
    );
    for (final match in chapterPattern.allMatches(html)) {
      final raw = match.group(0) ?? '';
      final number = match.group(1) ?? '';
      addChapter(raw, 'الفصل $number');
    }
    result.sort((a, b) => (b['number'] as num).compareTo(a['number'] as num));
    return result;
  }

  String _mangaUrl(String url) {
    if (url.startsWith('mangadar://manga/')) return '$_site/manga/${url.substring(17).replaceAll(RegExp(r'/+$'), '')}/';
    final match = RegExp(r'(https?://(?:www\.)?mangadar\.com/manga/[^/?#]+)', caseSensitive: false).firstMatch(url);
    return match == null ? url : '${match.group(1)}/';
  }

  String _chapterUrl(String url) {
    if (url.startsWith('mangadar://chapter/')) return url.substring(19);
    try {
      final uri = Uri.parse(url);
      final parts = uri.pathSegments;
      final mangaIndex = parts.indexOf('manga');
      if (mangaIndex >= 0 && parts.length > mangaIndex + 2) {
        final normalizedPath = '/${parts.join('/')}/';
        return uri.replace(path: normalizedPath).toString();
      }
    } catch (_) {}
    return url;
  }

  String _slug(String url) => RegExp(r'/manga/([^/?#]+)', caseSensitive: false).firstMatch(url)?.group(1) ?? '';

  String _canonicalMangaUrl(String html, String fallback) {
    final raw = HtmlParse.firstMatch(html, [
      RegExp(r'''"url"\s*:\s*"(https?:\\/\\/mangadar\.com\\/manga\\/[^"\\]+)''', caseSensitive: false),
      RegExp(r'''<link[^>]+rel=["']canonical["'][^>]+href=["']([^"']+)''', caseSensitive: false),
    ]);
    if (raw == null || raw.isEmpty) return fallback;
    final decoded = raw.replaceAll(r'\/', '/');
    return _isMangaUrl(decoded) ? _mangaUrl(decoded) : fallback;
  }

  bool _isMangaUrl(String url) => RegExp(r'https?://(?:www\.)?mangadar\.com/manga/[^/]+/?$', caseSensitive: false).hasMatch(url);

  bool _isChapterUrl(String url, String slug) {
    try {
      final uri = Uri.parse(url);
      if (!{'http', 'https'}.contains(uri.scheme) || HtmlParse.hostOf(url) != 'mangadar.com') return false;
      final parts = uri.pathSegments;
      final mangaIndex = parts.indexOf('manga');
      if (mangaIndex < 0 || mangaIndex + 1 >= parts.length || parts[mangaIndex + 1].toLowerCase() != slug.toLowerCase()) return false;
      return parts.length > mangaIndex + 2 || uri.queryParameters.keys.any((key) => key.toLowerCase().contains('chapter'));
    } catch (_) {
      return false;
    }
  }

  bool _isNoise(String text) => RegExp(r'^(الفصل|chapter|صفحة|page|قراءة|مشاركة|تحميل|التالي|السابق)\b', caseSensitive: false).hasMatch(text);

  String _title(String html, String fallback) {
    final raw = HtmlParse.meta(html, 'og:title') ?? HtmlParse.firstMatch(html, [RegExp(r'<h1[^>]*>([\s\S]*?)</h1>', caseSensitive: false), RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false)]) ?? fallback;
    return HtmlParse.stripTags(raw).replaceFirst(RegExp(r'\s*[-|].*$'), '').trim();
  }

  String _image(String html, String base) {
    final raw = HtmlParse.meta(html, 'og:image') ?? HtmlParse.firstMatch(html, [RegExp(r'''<img\b[^>]*(?:data-src|src)=["']([^"']+)''', caseSensitive: false)]) ?? '';
    return raw.isEmpty ? '' : HtmlParse.absUrl(base, raw);
  }

  List<String> _genres(String html) => HtmlParse.all(html, RegExp(r'(?:genre|التصنيف)[^<]{0,100}<[^>]*>([^<]+)<', caseSensitive: false)).map(HtmlParse.stripTags).toSet().toList();

  String? _first(String html, List<String> expressions) {
    for (final expression in expressions) {
      final match = RegExp(expression, caseSensitive: false).firstMatch(html);
      if (match != null) return HtmlParse.stripTags(match.groupCount > 0 ? (match.group(1) ?? match.group(0)!) : match.group(0)!);
    }
    return null;
  }

  String _attribute(String tag, List<String> names) {
    for (final name in names) {
      final match = RegExp('\\b${RegExp.escape(name)}=["\\\']([^"\\\']+)', caseSensitive: false).firstMatch(tag);
      if (match != null) return HtmlParse.decode(match.group(1)!);
    }
    return '';
  }

  bool _isPageImage(String url) => RegExp(r'\.(?:jpe?g|png|webp|gif)(?:[?#].*)?$', caseSensitive: false).hasMatch(url) && !RegExp(r'(logo|icon|avatar|emoji|banner|favicon)', caseSensitive: false).hasMatch(url);

  double? _number(String value) {
    final match = RegExp(r'(?:الفصل|chapter|ch)[^\d]*(\d+(?:\.\d+)?)', caseSensitive: false).firstMatch(value) ?? RegExp(r'/([0-9]+(?:\.[0-9]+)?)/?$', caseSensitive: false).firstMatch(value);
    return match == null ? null : double.tryParse(match.group(1)!);
  }
}
