import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_error_dialog.dart';
import '../providers/app_state_provider.dart';
import '../widgets/ui/app_fixed_header.dart';
import '../widgets/app_navigation_drawer.dart';
import '../widgets/ui/app_search_bar.dart';
import '../widgets/ui/content_card.dart';
import '../widgets/ui/content_grid.dart';
import '../widgets/ui/segmented_toggle.dart';
import '../widgets/ui/state_views.dart';
import '../sources/source_registry.dart';
import 'anime_details_screen.dart';
import 'comic_details_screen.dart';
import 'search_screen.dart';
import 'youtube_watch_screen.dart';

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
    if (widget.sourceId == 'aflaam') {
      return ListView(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ContentGrid(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) => ContentCard(
              title: items[index]['title']?.toString() ?? 'بدون عنوان',
              imageUrl: items[index]['image_url']?.toString(),
              badge: items[index]['type']?.toString(),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AnimeDetailsScreen(url: items[index]['url']))),
            ),
          ),
          const SizedBox(height: 18),
          const _ExploreSectionTitle(title: 'YouTube', subtitle: 'فيديوهات YouTube أسفل قائمة الأفلام والمسلسلات'),
          const YouTubeCatalogSection(),
        ],
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

class _ExploreSectionTitle extends StatelessWidget {
  final String title, subtitle;
  const _ExploreSectionTitle({required this.title, required this.subtitle});
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12))]));
}

class YouTubeCatalogSection extends StatefulWidget {
  const YouTubeCatalogSection({super.key});
  @override State<YouTubeCatalogSection> createState() => _YouTubeCatalogSectionState();
}

class _YouTubeCatalogSectionState extends State<YouTubeCatalogSection> {
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> allItems = [];
  bool loading = true, loadingMore = false;
  int page = 1;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load({bool more = false}) async {
    if (more && loadingMore) return;
    setState(() => more ? loadingMore = true : loading = true);
    final result = await SourceRegistry.latestFromSource('youtube', page: more ? page + 1 : 1);
    if (!mounted) return;
    final known = allItems.map((e) => e['url']).toSet();
    final merged = [...allItems, ...result.where((e) => known.add(e['url']))];
    final visibleCount = more ? items.length + 12 : 12;
    setState(() { allItems = merged; items = merged.take(visibleCount).toList(); page = more ? page + 1 : 1; loading = false; loadingMore = false; });
  }
  @override Widget build(BuildContext context) {
    if (loading) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
    return Column(children: [
      ContentGrid(
        shrinkWrap: true,
        columns: 1,
        childAspectRatio: 1.35,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, index) => YouTubeCard(
          item: items[index],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => YouTubeWatchScreen(
                url: items[index]['url'].toString(),
                title: items[index]['title']?.toString() ?? 'YouTube',
              ),
            ),
          ),
        ),
      ),
      TextButton.icon(
        onPressed: (loadingMore || items.length >= allItems.length) ? null : () => _load(more: true),
        icon: loadingMore ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.expand_more),
        label: const Text('تحميل المزيد من YouTube'),
      ),
    ]);
  }
}
