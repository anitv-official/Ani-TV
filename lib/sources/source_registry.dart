import 'anime3rb_source.dart';
import 'anime_phoenix_source.dart';
import 'azorafy_source.dart';
import 'manga_swat_source.dart';
import 'olympus_source.dart';
import 'risto_anime_source.dart';
import 'source_base.dart';

class SourceRegistry {
  static final List<ContentSource> all = [
    RistoAnimeSource(),
    Anime3rbSource(),
    AnimePhoenixSource(),
    OlympusSource(),
    AzorafySource(),
    MangaSwatSource(),
  ];

  static List<ContentSource> get animeSources =>
      all.where((s) => s.kind == 'anime').toList();

  static List<ContentSource> get mangaSources =>
      all.where((s) => s.kind == 'manga').toList();

  static ContentSource? sourceFor(String url) {
    for (final source in all) {
      if (source.handles(url)) return source;
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> searchAnime(String query) async {
    return _merge(animeSources.map((s) => s.search(query)));
  }

  static Future<List<Map<String, dynamic>>> searchManga(String query) async {
    return _merge(mangaSources.map((s) => s.search(query)));
  }

  static Future<List<Map<String, dynamic>>> searchAll(String query) async {
    return _merge(all.map((s) => s.search(query)));
  }

  static Future<List<Map<String, dynamic>>> latestAnime({int page = 1}) async {
    return _merge(animeSources.map((s) => s.latest(page: page)));
  }

  static Future<List<Map<String, dynamic>>> latestManga({int page = 1}) async {
    return _merge(mangaSources.map((s) => s.latest(page: page)));
  }

  static Future<Map<String, dynamic>?> details(String url) async {
    final source = sourceFor(url);
    if (source == null) return null;
    return source.details(url);
  }

  static Future<Map<String, dynamic>?> streams(String url) async {
    final source = sourceFor(url);
    if (source == null) return null;
    return source.streams(url);
  }

  static Future<Map<String, dynamic>?> chapterImages(String url) async {
    final source = sourceFor(url);
    if (source == null) return null;
    return source.chapterImages(url);
  }

  static Future<List<Map<String, dynamic>>> _merge(
      Iterable<Future<List<Map<String, dynamic>>>> tasks) async {
    final results = await Future.wait(
      tasks.map((task) async {
        try {
          return await task.timeout(const Duration(seconds: 12));
        } catch (_) {
          return <Map<String, dynamic>>[];
        }
      }),
    );
    final merged = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final list in results) {
      for (final item in list) {
        final key = '${item['url']}|${item['source_id']}|${item['title']}';
        if (seen.add(key)) merged.add(item);
      }
    }
    return merged;
  }
}
