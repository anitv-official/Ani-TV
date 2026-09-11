abstract class ContentSource {
  String get id;
  String get name;
  String get kind;
  List<String> get hosts;

  bool handles(String url) {
    final host = _hostOf(url);
    return hosts.any((h) => host == h || host.endsWith('.$h') || host.contains(h));
  }

  Future<List<Map<String, dynamic>>> search(String query);

  Future<List<Map<String, dynamic>>> latest({int page = 1});

  Future<Map<String, dynamic>> details(String url);

  Future<Map<String, dynamic>?> streams(String url) async => null;

  Future<Map<String, dynamic>?> chapterImages(String url) async => null;

  Map<String, dynamic> item({
    required String title,
    required String url,
    String image = '',
    String type = '',
    List<dynamic> genres = const [],
    String description = '',
    String rating = '',
  }) {
    final resolvedType = type.isNotEmpty ? type : (kind == 'anime' ? 'anime' : 'comic');
    return {
      'title': title,
      'url': url,
      'image_url': image,
      'type': resolvedType,
      'category': kind == 'anime' ? 'anime' : 'comic',
      'source': name,
      'source_id': id,
      'genres': genres,
      'description': description,
      'rating': rating,
    };
  }

  String _hostOf(String url) {
    try {
      return Uri.parse(url).host.toLowerCase().replaceFirst('www.', '');
    } catch (_) {
      return '';
    }
  }
}

class SourceUtils {
  static List<String> extractMediaUrls(String html, String pageUrl) {
    final urls = <String>{};
    void add(String raw) {
      final value = raw.trim().replaceAll('&amp;', '&');
      if (value.isEmpty) return;
      final resolved = HtmlParse.absUrl(pageUrl, value);
      if (resolved.isNotEmpty) urls.add(resolved);
    }
    for (final match in RegExp(r'''(?:src|data-src|data-url|data-embed|href)=["']([^"']+)["']''', caseSensitive: false).allMatches(html)) {
      add(match.group(1)!);
    }
    for (final match in RegExp(r'https?://[^\s"<>]+(?:\.mp4|\.m3u8|ok\.ru|dood|mp4upload|vidmoly|uqload|streamtape|filemoon|voe|mixdrop|yourupload|goload|sbfull|sbplay|pixeldrain)[^\s"<>]*', caseSensitive: false).allMatches(html)) {
      add(match.group(0)!);
    }
    return urls.where((url) => !url.contains(HtmlParse.hostOf(pageUrl))).toList();
  }

  static String cleanTitle(String title) {
    return title
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('&amp;', '&')
        .trim();
  }

  static String episodeTitle(String raw, [int? number]) {
    final cleaned = cleanTitle(raw)
        .replaceAll(RegExp(r'مترجم.*$'), '')
        .replaceAll(RegExp(r'اون.?لاين.*$', caseSensitive: false), '')
        .trim();
    if (cleaned.isNotEmpty) return cleaned;
    return number == null ? 'حلقة' : 'الحلقة $number';
  }

  static int? episodeNumber(String text) {
    final match = RegExp(r'(?:الحلقة|حلقة|episode|ep)\s*[:\-]?\s*(\d+)', caseSensitive: false)
        .firstMatch(text);
    if (match != null) return int.tryParse(match.group(1)!);
    final last = RegExp(r'(\d+)').allMatches(text).toList();
    if (last.isEmpty) return null;
    return int.tryParse(last.last.group(1)!);
  }

  static int? chapterNumber(String text) {
    final match = RegExp(r'(?:الفصل|chapter|ch)\s*[:\-]?\s*(\d+(?:\.\d+)?)', caseSensitive: false)
        .firstMatch(text);
    if (match != null) return int.tryParse(match.group(1)!.split('.').first);
    final last = RegExp(r'(\d+)').allMatches(text).toList();
    if (last.isEmpty) return null;
    return int.tryParse(last.last.group(1)!);
  }

  static String seriesKey(String title) {
    return cleanTitle(title)
        .toLowerCase()
        .replaceAll(RegExp(r'(الحلقة|حلقة|episode|ep)\s*\d+.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'مترجم.*$'), '')
        .replaceAll(RegExp(r'اون.?لاين', caseSensitive: false), '')
        .replaceAll(RegExp(r'انمي|anime'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
