import 'dart:convert';
import 'package:http/http.dart' as http;

class TmdbService {
  static const _base = 'https://api.themoviedb.org/3';
  static const apiKey = String.fromEnvironment('TMDB_API_KEY');
  static bool get isConfigured => apiKey.trim().isNotEmpty;

  static Future<List<Map<String, dynamic>>> search(String query,
      {bool tv = false}) async {
    if (!isConfigured) return const [];
    try {
      final path = tv ? 'search/tv' : 'search/movie';
      final uri = Uri.parse('$_base/$path').replace(queryParameters: {
        'api_key': apiKey,
        'language': 'ar-SA',
        'query': query,
        'include_adult': 'false'
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 7));
      if (response.statusCode < 200 || response.statusCode >= 300)
        return const [];
      final results = (jsonDecode(response.body) as Map?)?['results'];
      if (results is! List) return const [];
      return results.whereType<Map>().take(8).map((item) {
        final title = tv ? item['name'] : item['title'];
        final date = tv ? item['first_air_date'] : item['release_date'];
        return <String, dynamic>{
          'id': 'tmdb:${item['id']}',
          'external_id': item['id'],
          'source': 'TMDB',
          'source_id': 'tmdb',
          'title': title ?? 'بدون عنوان',
          'url': '',
          'cover_url': item['poster_path'] == null
              ? ''
              : 'https://image.tmdb.org/t/p/w500${item['poster_path']}',
          'banner_url': item['backdrop_path'] == null
              ? ''
              : 'https://image.tmdb.org/t/p/w780${item['backdrop_path']}',
          'description': item['overview'] ?? '',
          'score': item['vote_average'],
          'year': date?.toString().split('-').first,
          'category': tv ? 'series' : 'movie',
          'external_only': true,
        };
      }).toList();
    } catch (_) {
      return const [];
    }
  }
}
