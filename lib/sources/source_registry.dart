import 'animefy_source.dart';
import 'anime_slayer_source.dart';
import 'drama_source.dart';
import 'manga_mello_source.dart';
import 'manga_swat_source.dart';
import 'mangatime_source.dart';
import 'source_base.dart';
import 'web_catalog_source.dart';
import '../extensions/extension_catalog.dart';

/// Internal API catalog.
///
/// These adapters share a stable ContentSource contract so they can be used
/// by the user-facing Sources screen and by the repository integration.
class SourceRegistry {
  static const Duration _requestTimeout = Duration(seconds: 35);
  static const Duration _cacheDuration = Duration(minutes: 3);
  static const int _maxAttempts = 3;
  static final Map<String, _RegistryCache> _cache = {};
  static final Map<String, Future<List<Map<String, dynamic>>>> _inFlight = {};
  static final _anime3rb = Anime3rbSource();
  static final _wecima = WecimaSource();
  static final _kormoz = KormozSource();
  static final List<ContentSource> _extensions = ExtensionCatalog.all;
  // API-only adapters. Keep this list private so the UI cannot expose them.
  static final List<ContentSource> _apis = [
    AnimeSlayerSource(),
    AnimefySource(),
    DramaSource(),
    MangaSwatSource(),
    MangaTimeSource(),
    MangaMelloSource(),
    _anime3rb,
    _wecima,
    _kormoz,
  ];

  static List<ContentSource> get _repositorySources => const [];
  static List<ContentSource> get _allSources => [..._apis, ..._repositorySources, ..._extensions];

  static List<ContentSource> get _animeApis =>
      _apis.where((s) => s.kind == 'anime').toList(growable: false);
  static List<ContentSource> get _mangaApis =>
      _apis.where((s) => s.kind == 'manga').toList(growable: false);
  static List<ContentSource> get _dramaApis =>
      _apis.where((s) => s.kind == 'drama').toList(growable: false);
  static List<ContentSource> get _movieApis =>
      _apis.where((s) => s.kind == 'movie').toList(growable: false);

  /// Kept for backwards compatibility. API adapters must not appear as sources.
  static const List<ContentSource> all = <ContentSource>[];

  /// Sources that have a complete user-facing adapter and can be opened from
  /// the Sources screen. Other adapters remain internal until their UI flow
  /// and playback contracts are verified.
  static List<ContentSource> get visibleSources => List.unmodifiable(_allSources);
  /// Compatibility getters for tests/services. The UI uses [all], which is
  /// intentionally empty so API adapters are never shown as sources.
  static List<ContentSource> get animeSources => _animeApis;
  static List<ContentSource> get mangaSources => _mangaApis;
  static List<ContentSource> get dramaSources => _dramaApis;
  static List<ContentSource> get movieSources => _movieApis;

  static ContentSource? sourceFor(String url) {
    for (final source in _allSources) {
      if (source.handles(url)) return source;
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> searchAnime(String query) {
    return _merge([
      ..._animeApis,
      ..._dramaApis,
    ].map((source) => _retry(() => source.search(query))));
  }

  static Future<List<Map<String, dynamic>>> searchManga(String query) {
    return _merge(_mangaApis.map((source) => _retry(() => source.search(query))));
  }

  static Future<List<Map<String, dynamic>>> searchAll(String query) {
    return _merge(_allSources.map((source) => _retry(() => source.search(query))));
  }


  static Future<List<Map<String, dynamic>>> latestAnime({int page = 1}) {
    return _cached('anime:$page', () => _merge([
          ..._animeApis,
          ..._dramaApis,
        ].map((source) => _retry(() => source.latest(page: page)))));
  }

  static Future<List<Map<String, dynamic>>> latestManga({int page = 1}) {
    return _cached('manga:$page', () =>
        _merge(_mangaApis.map((source) => _retry(() => source.latest(page: page)))));
  }


  static Future<List<Map<String, dynamic>>> latestFromSource(
      String sourceId, {int page = 1}) async {
    final source = _allSources.firstWhere((entry) => entry.id == sourceId);
    return _retry(() => source.latest(page: page));
  }

  static Future<Map<String, dynamic>?> details(String url) async {
    final source = sourceFor(url);
    if (source == null) return null;
    return _retry(() => source.details(url));
  }

  static Future<Map<String, dynamic>?> streams(String url) async {
    final source = sourceFor(url);
    if (source == null) return null;
    final result = await _retry(() => source.streams(url));
    if (result == null) return null;
    final links = (result['direct_stream_urls'] as List?)
            ?.whereType<Map>()
            .where((link) => _validPlayableLink(link, source))
            .toList() ??
        [];
    // Never pass third-party player pages to the app. They commonly contain
    // login/social buttons, pop-under ads, and redirect scripts. Only direct
    // media URLs may enter the native player for movie/series providers.
    if (links.isEmpty) return null;
    return {...result, 'direct_stream_urls': links};
  }

  static bool _validPlayableLink(Map link, ContentSource source) {
    final value = link['url']?.toString() ?? '';
    final uri = Uri.tryParse(value);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
      return false;
    }
    final lower = value.toLowerCase();
    final media = RegExp(r'\.(?:mp4|m3u8|mov|webm|mpd)(?:[?#].*)?$').hasMatch(lower) ||
        lower.contains('pixeldrain.com/api/file');
    final embeddedPlayer = const {
      'streamtape.cc',
      'streamtape.com',
      'luluvdo.com',
      'uqload.net',
      'uqload.cx',
      'uqload.io',
      'uqload.vc',
      'streamwish.to',
      'streamwish.fun',
      'streamwish.com',
      'topcinemaa.com',
      'topcinemaa.cc',
      'topcinemaa.co',
      'web2.topcinemaa.com',
      'vidtube.one',
      'down.vidtube.one',
      'updown.icu',
      'animewitcher.com',
      'anime3rb.com',
      'wecima.show',
      'wecima.tube',
      'wecima.video',
      'wecima.mov',
      'kormoz.com',
      'kormozi.com',
      'kormozy.com',
      'mediafire.com',
      'pixeldrain.com',
      'firestream.to',
      'firestream.site',
    }.any((host) => uri.host.toLowerCase().replaceFirst('www.', '') == host);
    final requestedEmbed = link['type']?.toString() == 'embed';
    final extractorCandidate = source.id == 'egydead' &&
        RegExp(r'(?:embed|player|stream|vid|file)', caseSensitive: false).hasMatch(lower);
    final providerEmbed =
        (source.id == 'egydead' || source.id == 'anime_witcher') && requestedEmbed;
    return (!requestedEmbed && media) || embeddedPlayer || extractorCandidate || providerEmbed;
  }

  static Future<Map<String, dynamic>?> chapterImages(String url) async {
    final source = sourceFor(url);
    if (source == null) return null;
    return _retry(() => source.chapterImages(url));
  }

  static Future<List<Map<String, dynamic>>> _merge(
      Iterable<Future<List<Map<String, dynamic>>>> tasks) async {
    final results = await Future.wait(tasks.map((task) async {
      try {
        return await task;
      } catch (_) {
        // An unavailable provider must not hide results from healthy APIs.
        return <Map<String, dynamic>>[];
      }
    }));
    final merged = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final list in results) {
      for (final item in list) {
        final key = '${item['url']}|${item['source_id']}|${item['title']}';
        if (seen.add(key)) merged.add(item);
      }
    }
    merged.sort((a, b) => _sourcePriority(a).compareTo(_sourcePriority(b)));
    return merged;
  }

  static Future<T> _retry<T>(Future<T> Function() operation) async {
    Object? lastError;
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        return await operation().timeout(_requestTimeout);
      } catch (error) {
        lastError = error;
        if (attempt < _maxAttempts) {
          await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
        }
      }
    }
    throw lastError ?? Exception('API request failed');
  }

  static int _sourcePriority(Map<String, dynamic> item) {
    final source = '${item['source_id'] ?? item['source'] ?? ''}'.toLowerCase();
    return source == 'anime_slayer' ? 0 : 1;
  }

  static Future<List<Map<String, dynamic>>> _cached(
      String key, Future<List<Map<String, dynamic>>> Function() loader) {
    final existing = _cache[key];
    if (existing != null &&
        DateTime.now().difference(existing.createdAt) < _cacheDuration) {
      return Future<List<Map<String, dynamic>>>.value(existing.value);
    }
    final running = _inFlight[key];
    if (running != null) return running;
    final future = loader();
    _inFlight[key] = future;
    future.then((value) {
      if (value.isNotEmpty) _cache[key] = _RegistryCache(value);
    }).whenComplete(() {
      if (identical(_inFlight[key], future)) _inFlight.remove(key);
    });
    return future;
  }

  static void clearCache() {
    _cache.clear();
  }
}

class _RegistryCache {
  final List<Map<String, dynamic>> value;
  final DateTime createdAt = DateTime.now();
  _RegistryCache(this.value);
}

/// Explicit API group names for non-UI callers and diagnostics.
enum InternalApiGroup { anime, manga, drama }

extension InternalApiGroupLabel on InternalApiGroup {
  String get key => switch (this) {
        InternalApiGroup.anime => 'api_anime',
        InternalApiGroup.manga => 'api_manga',
        InternalApiGroup.drama => 'api_drama',
      };
}
