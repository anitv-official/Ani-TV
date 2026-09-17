import '../sources/source_registry.dart';

class ApiService {
  static Future<List<dynamic>> fetchTopAnime() async {
    try {
      final sourced = await fetchLatestAnime();
      if (sourced.isNotEmpty) return sourced.take(12).toList();
      return [];
    } catch (e) {
      throw ApiException('Failed to load top anime: ${e.toString()}');
    }
  }

  static Future<List<dynamic>> fetchLatestAnime({int page = 1}) async {
    try {
      return await SourceRegistry.latestAnime(page: page);
    } catch (e) {
      throw ApiException('Failed to load latest anime: ${e.toString()}');
    }
  }

  static Future<dynamic> fetchAnimeDetails(String url) async {
    try {
      final sourced = await SourceRegistry.details(url);
      if (sourced != null) return sourced;
      throw ApiException('لم يتم العثور على تفاصيل هذا الأنمي');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to load anime details: ${e.toString()}');
    }
  }

  static Future<dynamic> fetchEpisodeStreams(String url) async {
    try {
      final sourced = await SourceRegistry.streams(url);
      if (sourced != null) return sourced;
      throw ApiException('تعذر استخراج رابط تشغيل لهذه الحلقة');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to load episode streams: ${e.toString()}');
    }
  }

  static void clearCache() {
    SourceRegistry.clearCache();
  }

  static Future<List<dynamic>> searchAnime(String query) async {
    try {
      return await SourceRegistry.searchAnime(query);
    } catch (e) {
      throw ApiException('Failed to search anime: ${e.toString()}');
    }
  }

  static Future<List<dynamic>> fetchLatestComics({int page = 1}) async {
    try {
      return await SourceRegistry.latestManga(page: page);
    } catch (e) {
      throw ApiException('Failed to load latest comics: ${e.toString()}');
    }
  }

  static Future<dynamic> fetchComicDetails(String url) async {
    try {
      final sourced = await SourceRegistry.details(url);
      if (sourced != null) return sourced;
      throw ApiException('لم يتم العثور على تفاصيل هذه القصة');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to load comic details: ${e.toString()}');
    }
  }

  static Future<List<dynamic>> searchComics(String query) async {
    try {
      return await SourceRegistry.searchManga(query);
    } catch (e) {
      throw ApiException('Failed to search comics: ${e.toString()}');
    }
  }

  static Future<List<dynamic>> fetchLatestMovies({int page = 1}) async {
    try {
      return await SourceRegistry.latestMovies(page: page);
    } catch (e) {
      throw ApiException('تعذر تحميل الأفلام والمسلسلات: $e');
    }
  }

  static Future<List<dynamic>> searchMovies(String query) async {
    try {
      return await SourceRegistry.searchMovies(query);
    } catch (e) {
      throw ApiException('تعذر البحث في الأفلام والمسلسلات: $e');
    }
  }

  static Future<dynamic> fetchMovieDetails(String url) async {
    final sourced = await SourceRegistry.details(url);
    if (sourced != null) return sourced;
    throw ApiException('لم يتم العثور على تفاصيل المحتوى');
  }

  static Future<dynamic> fetchMovieStreams(String url) async {
    final sourced = await SourceRegistry.streams(url);
    if (sourced != null) return sourced;
    throw ApiException('لا توجد سيرفرات تشغيل متاحة');
  }

  static Future<dynamic> fetchChapterImages(String url) async {
    try {
      final sourced = await SourceRegistry.chapterImages(url);
      if (sourced != null) return sourced;
      throw ApiException('تعذر تحميل صور الفصل');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to load chapter images: ${e.toString()}');
    }
  }

  static Future<List<dynamic>> fetchGenres() async {
    return [];
  }

  static Future<dynamic> fetchGenreContent(String genreUrl, {int page = 1}) async {
    return {'content': []};
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Exception? originalError;

  ApiException(this.message, {this.statusCode, this.originalError});

  @override
  String toString() => message;
}
