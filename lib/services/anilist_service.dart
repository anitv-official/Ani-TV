import 'dart:convert';

import 'package:http/http.dart' as http;

class AniListService {
  static const _endpoint = 'https://graphql.anilist.co';
  static final http.Client _client = http.Client();

  static Future<List<Map<String, dynamic>>> search(String query,
      {String type = 'ANIME'}) async {
    final normalizedType = type == 'MANGA' ? 'MANGA' : 'ANIME';
    const document = r'''
      query ($search: String, $type: MediaType) {
        Page(perPage: 8) {
          media(search: $search, type: $type, sort: SEARCH_MATCH) {
            id
            type
            format
            title { romaji english native }
            description(asHtml: false)
            coverImage { large extraLarge color }
            bannerImage
            averageScore
            episodes
            chapters
            volumes
            status
            season
            seasonYear
            genres
            siteUrl
          }
        }
      }
    ''';
    try {
      final response = await _client
          .post(
            Uri.parse(_endpoint),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json'
            },
            body: jsonEncode({
              'query': document,
              'variables': {'search': query, 'type': normalizedType}
            }),
          )
          .timeout(const Duration(seconds: 7));
      if (response.statusCode < 200 || response.statusCode >= 300)
        return const [];
      final decoded = jsonDecode(response.body);
      final media =
          (((decoded as Map?)?['data'] as Map?)?['Page'] as Map?)?['media'];
      if (media is! List) return const [];
      return media.whereType<Map>().map((item) {
        final title = (item['title'] as Map?) ?? const {};
        final cover = (item['coverImage'] as Map?) ?? const {};
        return <String, dynamic>{
          'id': 'anilist:${item['id']}',
          'external_id': item['id'],
          'source': 'AniList',
          'source_id': 'anilist',
          'title': title['english'] ??
              title['romaji'] ??
              title['native'] ??
              'بدون عنوان',
          'native_title': title['native'] ?? '',
          'url': item['siteUrl'] ?? '',
          'cover_url': cover['extraLarge'] ?? cover['large'] ?? '',
          'banner_url': item['bannerImage'] ?? '',
          'description': _clean(item['description']?.toString() ?? ''),
          'score': item['averageScore'],
          'episodes': item['episodes'],
          'chapters': item['chapters'],
          'volumes': item['volumes'],
          'format': item['format'],
          'status': item['status'],
          'year': item['seasonYear'],
          'genres': item['genres'] is List
              ? List<String>.from(item['genres'])
              : const <String>[],
          'external_only': true,
        };
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  static String _clean(String value) =>
      value.replaceAll(RegExp(r'<[^>]*>'), '').trim();
}
