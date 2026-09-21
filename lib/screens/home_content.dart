
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../sources/source_registry.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_error_dialog.dart';
import '../widgets/ui/app_search_bar.dart';
import '../widgets/ui/content_card.dart';
import '../widgets/ui/content_grid.dart';
import '../widgets/ui/state_views.dart';
import 'anime_details_screen.dart';
import 'comic_details_screen.dart';
import 'search_screen.dart';
import 'youtube_watch_screen.dart';


class HomeContent extends StatefulWidget {
  final List<dynamic>? preloadedAnime;
  final List<dynamic>? preloadedComics;
  final List<dynamic>? preloadedFeaturedContent;

  const HomeContent({
    Key? key,
    this.preloadedAnime,
    this.preloadedComics,
    this.preloadedFeaturedContent,
  }) : super(key: key);

  @override
  _HomeContentState createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> with AutomaticKeepAliveClientMixin {
  List<dynamic> featuredContent = [];
  List<dynamic> latestAnime = [];
  List<dynamic> latestComics = [];
  List<dynamic> latestDrama = [];
  List<dynamic> latestYouTube = [];
  bool isLoading = true;
  bool _hasError = false;
  int _currentCarouselIndex = 0;
  late final ScrollController _scrollController;
  int _animePage = 1;
  int _comicPage = 1;
  bool _loadingMore = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    if (widget.preloadedAnime != null &&
        widget.preloadedComics != null &&
        widget.preloadedFeaturedContent != null &&
        widget.preloadedAnime!.isNotEmpty &&
        widget.preloadedComics!.isNotEmpty) {
      setState(() {
        latestAnime = widget.preloadedAnime!;
        latestComics = widget.preloadedComics!;
        featuredContent = widget.preloadedFeaturedContent!;
        isLoading = false;
      });
    } else {
      _loadContent();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients && _scrollController.position.extentAfter < 500) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !mounted) return;
    _loadingMore = true;
    try {
      final animePage = _animePage + 1;
      final comicPage = _comicPage + 1;
      final loaded = await Future.wait([
        _safeLatest('anime_slayer', page: animePage),
        _safeLatest('drama_slayer', page: animePage),
        _safeLatest('mangatime', page: comicPage),
      ]);
      if (!mounted) return;
      final anime = loaded[0] as List<dynamic>;
      final drama = loaded[1] as List<dynamic>;
      final comics = loaded[2] as List<dynamic>;
      setState(() {
        if (anime.isNotEmpty) {
          latestAnime = [...latestAnime, ..._uniqueItems(anime, latestAnime)];
          _animePage = animePage;
        }
        if (drama.isNotEmpty) latestDrama = [...latestDrama, ..._uniqueItems(drama, latestDrama)];
        if (comics.isNotEmpty) {
          latestComics = [...latestComics, ..._uniqueItems(comics, latestComics)];
          _comicPage = comicPage;
        }
      });
    } finally {
      _loadingMore = false;
    }
  }

  List<dynamic> _uniqueItems(List<dynamic> incoming, List<dynamic> existing) {
    final keys = existing.map((e) => e['url'] ?? e['title']).toSet();
    return incoming.where((e) => keys.add(e['url'] ?? e['title'])).toList();
  }

  Future<void> _loadContent() async {
    setState(() {
      isLoading = true;
      _hasError = false;
    });
    try {
      final loaded = await Future.wait([
        _safeLatest('anime_slayer'),
        _safeLatest('drama_slayer'),
        _safeLatest('mangatime'),
        _safeLatest('youtube'),
      ]);
      final movies = loaded[0] as List<dynamic>;
      final drama = loaded[1] as List<dynamic>;
      final comics = loaded[2] as List<dynamic>;
      final youtube = loaded[3] as List<dynamic>;

      if (mounted) {
        setState(() {
          final featuredMovies = movies.take(3).map((item) => {...item, 'type': 'anime'}).toList();
          final featuredDrama = drama.take(3).map((item) => {...item, 'type': 'drama'}).toList();
          final featuredComics = comics.take(3).map((item) => {...item, 'type': 'comic'}).toList();
          featuredContent = [...featuredMovies, ...featuredDrama, ...featuredComics];
          latestAnime = movies;
          latestDrama = drama;
          latestComics = comics;
          latestYouTube = youtube;
          _animePage = 1;
          _comicPage = 1;
          isLoading = false;
          _hasError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          _hasError = true;
        });
        _showErrorDialog('خطأ في التحميل', 'تعذر تحميل المحتوى. حاول مرة أخرى.');
      }
    }
  }

  Future<List<Map<String, dynamic>>> _safeLatest(String sourceId, {int page = 1}) async {
    try {
      return await SourceRegistry.latestFromSource(sourceId, page: page);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  void _showErrorDialog(String title, String message) {
    CustomErrorDialog.show(
      context,
      title: title,
      message: message,
      onRetry: _loadContent,
    );
  }

  void _openItem(dynamic item, {required bool isAnime}) {
    final isVideoContent = isAnime || item['type'] == 'anime' || item['type'] == 'drama' || item['category'] == 'drama';
    if (isVideoContent) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => AnimeDetailsScreen(url: item['url'])));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ComicDetailsScreen(url: item['url'], type: item['type'])));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (isLoading) return const LoadingView(message: 'جارٍ تحميل المحتوى...', size: 72);
    if (_hasError && latestAnime.isEmpty && latestComics.isEmpty) {
      return ErrorState(onRetry: _loadContent);
    }

    return RefreshIndicator(
      onRefresh: _loadContent,
      color: AppTheme.primaryColor,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(child: _buildContentGrid()),
          SliverToBoxAdapter(child: SizedBox(height: 24 + MediaQuery.of(context).padding.bottom)),
        ],
      ),
    );
  }

  Widget _buildContentGrid() {
    // Keep the home layout light; the horizontal sections still expose the
    // complete API pages while the expensive grid renders only the first set.
    final items = [...latestAnime, ...latestDrama, ...latestComics].take(24).toList();
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: EmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'لا يوجد محتوى حالياً',
          message: 'حاول التحديث أو تصفح مصدر آخر.',
          actionLabel: 'تحديث',
          onAction: _loadContent,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (featuredContent.isNotEmpty) _buildFeatured(),
        if (latestAnime.isNotEmpty) ...[
          _buildSectionHeader('أحدث الأنمي', 'أحدث الحلقات من Anime Slayer'),
          _buildHorizontal(latestAnime, isAnime: true),
        ],
        if (latestDrama.isNotEmpty) ...[
          _buildSectionHeader('أحدث الدراما', 'مسلسلات وأعمال جديدة'),
          _buildHorizontal(latestDrama, isAnime: true),
        ],
        if (latestComics.isNotEmpty) ...[
          _buildSectionHeader('أحدث المانجا', 'قصص جديدة بانتظارك'),
          _buildHorizontal(latestComics, isAnime: false),
        ],
        if (latestYouTube.isNotEmpty) ...[
          _buildSectionHeader('أحدث YouTube', 'فيديوهات جديدة من YouTube'),
          _buildYouTubeHorizontal(latestYouTube),
        ],
        _buildSectionHeader('كل المحتوى', 'تصفح أحدث الإضافات'),
        ContentGrid(
          shrinkWrap: true,
          columns: 3,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return ContentCard(
              title: item['title']?.toString(),
              imageUrl: (item['image_url'] ?? item['image'])?.toString(),
              badge: item['source']?.toString(),
              onTap: () => _openItem(item, isAnime: true),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
      child: Row(
        children: [
          Container(width: 4, height: 28, decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(8))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ])),
        ],
      ),
    );
  }

  Widget _buildHorizontal(List<dynamic> items, {required bool isAnime}) {
    final visible = items.take(12).toList();
    return HorizontalContentList(
      height: 222,
      itemWidth: 132,
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final item = visible[index];
        return ContentCard(
          title: item['title']?.toString(),
          imageUrl: (item['image_url'] ?? item['image'])?.toString(),
          badge: item['source']?.toString(),
          onTap: () => _openItem(item, isAnime: isAnime),
        );
      },
    );
  }

  Widget _buildYouTubeHorizontal(List<dynamic> items) {
    final visible = items.take(12).toList();
    return HorizontalContentList(
      height: 222,
      itemWidth: 240,
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final item = visible[index];
        return YouTubeCard(
          item: item,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => YouTubeWatchScreen(url: item['url'].toString(), title: item['title']?.toString() ?? 'YouTube', imageUrl: item['image_url']?.toString() ?? ''))),
        );
      },
    );
  }

  Widget _buildFeatured() {
    final item = featuredContent.first;
    final image = (item['backdrop_url'] ?? item['image_url'] ?? item['image'])?.toString();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
      child: GestureDetector(
        onTap: () => _openItem(item, isAnime: item['type'] != 'comic'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Container(
            height: 210,
            decoration: BoxDecoration(color: AppTheme.surfaceColor, image: image == null ? null : DecorationImage(image: NetworkImage(image), fit: BoxFit.cover)),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.centerRight, end: Alignment.centerLeft, colors: [Color(0xF2080B12), Color(0x99080B12), Colors.transparent])),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: SizedBox(width: 220, child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('اختيار اليوم', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.primaryColor)),
                  const SizedBox(height: 6),
                  Text(item['title']?.toString() ?? 'محتوى مميز', maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text('اضغط للانتقال إلى التفاصيل', style: Theme.of(context).textTheme.bodySmall),
                ])),
              ),
            ),
          ),
        ),
      ),
    );
  }

}
