import 'html_client.dart';
import 'source_base.dart';

class AzorafySource extends ContentSource {
  static const String _base = 'https://azorafly.com';

  @override
  String get id => 'azora';

  @override
  String get name => 'Azorafy';

  @override
  String get kind => 'manga';

  @override
  List<String> get hosts => ['azorafly.com', 'azoramoon.com'];

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final html = await HtmlClient.getHtml(
        '$_base/?s=${Uri.encodeQueryComponent(query)}');
    return _parseCards(html);
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final url = page <= 1 ? '$_base/series' : '$_base/series?page=$page';
    final html = await HtmlClient.getHtml(url);
    return _parseCards(html);
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final html = await HtmlClient.getHtml(url);
    final title = HtmlParse.stripTags(
      HtmlParse.meta(html, 'og:title') ??
          HtmlParse.firstMatch(html, [
            RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false)
          ]) ??
          'بدون عنوان',
    );
    final image = HtmlParse.meta(html, 'og:image') ??
        HtmlParse.firstMatch(html, [
              RegExp(r'<img[^>]+src="(https://storage\.azorafly\.com/[^"]+)"',
                  caseSensitive: false)
            ]) ??
            '';
    final description = HtmlParse.stripTags(
      HtmlParse.meta(html, 'og:description') ?? '',
    );
    final genres = HtmlParse.all(
      html,
      RegExp(
          r'class="[^"]*rounded-full[^"]*"[\s\S]{0,120}?<span[^>]*>([^<]+)</span>',
          caseSensitive: false),
    );
    final typeBadge = HtmlParse.firstMatch(html, [
          RegExp(r'uppercase bg-gray-800[^>]*>\s*([^<]+)\s*<',
              caseSensitive: false)
        ]) ??
        'comic';
    var chapters = _parseListedChapters(html, url);
    chapters = await _expandChapters(url, chapters);
    return {
      ...item(
        title: title,
        url: url,
        image: image,
        type: typeBadge,
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
      r'<img[^>]+src="(https://storage\.azorafly\.com/upload/series/[^"]+)"',
      caseSensitive: false,
    ).allMatches(html)) {
      final src = match.group(1)!;
      if (!seen.add(src)) continue;
      images.add({'url': src});
    }
    if (images.isEmpty) {
      for (final match in RegExp(
        r'(https://storage\.azorafly\.com/upload/series/[^"\s]+)',
        caseSensitive: false,
      ).allMatches(html)) {
        final src = match.group(1)!;
        if (!seen.add(src)) continue;
        images.add({'url': src});
      }
    }
    final title = HtmlParse.stripTags(
      HtmlParse.meta(html, 'og:title') ?? 'الفصل',
    );
    return {
      'title': title,
      'images': images,
      'chapter_number': SourceUtils.chapterNumber(url) ?? 0,
    };
  }

  List<Map<String, dynamic>> _parseCards(String html) {
    final items = <Map<String, dynamic>>[];
    final seen = <String>{};
    final pattern = RegExp(
      r'<a href="(/series/[^"]+)"[^>]*>[\s\S]{0,2000}?</a>',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(html)) {
      final path = match.group(1)!;
      if (path.contains('/chapter-')) continue;
      final url = HtmlParse.absUrl(_base, path);
      if (!seen.add(url)) continue;
      final block = match.group(0) ?? '';
      final title = HtmlParse.stripTags(
        HtmlParse.firstMatch(block, [
              RegExp(r'title="([^"]+)"'),
              RegExp(r'alt="([^"]+)"'),
              RegExp(r'<h2[^>]*>([\s\S]*?)</h2>', caseSensitive: false),
            ]) ??
            path.split('/').last,
      );
      final image = HtmlParse.firstMatch(block, [
            RegExp(r'src="(https://storage\.azorafly\.com/[^"]+)"'),
            RegExp(r'src="([^"]+)"'),
          ]) ??
          '';
      final typeBadge = HtmlParse.firstMatch(block, [
            RegExp(r'uppercase[^>]*>\s*([^<]+)\s*<', caseSensitive: false)
          ]) ??
          'comic';
      final genres = HtmlParse.all(
        block,
        RegExp(r'<span class="leading-6 font-light">([^<]+)</span>'),
      );
      items.add(item(
        title: title,
        url: url,
        image: image,
        type: typeBadge,
        genres: genres,
      ));
    }
    return items;
  }

  List<Map<String, dynamic>> _parseListedChapters(String html, String seriesUrl) {
    final chapters = <Map<String, dynamic>>[];
    final seen = <String>{};
    final slug = Uri.parse(seriesUrl).path;
    for (final match in RegExp(
      'href="($slug/chapter-\\d+(?:\\.\\d+)?)"',
    ).allMatches(html)) {
      final path = match.group(1)!;
      final url = HtmlParse.absUrl(_base, path);
      if (!seen.add(url)) continue;
      final number = SourceUtils.chapterNumber(path) ?? chapters.length + 1;
      chapters.add({
        'title': 'الفصل $number',
        'url': url,
        'number': number,
      });
    }
    return chapters;
  }

  Future<List<Map<String, dynamic>>> _expandChapters(
      String seriesUrl, List<Map<String, dynamic>> listed) async {
    if (listed.isEmpty) return listed;
    final numbers = listed
        .map((c) => c['number'] as int? ?? 0)
        .where((n) => n > 0)
        .toList()
      ..sort();
    if (numbers.isEmpty) return listed;
    final maxN = numbers.last;
    final minListed = numbers.where((n) => n > 1).isEmpty
        ? maxN
        : numbers.where((n) => n > 1).reduce((a, b) => a < b ? a : b);
    final slug = Uri.parse(seriesUrl).path.replaceAll(RegExp(r'/$'), '');
    final byNumber = <int, Map<String, dynamic>>{
      for (final c in listed) (c['number'] as int? ?? 0): c,
    };
    if (!byNumber.containsKey(1)) {
      byNumber[1] = {
        'title': 'الفصل 1',
        'url': HtmlParse.absUrl(_base, '$slug/chapter-1'),
        'number': 1,
      };
    }
    if (maxN - minListed < 80) {
      for (var n = 1; n <= maxN; n++) {
        byNumber.putIfAbsent(n, () {
          return {
            'title': 'الفصل $n',
            'url': HtmlParse.absUrl(_base, '$slug/chapter-$n'),
            'number': n,
          };
        });
      }
    } else {
      for (var n = minListed; n <= maxN; n++) {
        byNumber.putIfAbsent(n, () {
          return {
            'title': 'الفصل $n',
            'url': HtmlParse.absUrl(_base, '$slug/chapter-$n'),
            'number': n,
          };
        });
      }
    }
    final chapters = byNumber.values.toList();
    chapters.sort((a, b) => (b['number'] as int).compareTo(a['number'] as int));
    return chapters;
  }
}
