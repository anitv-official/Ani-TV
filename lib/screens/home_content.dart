
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_error_dialog.dart';
import '../widgets/ui/app_search_bar.dart';
import '../widgets/ui/content_card.dart';
import '../widgets/ui/content_grid.dart';
import '../widgets/ui/state_views.dart';
import 'anime_details_screen.dart';
import 'comic_details_screen.dart';
import 'search_screen.dart';


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
        ApiService.fetchLatestAnime(page: animePage),
        ApiService.fetchLatestComics(page: comicPage),
      ]);
      if (!mounted) return;
      final anime = loaded[0] as List<dynamic>;
      final comics = loaded[1] as List<dynamic>;
      setState(() {
        if (anime.isNotEmpty) {
          latestAnime = [...latestAnime, ..._uniqueItems(anime, latestAnime)];
          _animePage = animePage;
        }
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
        ApiService.fetchLatestAnime(),
        ApiService.fetchLatestComics(),
      ]);
      final anime = loaded[0] as List<dynamic>;
      final comics = loaded[1] as List<dynamic>;
      final topAnime = anime;

      if (mounted) {
        setState(() {
          final featuredAnime = topAnime
              .take(4)
              .map((item) => {
                    ...item,
                    'type': item['type'] ?? 'anime',
                  })
              .toList();
          final featuredComics = comics
              .take(4)
              .map((item) => {
                    ...item,
                    'type': 'comic',
                  })
              .toList();
          // Preserve SourceRegistry priority so Anime Slayer content stays first.
          featuredContent = [...featuredAnime, ...featuredComics];
          latestAnime = anime;
          latestComics = comics;
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
    final items = latestAnime
        .where((item) => item['type'] != 'drama' && item['category'] != 'drama')
        .toList();
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
    return ContentGrid(
      shrinkWrap: true,
      columns: 3,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ContentCard(
          title: item['title']?.toString(),
          imageUrl: (item['image_url'] ?? item['image'])?.toString(),
          onTap: () => _openItem(item, isAnime: true),
        );
      },
    );
  }

}
