import 'html_client.dart';
import 'source_base.dart';

class OlympusSource extends ContentSource {
  static const String _base = 'https://olympustaff.com';

  @override
  String get id => 'olympus';

  @override
  String get name => 'Team X Manga';

  @override
  String get kind => 'manga';

  @override
  List<String> get hosts => ['olympustaff.com'];

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final slug = HtmlParse.slugify(query);
    final tried = <Map<String, dynamic>>[];
    try {
      final direct = await details('$_base/series/$slug');
      tried.add(item(
        title: direct['title']?.toString() ?? query,
        url: direct['url']?.toString() ?? '$_base/series/$slug',
        image: direct['image_url']?.toString() ?? '',
        type: direct['type']?.toString() ?? 'comic',
        genres: direct['genres'] as List? ?? [],
        description: direct['description']?.toString() ?? '',
      ));
    } catch (_) {}
    final html = await HtmlClient.getHtml('$_base/series');
    final all = _parseSeriesList(html);
    final q = query.toLowerCase();
    final filtered = all
        .where((item) =>
            (item['title'] ?? '').toString().toLowerCase().contains(q) ||
            (item['url'] ?? '').toString().toLowerCase().contains(slug))
        .toList();
    final merged = [...tried, ...filtered];
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
    final chapters = _parseChapters(html, url);
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
      'chapters': chapters,
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

  List<Map<String, dynamic>> _parseSeriesList(String html) {
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
      items.add(item(title: HtmlParse.stripTags(title), url: url, image: image, type: 'comic'));
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
    for (final match in RegExp(
      'https://olympustaff\\.com$slug/(\\d+(?:\\.\\d+)?)',
    ).allMatches(html)) {
      final numStr = match.group(1)!;
      final url = match.group(0)!;
      if (!seen.add(url)) continue;
      final number = int.tryParse(numStr.split('.').first) ?? chapters.length + 1;
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
        final number = SourceUtils.chapterNumber(url) ?? chapters.length + 1;
        chapters.add({
          'title': 'الفصل $number',
          'url': url,
          'number': number,
        });
      }
    }
    chapters.sort((a, b) => (b['number'] as int).compareTo(a['number'] as int));
    return chapters;
  }
}
