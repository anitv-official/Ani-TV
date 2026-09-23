import '../providers/app_state_provider.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';
import '../services/anilist_service.dart';
import '../services/tmdb_service.dart';
import '../sources/source_registry.dart';
import 'ai_context_manager.dart';
import 'ai_models.dart';

class AiToolContext {
  final AppStateProvider appState;
  final AiContextSnapshot context;
  const AiToolContext({required this.appState, required this.context});
}

abstract class AiTool {
  String get name;
  String get description;
  Map<String, dynamic> get parameters;
  Future<AiToolResult> execute(
      Map<String, dynamic> arguments, AiToolContext context);

  Map<String, dynamic> get definition => {
        'type': 'function',
        'function': {
          'name': name,
          'description': description,
          'parameters': parameters,
        },
      };
}

class AiToolRegistry {
  final List<AiTool> tools;
  AiToolRegistry({List<AiTool>? tools}) : tools = tools ?? _defaultTools();

  static List<AiTool> _defaultTools() => [
        SearchContentTool(),
        SearchAnimeTool(),
        SearchMangaTool(),
        SearchMovieTool(),
        SearchSeriesTool(),
        SearchDramaTool(),
        OpenContentTool(),
        GetContentDetailsTool(),
        SearchEpisodesTool(),
        GetEpisodeTool(),
        SearchChaptersTool(),
        GetChapterTool(),
        GetContinueWatchingTool(),
        GetHistoryTool(),
        PlayContentTool(),
        DownloadContentTool(),
        DownloadEpisodeTool(),
        DownloadChapterTool(),
      ];

  List<Map<String, dynamic>> get definitions =>
      tools.map((tool) => tool.definition).toList();

  Future<AiToolResult> execute(String name, Map<String, dynamic> arguments,
      AiToolContext context) async {
    final tool = tools.where((item) => item.name == name).firstOrNull;
    if (tool == null)
      return const AiToolResult(
          success: false, message: 'الأداة المطلوبة غير متاحة.');
    try {
      return await tool.execute(arguments, context);
    } catch (error) {
      return AiToolResult(success: false, message: 'تعذر تنفيذ الأداة: $error');
    }
  }
}

class SearchContentTool extends AiTool {
  @override
  String get name => 'search_content';
  @override
  String get description =>
      'ابحث عن أنمي أو مانجا أو فيلم أو مسلسل أو دراما في مصادر AniTV الحقيقية.';
  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'query': {'type': 'string'},
          'category': {
            'type': 'string',
            'enum': ['all', 'anime', 'manga', 'movie', 'series', 'drama']
          }
        },
        'required': ['query']
      };
  @override
  Future<AiToolResult> execute(
      Map<String, dynamic> arguments, AiToolContext context) async {
    final query = arguments['query']?.toString().trim() ?? '';
    if (query.isEmpty)
      return const AiToolResult(success: false, message: 'أدخل اسمًا للبحث.');
    final category = arguments['category']?.toString().toLowerCase() ?? 'all';
    final Future<List<dynamic>> localFuture = switch (category) {
      'anime' => ApiService.searchAnime(query),
      'manga' => ApiService.searchComics(query),
      _ => ApiService.searchAll(query),
    };
    List<dynamic> rawItems;
    if (category == 'anime' || category == 'manga') {
      final results = await Future.wait<dynamic>([
        localFuture,
        AniListService.search(query,
            type: category == 'manga' ? 'MANGA' : 'ANIME'),
      ]);
      rawItems = [...results[0] as List, ...results[1] as List];
    } else if (category == 'movie' ||
        category == 'series' ||
        category == 'drama') {
      final results = await Future.wait<dynamic>([
        localFuture,
        TmdbService.search(query, tv: category != 'movie'),
      ]);
      rawItems = [...results[0] as List, ...results[1] as List];
    } else {
      rawItems = await localFuture;
    }
    final items =
        category == 'all' || category == 'anime' || category == 'manga'
            ? rawItems
            : rawItems.where((item) {
                if (item is! Map) return false;
                final kind =
                    (item['category'] ?? item['type'] ?? item['kind'] ?? '')
                        .toString()
                        .toLowerCase();
                return kind == category ||
                    (category == 'movie' && kind == 'film') ||
                    (category == 'series' && kind == 'tv');
              }).toList();
    return _items(
        items,
        items.isEmpty
            ? 'لم أجد نتائج حقيقية لهذا البحث.'
            : 'وجدت ${items.length} نتيجة.');
  }
}

class SearchAnimeTool extends SearchContentTool {
  @override
  String get name => 'search_anime';
  @override
  Future<AiToolResult> execute(
          Map<String, dynamic> arguments, AiToolContext context) =>
      super.execute({...arguments, 'category': 'anime'}, context);
}

class SearchMangaTool extends SearchContentTool {
  @override
  String get name => 'search_manga';
  @override
  Future<AiToolResult> execute(
          Map<String, dynamic> arguments, AiToolContext context) =>
      super.execute({...arguments, 'category': 'manga'}, context);
}

class SearchMovieTool extends SearchContentTool {
  @override
  String get name => 'search_movie';
  @override
  Future<AiToolResult> execute(
          Map<String, dynamic> arguments, AiToolContext context) =>
      super.execute({...arguments, 'category': 'movie'}, context);
}

class SearchSeriesTool extends SearchContentTool {
  @override
  String get name => 'search_series';
  @override
  Future<AiToolResult> execute(
          Map<String, dynamic> arguments, AiToolContext context) =>
      super.execute({...arguments, 'category': 'series'}, context);
}

class SearchDramaTool extends SearchContentTool {
  @override
  String get name => 'search_drama';
  @override
  Future<AiToolResult> execute(
          Map<String, dynamic> arguments, AiToolContext context) =>
      super.execute({...arguments, 'category': 'drama'}, context);
}

class OpenContentTool extends GetContentDetailsTool {
  @override
  String get name => 'open_content';
}

class GetContentDetailsTool extends AiTool {
  @override
  String get name => 'get_content_details';
  @override
  String get description =>
      'احصل على تفاصيل حقيقية لعنصر من نتيجة البحث باستخدام الرابط أو المعرف المتاح.';
  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'url': {'type': 'string'}
        },
        'required': ['url']
      };
  @override
  Future<AiToolResult> execute(
      Map<String, dynamic> arguments, AiToolContext context) async {
    final url = arguments['url']?.toString().trim() ?? '';
    if (url.isEmpty)
      return const AiToolResult(
          success: false, message: 'رابط المحتوى غير موجود.');
    final details = await SourceRegistry.details(url);
    if (details == null)
      return const AiToolResult(
          success: false, message: 'المصدر لا يدعم تفاصيل هذا المحتوى.');
    return AiToolResult(
        success: true,
        message: 'تم تحميل التفاصيل.',
        data: Map<String, dynamic>.from(details),
        action: AiAction(type: 'open_content', payload: {
          'url': url,
          'category': details['category'] ?? details['type'] ?? 'anime'
        }));
  }
}

class SearchEpisodesTool extends AiTool {
  @override
  String get name => 'search_episodes';
  @override
  String get description => 'ابحث داخل الحلقات الحقيقية لعنصر تفاصيل معروف.';
  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'content_url': {'type': 'string'},
          'query': {'type': 'string'}
        },
        'required': ['content_url', 'query']
      };
  @override
  Future<AiToolResult> execute(
      Map<String, dynamic> arguments, AiToolContext context) async {
    final url = arguments['content_url']?.toString().trim() ?? '';
    final query = arguments['query']?.toString().trim().toLowerCase() ?? '';
    if (url.isEmpty || query.isEmpty)
      return const AiToolResult(
          success: false, message: 'رابط المحتوى ورقم الحلقة مطلوبان.');
    final details = await SourceRegistry.details(url);
    final cover = (details?['cover_url'] ??
            details?['poster'] ??
            details?['image'] ??
            details?['thumbnail'] ??
            '')
        .toString();
    final episodes = (details?['episodes'] as List?)
            ?.whereType<Map>()
            .map((item) => {
                  ...Map<String, dynamic>.from(item),
                  if (cover.isNotEmpty) 'cover_url': cover,
                  'content_url': url,
                })
            .where((item) => '${item['title'] ?? ''} ${item['number'] ?? ''}'
                .toLowerCase()
                .contains(query))
            .toList() ??
        [];
    AiAction? action;
    if (episodes.length == 1) {
      final episodeUrl = episodes.first['url']?.toString() ?? '';
      if (episodeUrl.isNotEmpty) {
        try {
          final streams = await ApiService.fetchEpisodeStreams(episodeUrl);
          final direct = (streams['direct_stream_urls'] as List?)
                  ?.whereType<Map>()
                  .map((item) => item['url']?.toString() ?? '')
                  .firstWhere((value) => value.isNotEmpty, orElse: () => '') ??
              '';
          final streamUrl = streams['stream_url']?.toString() ?? direct;
          if (streamUrl.isNotEmpty) {
            action = AiAction(type: 'play_episode', payload: {
              'url': streamUrl,
              'title': episodes.first['title'] ?? 'حلقة',
              'episodeId': episodeUrl,
              'cover_url': cover,
            });
          }
        } catch (_) {}
      }
    }
    return AiToolResult(
        success: episodes.isNotEmpty,
        message: episodes.isEmpty
            ? 'لم أجد هذه الحلقة في البيانات الحقيقية.'
            : 'وجدت الحلقة المطلوبة.',
        items: episodes,
        action: action);
  }
}

class GetEpisodeTool extends SearchEpisodesTool {
  @override
  String get name => 'get_episode';
}

class SearchChaptersTool extends AiTool {
  @override
  String get name => 'search_chapters';
  @override
  String get description => 'ابحث داخل فصول مانجا حقيقية لعنصر تفاصيل معروف.';
  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'content_url': {'type': 'string'},
          'query': {'type': 'string'}
        },
        'required': ['content_url', 'query']
      };
  @override
  Future<AiToolResult> execute(
      Map<String, dynamic> arguments, AiToolContext context) async {
    final url = arguments['content_url']?.toString().trim() ?? '';
    final query = arguments['query']?.toString().trim().toLowerCase() ?? '';
    if (url.isEmpty || query.isEmpty)
      return const AiToolResult(
          success: false, message: 'رابط المانجا ورقم الفصل مطلوبان.');
    final details = await SourceRegistry.details(url);
    final chapters = (details?['chapters'] as List?)
            ?.whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((item) =>
                '${item['title'] ?? ''} ${item['number'] ?? item['chapter_number'] ?? ''}'
                    .toLowerCase()
                    .contains(query))
            .toList() ??
        [];
    return _items(
        chapters,
        chapters.isEmpty
            ? 'لم أجد هذا الفصل في البيانات الحقيقية.'
            : 'وجدت الفصل المطلوب.');
  }
}

class GetChapterTool extends SearchChaptersTool {
  @override
  String get name => 'get_chapter';
}

class GetContinueWatchingTool extends AiTool {
  @override
  String get name => 'get_continue_watching';
  @override
  String get description =>
      'اعرض آخر عناصر المشاهدة والقراءة المتوفرة محليًا للمستخدم الحالي.';
  @override
  Map<String, dynamic> get parameters => {'type': 'object', 'properties': {}};
  @override
  Future<AiToolResult> execute(
      Map<String, dynamic> arguments, AiToolContext context) async {
    final items = [
      ...context.appState.animeHistory,
      ...context.appState.comicHistory
    ]
        .take(12)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    return _items(items,
        items.isEmpty ? 'لا يوجد سجل متابعة متاح.' : 'هذه آخر عناصر المتابعة.');
  }
}

class GetHistoryTool extends GetContinueWatchingTool {
  @override
  String get name => 'get_history';
}

class PlayContentTool extends AiTool {
  @override
  String get name => 'play_content';
  @override
  String get description =>
      'جهز فتح محتوى أو حلقة حقيقية في مشغل AniTV الحالي. لا يخترع روابط.';
  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'url': {'type': 'string'},
          'title': {'type': 'string'},
          'episode_id': {'type': 'string'},
          'episode_url': {'type': 'string'}
        },
        'required': ['url', 'title']
      };
  @override
  Future<AiToolResult> execute(
      Map<String, dynamic> arguments, AiToolContext context) async {
    final url = arguments['url']?.toString().trim() ?? '';
    final title = arguments['title']?.toString().trim() ?? 'محتوى';
    if (url.isEmpty || title.isEmpty)
      return const AiToolResult(
          success: false, message: 'لا توجد بيانات حقيقية كافية للتشغيل.');
    final episodeUrl = arguments['episode_url']?.toString().trim() ?? url;
    final streams = await ApiService.fetchEpisodeStreams(episodeUrl);
    final direct =
        (streams['direct_stream_urls'] as List?)?.whereType<Map>().toList() ??
            [];
    final streamUrl = streams['stream_url']?.toString() ??
        (direct.isNotEmpty ? direct.first['url']?.toString() ?? '' : '');
    if (streamUrl.isEmpty)
      return const AiToolResult(
          success: false, message: 'لم يعثر المصدر على رابط تشغيل حقيقي.');
    return AiToolResult(
        success: true,
        message: 'تم تجهيز التشغيل.',
        data: streams,
        action: AiAction(type: 'play_episode', payload: {
          'url': streamUrl,
          'title': title,
          'episodeId': arguments['episode_id']?.toString() ?? episodeUrl,
          'episodeUrl': episodeUrl
        }));
  }
}

class DownloadContentTool extends AiTool {
  @override
  String get name => 'download_content';
  @override
  String get description =>
      'ابدأ تنزيل حلقة أو فصل حقيقي باستخدام DownloadService الحالي.';
  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'kind': {
            'type': 'string',
            'enum': ['episode', 'chapter']
          },
          'title': {'type': 'string'},
          'url': {'type': 'string'},
          'episode': {'type': 'string'},
          'chapter': {'type': 'string'},
          'cover_url': {'type': 'string'},
          'source_id': {'type': 'string'}
        },
        'required': ['kind', 'title', 'url']
      };
  @override
  Future<AiToolResult> execute(
      Map<String, dynamic> arguments, AiToolContext context) async {
    if (!context.appState.isLoggedIn)
      return const AiToolResult(
          success: false, message: 'سجّل الدخول قبل بدء التنزيل.');
    final kind = arguments['kind']?.toString() ?? '';
    final title = arguments['title']?.toString().trim() ?? '';
    final url = arguments['url']?.toString().trim() ?? '';
    if (title.isEmpty || url.isEmpty)
      return const AiToolResult(
          success: false, message: 'بيانات التنزيل غير مكتملة.');
    if (kind == 'episode') {
      final streams = await ApiService.fetchEpisodeStreams(url);
      final direct =
          (streams['direct_stream_urls'] as List?)?.whereType<Map>().toList() ??
              [];
      final streamUrl = streams['stream_url']?.toString() ??
          (direct.isNotEmpty ? direct.first['url']?.toString() ?? '' : '');
      if (streamUrl.isEmpty)
        return const AiToolResult(
            success: false, message: 'لا يوجد رابط فيديو حقيقي للتنزيل.');
      await DownloadService.enqueueMediaDownload(
          taskId: 'ai:${title.hashCode}:${url.hashCode}',
          kind: 'Anime',
          title: title,
          episode: arguments['episode']?.toString() ?? 'حلقة',
          mediaUrl: streamUrl,
          coverUrl: arguments['cover_url']?.toString() ?? '',
          sourceId: arguments['source_id']?.toString() ?? '');
      return const AiToolResult(
          success: true, message: 'بدأ تنزيل الحلقة في صفحة التنزيلات.');
    }
    final chapter = await ApiService.fetchChapterImages(url);
    final imageUrls = (chapter is Map && chapter['images'] is List)
        ? (chapter['images'] as List)
            .whereType<Map>()
            .map((image) => image['url']?.toString().trim() ?? '')
            .where((image) => image.isNotEmpty)
            .toList()
        : <String>[];
    if (imageUrls.isEmpty) {
      return const AiToolResult(
          success: false, message: 'لا توجد صور حقيقية متاحة لهذا الفصل.');
    }
    await DownloadService.saveMangaChapter(
      mangaTitle: title,
      chapterTitle: arguments['chapter']?.toString() ??
          chapter['title']?.toString() ??
          'الفصل',
      imageUrls: imageUrls,
      coverUrl: arguments['cover_url']?.toString() ?? '',
      sourceId: arguments['source_id']?.toString() ?? '',
    );
    return const AiToolResult(
        success: true, message: 'بدأ تنزيل الفصل في صفحة التنزيلات.');
  }
}

class DownloadEpisodeTool extends DownloadContentTool {
  @override
  String get name => 'download_episode';
  @override
  Future<AiToolResult> execute(
          Map<String, dynamic> arguments, AiToolContext context) =>
      super.execute({...arguments, 'kind': 'episode'}, context);
}

class DownloadChapterTool extends DownloadContentTool {
  @override
  String get name => 'download_chapter';
  @override
  Future<AiToolResult> execute(
          Map<String, dynamic> arguments, AiToolContext context) =>
      super.execute({...arguments, 'kind': 'chapter'}, context);
}

AiToolResult _items(Iterable<dynamic> raw, String message) => AiToolResult(
      success: raw.isNotEmpty,
      message: message,
      items: raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
    );
