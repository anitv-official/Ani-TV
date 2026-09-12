import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/app_version_service.dart';
import '../theme/app_theme.dart';
import '../providers/app_state_provider.dart';
import '../widgets/custom_error_dialog.dart';
import '../widgets/update_bottom_sheet.dart';
import '../widgets/ui/app_search_bar.dart';
import '../widgets/ui/content_card.dart';
import '../widgets/ui/content_grid.dart';
import '../widgets/ui/poster_image.dart';
import '../widgets/ui/primary_button.dart';
import '../widgets/ui/section_header.dart';
import '../widgets/ui/segmented_toggle.dart';
import '../widgets/ui/source_badge.dart';
import '../widgets/ui/state_views.dart';
import 'anime_details_screen.dart';
import 'comic_details_screen.dart';
import 'categories_screen.dart';
import 'favorites_screen.dart';
import 'search_screen.dart';
import 'sources_screen.dart';

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
  bool _showAnime = true;
  bool _isUpdateAvailable = false;
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
    _checkForUpdates();
    if (widget.preloadedAnime != null &&
        widget.preloadedComics != null &&
        widget.preloadedFeaturedContent != null) {
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
                    'type': 'anime',
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

  Future<void> _checkForUpdates() async {
    try {
      final available = await AppVersionService.isUpdateAvailable();
      if (mounted) setState(() => _isUpdateAvailable = available);
    } catch (_) {}
  }

  void _showUpdateSheet() async {
    final versionData = await AppVersionService.getAppVersion();
    final changelog = await AppVersionService.getChangelog();
    final latestVersion = versionData?['version'];
    if (mounted) {
      UpdateBottomSheet.show(
        context: context,
        latestVersion: latestVersion,
        changelog: changelog,
      );
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
    if (isAnime || item['type'] == 'anime') {
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
          SliverToBoxAdapter(child: _buildHeroSection()),
          SliverToBoxAdapter(child: _buildQuickActions()),
          SliverToBoxAdapter(
            child: SourceSummary(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SourcesScreen())),
            ),
          ),
          SliverToBoxAdapter(child: _buildContinueSection()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SegmentedToggle(
                labels: const ['أنمي', 'مانجا'],
                index: _showAnime ? 0 : 1,
                onChanged: (i) => setState(() => _showAnime = i == 0),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SectionHeader(
              title: _showAnime ? 'أحدث الأنمي' : 'أحدث المانجا',
            ),
          ),
          SliverToBoxAdapter(child: _buildContentGrid()),
          SliverToBoxAdapter(child: SizedBox(height: 24 + MediaQuery.of(context).padding.bottom)),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    final screenHeight = MediaQuery.of(context).size.height;
    final heroHeight = (screenHeight * 0.42).clamp(280.0, 420.0);
    final item = featuredContent.isEmpty ? null : featuredContent[_currentCarouselIndex];

    return SizedBox(
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (featuredContent.isNotEmpty)
            CarouselSlider(
              options: CarouselOptions(
                height: heroHeight,
                viewportFraction: 1.0,
                autoPlay: true,
                autoPlayInterval: const Duration(seconds: 5),
                onPageChanged: (index, reason) => setState(() => _currentCarouselIndex = index),
              ),
              items: featuredContent.map((contentItem) {
                return PosterImage(
                  url: (contentItem['image_url'] ?? '').toString(),
                  borderRadius: BorderRadius.zero,
                  width: double.infinity,
                  height: heroHeight,
                );
              }).toList(),
            )
          else
            Container(color: AppTheme.surfaceColor),
          IgnorePointer(
            child: Container(decoration: BoxDecoration(gradient: AppTheme.heroOverlay)),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('AniTV', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 0.4)),
                      const Spacer(),
                      IconButton(
                        tooltip: 'التحديثات',
                        onPressed: _isUpdateAvailable ? _showUpdateSheet : null,
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              _isUpdateAvailable ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                              color: Colors.white,
                            ),
                            if (_isUpdateAvailable)
                              Positioned(
                                right: -1,
                                top: -1,
                                child: Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.4),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SearchLaunchField(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen(autoFocus: true))),
                  ),
                  const Spacer(),
                  if (item != null) ...[
                    SourceBadge(label: item['type'] == 'comic' ? 'مانجا' : 'أنمي'),
                    const SizedBox(height: 8),
                    Text(
                      item['title'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 1.2),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        PrimaryButton(
                          label: item['type'] == 'comic' ? 'اقرأ الآن' : 'شاهد الآن',
                          icon: item['type'] == 'comic' ? Icons.menu_book_rounded : Icons.play_arrow_rounded,
                          onPressed: () => _openItem(item, isAnime: item['type'] == 'anime'),
                        ),
                        const SizedBox(width: 10),
                        SecondaryButton(
                          label: 'التفاصيل',
                          onPressed: () => _openItem(item, isAnime: item['type'] == 'anime'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          _quickAction(Icons.favorite_rounded, 'المفضلة', () => Navigator.push(context, MaterialPageRoute(builder: (_) => FavoritesScreen()))),
          const SizedBox(width: 10),
          _quickAction(Icons.category_rounded, 'التصنيفات', () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoriesScreen()))),
          const SizedBox(width: 10),
          _quickAction(Icons.hub_outlined, 'المصادر', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SourcesScreen()))),
          const SizedBox(width: 10),
          _quickAction(Icons.search_rounded, 'بحث', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen(autoFocus: true)))),
        ],
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppTheme.primaryColor, size: 20),
                const SizedBox(height: 6),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContinueSection() {
    return Consumer<AppStateProvider>(
      builder: (context, appState, _) {
        final animeItems = appState.animeHistory.take(8).toList();
        final comicItems = appState.comicHistory.take(8).toList();
        if (animeItems.isEmpty && comicItems.isEmpty) return const SizedBox.shrink();
        final items = [
          ...animeItems.map((item) => Map<String, dynamic>.from(item as Map)..['type'] = 'anime'),
          ...comicItems.map((item) => Map<String, dynamic>.from(item as Map)..['type'] = 'comic'),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'متابعة المشاهدة والقراءة',
              actionLabel: 'السجل',
              onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
            ),
            HorizontalContentList(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isAnime = item['type'] == 'anime';
                return ContentCard(
                  title: item['title']?.toString(),
                  imageUrl: (item['image_url'] ?? item['image'])?.toString(),
                  badge: isAnime ? 'أنمي' : 'مانجا',
                  compactTitle: true,
                  onTap: () => _openItem(item, isAnime: isAnime),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildContentGrid() {
    final items = _showAnime ? latestAnime : latestComics;
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
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ContentCard(
          title: item['title']?.toString(),
          imageUrl: item['image_url']?.toString(),
          badge: _showAnime ? item['source']?.toString() : item['type']?.toString(),
          onTap: () => _openItem(item, isAnime: _showAnime),
        );
      },
    );
  }
}
