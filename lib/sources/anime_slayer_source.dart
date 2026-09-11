import 'anime_slayer_api.dart';
import 'source_base.dart';

/// Anime Slayer source backed by the public API used by the official Android app.
/// The source identity remains unchanged so existing UI, badges, history and player
/// integration continue to work.
class AnimeSlayerSource extends ContentSource {
  @override
  String get id => 'anime_slayer';

  @override
  String get name => 'Anime Slayer';

  @override
  String get kind => 'anime';

  @override
  List<String> get hosts => ['anslayer.com', 'img.anslayer.com', 'video.anime-slayer.com', 'anime-slayer.com'];

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final records = await AnimeSlayerApi.search(query);
    return records.map(_asItem).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final records = await AnimeSlayerApi.latest(offset: (page - 1) * 30);
    return records.map(_asItem).toList();
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final uri = Uri.tryParse(url);
    final id = int.tryParse(uri?.queryParameters['anime_id'] ?? '');
    if (id == null || id <= 0) throw Exception('تعذر تحديد الأنمي من Anime Slayer');
    final data = await AnimeSlayerApi.details(id);
    return {
      ...data,
      'url': url,
      'source': name,
      'source_id': this.id,
      'type': 'anime',
      'category': 'anime',
    };
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async {
    final uri = Uri.tryParse(url);
    final animeId = int.tryParse(uri?.queryParameters['anime_id'] ?? '');
    final episodeId = int.tryParse(uri?.queryParameters['episode_id'] ?? '');
    if (animeId == null || episodeId == null || animeId <= 0 || episodeId <= 0) return null;
    return AnimeSlayerApi.streams(animeId, episodeId);
  }

  Map<String, dynamic> _asItem(Map<String, dynamic> record) {
    final title = (record['title'] ?? '').toString().trim();
    return item(
      title: title,
      url: record['url'].toString(),
      image: (record['image_url'] ?? '').toString(),
      type: 'anime',
      genres: record['genres'] as List? ?? const [],
      description: (record['description'] ?? '').toString(),
      rating: (record['rating'] ?? '').toString(),
    )
      ..addAll({
        'anime_id': record['anime_id'],
        'english_title': record['english_title'] ?? '',
        'banner_image_url': record['banner_image_url'] ?? '',
        'status': record['status'] ?? '',
        'release_year': record['release_year'] ?? '',
      });
  }
}
