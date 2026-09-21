import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_error_dialog.dart';
import '../providers/app_state_provider.dart';
import '../widgets/ui/app_fixed_header.dart';
import '../widgets/app_navigation_drawer.dart';
import '../widgets/ui/content_card.dart';
import '../widgets/ui/content_grid.dart';
import '../widgets/ui/segmented_toggle.dart';
import '../widgets/ui/state_views.dart';
import '../sources/source_registry.dart';
import 'anime_details_screen.dart';
import 'comic_details_screen.dart';

class ExploreScreen extends StatefulWidget {
  final bool initialIsAnime;
  final bool showBackButton;
  final bool embedded;
  final String? sourceId;
  final String? title;

  const ExploreScreen({
    Key? key,
    this.initialIsAnime = true,
    this.showBackButton = true,
    this.embedded = false,
    this.sourceId,
    this.title,
  }) : super(key: key);

  @override
  _ExploreScreenState createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  int _currentTabIndex = 0;
  List<dynamic> latestAnime = [];
  List<dynamic> latestComics = [];
  bool isLoadingContent = true;
  late final ScrollController _scrollController;
  int _animePage = 2;
  int _comicPage = 2;
  bool _loadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _currentTabIndex = widget.initialIsAnime ? 0 : 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppStateProvider>(context, listen: false).initialize();
    });
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_hasMore && _scrollController.hasClients && _scrollController.position.extentAfter < 500) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !mounted) return;
    setState(() => _loadingMore = true);
    try {
      final isAnime = _currentTabIndex == 0;
      final page = (isAnime ? _animePage : _comicPage) + 1;
      final items = await _fetchPage(isAnime: isAnime, page: page);
      if (!mounted) return;
      if (items.isEmpty) {
        setState(() => _hasMore = false);
        return;
      }
      setState(() {
        if (isAnime) {
          _animePage = page;
        } else {
          _comicPage = page;
        }
        final target = isAnime ? latestAnime : latestComics;
        final keys = target.map((e) => e['url'] ?? e['title']).toSet();
        target.addAll(items.where((e) => keys.add(e['url'] ?? e['title'])));
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _loadData() async {
    try {
      if (widget.sourceId != null) {
        final items = await _fetchPage(isAnime: widget.initialIsAnime, page: 1);
        if (!mounted) return;
        setState(() {
          latestAnime = widget.initialIsAnime ? items : [];
          latestComics = widget.initialIsAnime ? [] : items;
          _animePage = 1;
          _comicPage = 1;
          _hasMore = true;
          isLoadingContent = false;
        });
        return;
      }
      final loaded = await Future.wait([
        _fetchPage(isAnime: true, page: 1),
        _fetchPage(isAnime: false, page: 1),
      ]);
      final latestAnimeData = loaded[0];
      final latestComicsData = loaded[1];
      if (mounted) {
        setState(() {
          latestAnime = latestAnimeData;
          latestComics = latestComicsData;
          _animePage = 1;
          _comicPage = 1;
          _hasMore = true;
          isLoadingContent = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoadingContent = false);
        _showErrorDialog('خطأ في التحميل', 'تعذر تحميل المحتوى. حاول مرة أخرى.');
      }
    }
  }

  Future<List<dynamic>> _fetchSourcePage(String sourceId, int page) async {
    return SourceRegistry.latestFromSource(sourceId, page: page);
  }

  Future<List<dynamic>> _fetchPage({required bool isAnime, required int page}) {
    if (widget.sourceId != null) {
      return _fetchSourcePage(widget.sourceId!, page);
    }
    // Anime list is intentionally Anime Slayer only. Manga combines every
    // registered manga API through the internal registry.
    return isAnime
        ? SourceRegistry.latestFromSource('anime_slayer', page: page)
        : SourceRegistry.latestManga(page: page);
  }

  void _showErrorDialog(String title, String message) {
    CustomErrorDialog.show(context, title: title, message: message, onRetry: _loadData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      endDrawer: widget.embedded ? null : const AppNavigationDrawer(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.embedded) AppFixedHeader(title: widget.title ?? 'استكشاف', showBack: widget.showBackButton),
            if (widget.sourceId == null && widget.title == null) Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedToggle(
                labels: const ['أنمي', 'مانجا'],
                index: _currentTabIndex,
                onChanged: (i) => setState(() => _currentTabIndex = i),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.title ?? (_currentTabIndex == 0 ? 'أحدث الأنمي' : 'أحدث المانجا'),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildContentGrid()),
          ],
        ),
      ),
    );
  }

  Widget _buildContentGrid() {
    if (isLoadingContent) {
      return const LoadingView(message: 'جارٍ تحميل المحتوى...', size: 72);
    }
    final items = _currentTabIndex == 0 ? latestAnime : latestComics;
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.explore_off_outlined,
        title: 'لا يوجد محتوى متاح حالياً',
        message: 'حاول التحديث لاحقاً.',
        actionLabel: 'إعادة المحاولة',
        onAction: _loadData,
      );
    }
    return ContentGrid(
      key: const PageStorageKey<String>('explore-content-grid'),
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2)));
        }
        final item = items[index];
        return ContentCard(
          title: item['title']?.toString() ?? 'بدون عنوان',
          imageUrl: item['image_url']?.toString(),
          badge: _currentTabIndex == 1 ? item['type']?.toString() : item['source']?.toString(),
          onTap: () {
            if (_currentTabIndex == 0) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => AnimeDetailsScreen(url: item['url'])));
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ComicDetailsScreen(url: item['url'], type: item['type'])));
            }
          },
        );
      },
    );
  }
}
