import 'html_client.dart';
import 'source_base.dart';

class OlympusSource extends ContentSource {
  static const String _base = 'https://olympustaff.com';

  @override
  String get id => 'teamx';

  @override
  String get name => 'Team X Manga';

  @override
  String get kind => 'manga';

  @override
  List<String> get hosts => ['olympustaff.com', 'teamxmanga.store'];

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final direct = await HtmlClient.getHtml(
      '$_base/search?keyword=${Uri.encodeQueryComponent(query)}',
    );
    final searched = _parseSeriesList(direct);
    // Keep a catalogue fallback for installations where the search endpoint
    // returns an empty page or changes its markup.
    final all = searched.isNotEmpty
        ? searched
        : _parseSeriesList(await HtmlClient.getHtml('$_base/series'));
    final slug = HtmlParse.slugify(query);
    final q = query.toLowerCase().trim();
    final filtered = searched.isNotEmpty
        ? all
        : all.where((entry) {
            final title = (entry['title'] ?? '').toString().toLowerCase();
            final url = (entry['url'] ?? '').toString().toLowerCase();
            return title.contains(q) || url.contains(slug);
          }).toList();
    final merged = [...filtered];
    final seen = <String>{};
    return merged.where((e) => seen.add((e['url'] ?? '').toString())).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final url = page <= 1 ? '$_base/series' : '$_base/series?page=$page';
    final html = await HtmlClient.getHtml(url);
    return _parseSeriesList(html);
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final html = await HtmlClient.getHtml(url);
    final title = HtmlParse.stripTags(
      HtmlParse.firstMatch(html, [
            RegExp(r'######\s*(.+)'),
            RegExp(r'^#\s*(.+)$', multiLine: true),
            RegExp(r'<h1[^>]*>([\s\S]*?)</h1>', caseSensitive: false),
          ]) ??
          HtmlParse.meta(html, 'og:title') ??
          'بدون عنوان',
    );
    final image = HtmlParse.firstMatch(html, [
          RegExp(r'(https://olympustaff\.com/images/manga/[^\s)"\]]+)'),
          RegExp(r'<img[^>]+src="([^"]+)"', caseSensitive: false),
        ]) ??
        HtmlParse.meta(html, 'og:image') ??
        '';
    final description = HtmlParse.stripTags(
      HtmlParse.meta(html, 'og:description') ??
          HtmlParse.firstMatch(html, [
            RegExp(r'القصة[:：]?\s*([\s\S]{20,400})'),
          ]) ??
          '',
    );
    final genres = HtmlParse.all(
      html,
      RegExp(r'olympustaff\.com/series\?genre=([^)\s"]+)'),
    ).map((g) => Uri.decodeComponent(g.replaceAll('+', ' '))).toList();
    if (genres.isEmpty) {
      genres.addAll(HtmlParse.all(
        html,
        RegExp(r'href="[^"]*genre=[^"]*"[^>]*>([^<]+)<', caseSensitive: false),
      ));
    }
    final typeName = HtmlParse.firstMatch(html, [
          RegExp(r'النوع:\s*\[[^\]]*\]\(([^)]+)\)'),
          RegExp(r'النوع:.*?>([^<]+)<'),
        ]) ??
        'comic';
    final chapterPages = <String>{url};
    chapterPages.addAll(_chapterPageUrls(html, url));
    final chapterHtml = <String>[html];
    final visited = <String>{url};
    while (chapterPages.isNotEmpty) {
      final page = chapterPages.first;
      chapterPages.remove(page);
      if (!visited.add(page)) continue;
      final pageHtml = await HtmlClient.getHtml(page);
      chapterHtml.add(pageHtml);
      chapterPages.addAll(_chapterPageUrls(pageHtml, url)
          .where((next) => !visited.contains(next)));
    }
    final chapters = <Map<String, dynamic>>[];
    for (final pageHtml in chapterHtml) {
      chapters.addAll(_parseChapters(pageHtml, url));
    }
    final uniqueChapters = <String, Map<String, dynamic>>{
      for (final chapter in chapters) chapter['url'].toString(): chapter,
    }.values.toList()
      ..sort((a, b) =>
          (b['number'] as double).compareTo(a['number'] as double));
    return {
      ...item(
        title: title,
        url: url,
        image: image,
        type: typeName.contains('مانها')
            ? 'Manhua'
            : typeName.contains('مانهوا')
                ? 'Manhwa'
                : typeName,
        genres: genres.toSet().toList(),
        description: description,
      ),
      'synopsis': description,
      'chapters': uniqueChapters,
    };
  }

  @override
  Future<Map<String, dynamic>> chapterImages(String url) async {
    final html = await HtmlClient.getHtml(url);
    final images = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final match in RegExp(
      r'(https://olympustaff\.com/uploads/manga_[^\s)"\]]+)',
    ).allMatches(html)) {
      final src = match.group(1)!;
      if (!seen.add(src)) continue;
      images.add({'url': src});
    }
    if (images.isEmpty) {
      for (final match in RegExp(
        r'<img[^>]+src="(https://olympustaff\.com/uploads/[^"]+)"',
        caseSensitive: false,
      ).allMatches(html)) {
        final src = match.group(1)!;
        if (!seen.add(src)) continue;
        images.add({'url': src});
      }
    }
    final title = HtmlParse.stripTags(
      HtmlParse.firstMatch(html, [
            RegExp(r'^#\s*(.+)$', multiLine: true),
            RegExp(r'<h1[^>]*>([\s\S]*?)</h1>', caseSensitive: false),
          ]) ??
          'الفصل',
    );
    return {
      'title': title,
      'images': images,
      'chapter_number': SourceUtils.chapterNumber(url) ?? 0,
    };
  }

  String _coverImage(String raw, String baseUrl) {
    var value = HtmlParse.decode(raw).trim();
    if (value.contains(',')) value = value.split(',').first.trim().split(' ').first;
    value = value.replaceAll(RegExp("""[\"'()]"""), '');
    return value.isEmpty ? '' : HtmlParse.absUrl(baseUrl, value);
  }

  List<Map<String, dynamic>> _parseSeriesList(String html) {
    // Current Team X markup uses `.bsx` cards inside `.manga-list`.
    final current = <Map<String, dynamic>>[];
    final currentSeen = <String>{};
    final currentPattern = RegExp(
      r'''<div[^>]+class=["'][^"']*bsx[^"']*["'][\s\S]*?<a[^>]+href=["']([^"']*/series/[^"']+)["'][^>]*title=["']([^"']*)["'][\s\S]*?<img[^>]+(?:src|data-src)=["']([^"']+)["']''',
      caseSensitive: false,
    );
    for (final match in currentPattern.allMatches(html)) {
      final url = HtmlParse.absUrl(_base, match.group(1)!);
      if (!url.contains('/series/') || !currentSeen.add(url)) continue;
      final rawTitle = HtmlParse.decode(match.group(2) ?? '').trim();
      current.add(item(
        title: HtmlParse.stripTags(rawTitle.isEmpty
            ? url.split('/').last.replaceAll('-', ' ')
            : rawTitle),
        url: url,
        image: _coverImage(match.group(3)!, url),
        type: 'comic',
      ));
    }
    if (current.isNotEmpty) return current;

    final modern = <Map<String, dynamic>>[];
    final modernSeen = <String>{};
    final modernPattern = RegExp(
      r'''<a[^>]+href=[\"'](https://olympustaff\.com/series/[^\"']+)[\"'][\s\S]{0,650}?<img[^>]+src=[\"']([^\"']+)[\"'][\s\S]{0,250}?(?:title=[\"']([^\"']+)[\"']|class=[\"'][^\"']*tt[^>]*>[\s\S]*?([^<]+))''',
      caseSensitive: false,
    );
    for (final match in modernPattern.allMatches(html)) {
      final url = match.group(1)!;
      if (!modernSeen.add(url)) continue;
      final title = HtmlParse.stripTags(match.group(3) ?? match.group(4) ?? url.split('/').last.replaceAll('-', ' '));
      modern.add(item(title: title, url: url, image: match.group(2)!, type: 'comic'));
    }
    if (modern.isNotEmpty) return modern;
    final items = <Map<String, dynamic>>[];
    final seen = <String>{};
    final md = RegExp(
      r'\[([^\]]*)\]\((https://olympustaff\.com/series/[a-z0-9-]+)(?:\s+"([^"]*)")?\)',
      caseSensitive: false,
    );
    for (final match in md.allMatches(html)) {
      final url = match.group(2)!;
      if (RegExp(r'/series/[^/]+/\d+').hasMatch(url) || !seen.add(url)) continue;
      var title = (match.group(3) ?? match.group(1) ?? '').trim();
      title = title
          .replaceAll(RegExp(r'!\[.*?\]\([^)]+\)'), '')
          .replaceAll(RegExp(r'متروك|مستمرة|مانها صيني|مانهوا كوري|مانجا ياباني'), '')
          .trim();
      if (title.isEmpty) title = url.split('/').last.replaceAll('-', ' ');
      final nearby = html.substring(
        match.start > 200 ? match.start - 200 : 0,
        match.end + 80 < html.length ? match.end + 80 : html.length,
      );
      final image = HtmlParse.firstMatch(nearby, [
            RegExp(r'(https://olympustaff\.com/images/manga/[^\s)"\]]+)'),
          ]) ??
          '';
      items.add(item(title: HtmlParse.stripTags(title), url: url, image: _coverImage(image, url), type: 'comic'));
    }
    if (items.isNotEmpty) return items;
    for (final match in RegExp(
      r'href="(https://olympustaff\.com/series/[a-z0-9-]+)"[^>]*>([\s\S]*?)</a>',
      caseSensitive: false,
    ).allMatches(html)) {
      final url = match.group(1)!;
      if (!seen.add(url)) continue;
      items.add(item(
        title: HtmlParse.stripTags(match.group(2) ?? url.split('/').last),
        url: url,
        type: 'comic',
      ));
    }
    return items;
  }

  List<Map<String, dynamic>> _parseChapters(String html, String seriesUrl) {
    final chapters = <Map<String, dynamic>>[];
    final seen = <String>{};
    final slug = Uri.parse(seriesUrl).path.replaceAll(RegExp(r'/$'), '');
    final currentPattern = RegExp(
      r'''<a[^>]+href=["']([^"']*/series/[^"']+/(\d+(?:\.\d+)?))["'][^>]*class=["'][^"']*chapter-link[^"']*["']''',
      caseSensitive: false,
    );
    for (final match in currentPattern.allMatches(html)) {
      final numStr = match.group(2)!;
      final url = HtmlParse.absUrl(_base, match.group(1)!);
      if (!seen.add(url)) continue;
      chapters.add({
        'title': 'الفصل $numStr',
        'url': url,
        'number': double.tryParse(numStr) ?? chapters.length + 1,
      });
    }
    if (chapters.isNotEmpty) {
      chapters.sort((a, b) =>
          (b['number'] as double).compareTo(a['number'] as double));
      return chapters;
    }
    for (final match in RegExp(
      'https://olympustaff\\.com$slug/(\\d+(?:\\.\\d+)?)',
    ).allMatches(html)) {
      final numStr = match.group(1)!;
      final url = match.group(0)!;
      if (!seen.add(url)) continue;
      final number = double.tryParse(numStr) ?? chapters.length + 1;
      chapters.add({
        'title': 'الفصل $numStr',
        'url': url,
        'number': number,
      });
    }
    if (chapters.isEmpty) {
      for (final match in RegExp(
        r'href="([^"]+/series/[^"]+/\d+(?:\.\d+)?)"',
        caseSensitive: false,
      ).allMatches(html)) {
        final url = HtmlParse.absUrl(_base, match.group(1)!);
        if (!seen.add(url)) continue;
        final number = double.tryParse(
                RegExp(r'(\d+(?:\.\d+)?)$').firstMatch(url)?.group(1) ?? '') ??
            chapters.length + 1;
        chapters.add({
          'title': 'الفصل $number',
          'url': url,
          'number': number,
        });
      }
    }
    chapters.sort((a, b) =>
        (b['number'] as double).compareTo(a['number'] as double));
    return chapters;
  }

  Set<String> _chapterPageUrls(String html, String seriesUrl) {
    final pages = <String>{};
    final slug = Uri.parse(seriesUrl).path.replaceAll(RegExp(r'/$'), '');
    for (final match in RegExp(
      r'''href=["']([^"']*page=\d+[^"']*)["']''',
      caseSensitive: false,
    ).allMatches(html)) {
      final url = HtmlParse.absUrl(_base, match.group(1)!);
      if (url.contains(slug)) pages.add(url);
    }
    return pages;
  }
}
