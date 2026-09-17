import 'anime3rb_source.dart';
import 'anyplay_source.dart';
import 'animefy_source.dart';
import 'anime4up_source.dart';
import 'anime_slayer_source.dart';
import 'azorafy_source.dart';
import 'manga_swat_source.dart';
import 'manga_slayer_source.dart';
import 'manga_mello_source.dart';
import 'manga_dar_source.dart';
import 'mangatime_source.dart';
import 'hijala_source.dart';
import 'olympus_source.dart';
import 'risto_anime_source.dart';
import 'drama_source.dart';
import 'moviehdplay_source.dart';
import 'cimalight_source.dart';
import 'source_base.dart';

class SourceRegistry {
  static const Duration _sourceTimeout = Duration(seconds: 12);
  static const Duration _cacheDuration = Duration(minutes: 3);
  static final Map<String, _RegistryCache> _cache = {};
  static final List<ContentSource> all = [
    AnyPlaySource(),
    AnimeSlayerSource(),
    RistoAnimeSource(),
    AnimefySource(),
    Anime3rbSource(),
    Anime4UpSource(),
    OlympusSource(),
    AzorafySource(),
    MangaSwatSource(),
    MangaSlayerSource(),
    MangaMelloSource(),
    MangaDarSource(),
    MangaTimeSource(),
    HijalaSource(),
    DramaSource(),
    MovieHdPlaySource(),
    CimaLightSource(),
  ];

  static List<ContentSource> get animeSources =>
      all.where((s) => s.kind == 'anime').toList();

  static List<ContentSource> get mangaSources =>
      all.where((s) => s.kind == 'manga').toList();

  static List<ContentSource> get dramaSources =>
      all.where((s) => s.kind == 'drama').toList();

  static ContentSource? sourceFor(String url) {
    for (final source in all) {
      if (source.handles(url)) return source;
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> searchAnime(String query) async {
    return _merge([...animeSources, ...dramaSources].map((s) => s.search(query)), query: query);
  }

  static Future<List<Map<String, dynamic>>> searchManga(String query) async {
    return _merge(mangaSources.map((s) => s.search(query)), query: query);
  }

  static Future<List<Map<String, dynamic>>> searchAll(String query) async {
    return _merge(all.map((s) => s.search(query)), query: query);
  }

  static Future<List<Map<String, dynamic>>> latestAnime({int page = 1}) async {
    return _cached('anime:$page', () => _merge([...animeSources, ...dramaSources].map((s) => s.latest(page: page))));
  }

  static Future<List<Map<String, dynamic>>> latestManga({int page = 1}) async {
    return _cached('manga:$page', () => _merge(mangaSources.map((s) => s.latest(page: page))));
  }

  static Future<Map<String, dynamic>?> details(String url) async {
    final source = sourceFor(url);
    if (source == null) return null;
    return source.details(url);
  }

  static Future<Map<String, dynamic>?> streams(String url) async {
    final source = sourceFor(url);
    if (source == null) return null;
    final result = await source.streams(url);
    if (result == null) return null;

    final links = (result['direct_stream_urls'] as List?)
            ?.whereType<Map>()
            .where((link) {
              final value = link['url']?.toString() ?? '';
              final uri = Uri.tryParse(value);
              // AnyPlay's current API intentionally returns third-party
              // player pages (e.g. Videasy/Vidlink/VidSrc), not media files.
              // Keep only valid HTTP player URLs for this source; other
              // sources retain the existing direct-media-only behavior.
              final isAnyPlayPlayer = source.id == 'anyplay' &&
                  uri != null &&
                  (uri.scheme == 'http' || uri.scheme == 'https') &&
                  uri.host.isNotEmpty;
              return _isDirectMediaUrl(value) || isAnyPlayPlayer;
            })
            .toList() ??
        [];

    // Anime3rb is intentionally player-only: never pass an embed page to the
    // app's WebView fallback. If no real media URL was extracted, fail cleanly
    // so the user sees the source-unavailable state instead of a broken player.
    if (source.id == 'anime3rb' && links.isEmpty) return null;

    final playable = links.any((link) {
      final value = link['url']?.toString() ?? '';
      final isEmbeddedPlayer =
          (source.id == 'anyplay' && value.contains('anyplay.stream/embed/')) ||
          (source.id == 'cimalight' && value.contains('/videos.php?'));
      final sourceHost = Uri.tryParse(url)?.host.toLowerCase() ?? '';
      final linkHost = Uri.tryParse(value)?.host.toLowerCase() ?? '';
      return value.isNotEmpty && value != url &&
          (_isDirectMediaUrl(value) || isEmbeddedPlayer || linkHost != sourceHost);
    });
    return playable ? result : null;
  }

  static bool _isDirectMediaUrl(String value) {
    final lower = value.toLowerCase();
    return RegExp(r'\.(?:mp4|m3u8|mov|webm)(?:[?#].*)?$').hasMatch(lower) ||
        lower.contains('pixeldrain.com/api/file');
  }

  static Future<Map<String, dynamic>?> chapterImages(String url) async {
    final source = sourceFor(url);
    if (source == null) return null;
    return source.chapterImages(url);
  }

  static Future<List<Map<String, dynamic>>> _merge(
      Iterable<Future<List<Map<String, dynamic>>>> tasks, {String query = ''}) async {
    final results = await Future.wait(
      tasks.map((task) async {
        try {
          return await task.timeout(_sourceTimeout);
        } catch (_) {
          return <Map<String, dynamic>>[];
        }
      }),
    );
    final merged = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final list in results) {
      for (final item in list) {
        if (query.trim().isNotEmpty && !_matchesQuery(item, query)) continue;
        final key = '${item['url']}|${item['source_id']}|${item['title']}';
        if (seen.add(key)) merged.add(item);
      }
    }
    merged.sort((a, b) => _sourcePriority(a).compareTo(_sourcePriority(b)));
    return merged;
  }

  static int _sourcePriority(Map<String, dynamic> item) {
    final source = '${item['source_id'] ?? item['source'] ?? ''}'.toLowerCase();
    final url = '${item['url'] ?? ''}'.toLowerCase();
    if (source == 'anime_slayer' || source.contains('anime slayer') || url.contains('anime_slayer')) return 0;
    return 1;
  }

  static bool _matchesQuery(Map<String, dynamic> item, String query) {
    if ('${item['source_id'] ?? ''}'.toLowerCase() == 'anyplay') return true;
    final normalizedQuery = query.toLowerCase().trim();
    final haystack = '${item['title'] ?? ''} ${item['url'] ?? ''}'.toLowerCase();
    final terms = normalizedQuery.split(RegExp(r'\s+')).where((term) => term.length > 1).toList();
    if (terms.isEmpty) return haystack.contains(normalizedQuery);
    return terms.any(haystack.contains);
  }

  static Future<List<Map<String, dynamic>>> _cached(
      String key, Future<List<Map<String, dynamic>>> Function() loader) async {
    final existing = _cache[key];
    if (existing != null && DateTime.now().difference(existing.createdAt) < _cacheDuration) {
      return existing.value;
    }
    final value = await loader();
    if (value.isNotEmpty) _cache[key] = _RegistryCache(value);
    return value;
  }

  static void clearCache() => _cache.clear();
}

class _RegistryCache {
  final List<Map<String, dynamic>> value;
  final DateTime createdAt = DateTime.now();
  _RegistryCache(this.value);
}
