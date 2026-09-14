import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state_provider.dart';
import '../widgets/ui/app_scaffold_header.dart';
import '../widgets/ui/app_search_bar.dart';
import '../widgets/ui/content_card.dart';
import '../widgets/ui/content_grid.dart';
import '../widgets/ui/segmented_toggle.dart';
import '../widgets/ui/state_views.dart';
import '../utils/toast_utils.dart';
import 'anime_details_screen.dart';
import 'comic_details_screen.dart';
import 'explore_screen.dart';
import '../widgets/auth_required_view.dart';

class FavoritesScreen extends StatefulWidget {
  final bool showBackButton;

  const FavoritesScreen({Key? key, this.showBackButton = true}) : super(key: key);

  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  int _currentTabIndex = 0;
  List<dynamic> favoriteAnime = [];
  List<dynamic> favoriteComics = [];
  bool isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppStateProvider>(context, listen: false).initialize();
    });
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => isLoading = true);
    try {
      final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
      await appStateProvider.initialize();
      setState(() {
        favoriteAnime = appStateProvider.favoriteAnime;
        favoriteComics = appStateProvider.favoriteComics;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _removeFavorite(String id, bool isAnime) async {
    try {
      final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
      await appStateProvider.removeFromFavorites(id, isAnime);
      setState(() {
        if (isAnime) {
          favoriteAnime = appStateProvider.favoriteAnime;
        } else {
          favoriteComics = appStateProvider.favoriteComics;
        }
      });
      ToastUtils.show('تمت الإزالة من المفضلة', backgroundColor: AppTheme.primaryColor);
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<AppStateProvider>().isLoggedIn;
    if (!isLoggedIn) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              AppScaffoldHeader(title: 'المفضلة', showBack: widget.showBackButton),
              const Expanded(child: AuthRequiredView(title: 'سجّل الدخول لاستخدام المفضلة', message: 'المفضلة مرتبطة بحسابك ولن يتم حفظ أي شيء أثناء استخدامك كزائر.')),
            ],
          ),
        ),
      );
    }
    List<dynamic> items = _currentTabIndex == 0 ? favoriteAnime : favoriteComics;
    final isAnime = _currentTabIndex == 0;
    if (_searchQuery.isNotEmpty) {
      items = items.where((item) {
        final title = (item['title'] ?? '').toString().toLowerCase();
        return title.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isSearching)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: AppSearchBar(
                  controller: _searchController,
                  autofocus: true,
                  hintText: 'ابحث في المفضلة...',
                  onChanged: (value) => setState(() => _searchQuery = value),
                  onClear: () {
                    setState(() {
                      _isSearching = false;
                      _searchQuery = '';
                      _searchController.clear();
                    });
                  },
                ),
              )
            else
              AppScaffoldHeader(
                title: 'المفضلة',
                showBack: widget.showBackButton,
                actions: [
                  IconButton(
                    tooltip: 'بحث',
                    onPressed: () => setState(() => _isSearching = true),
                    icon: const Icon(Icons.search_rounded),
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SegmentedToggle(
                labels: const ['أنمي', 'مانجا'],
                index: _currentTabIndex,
                onChanged: (i) => setState(() => _currentTabIndex = i),
              ),
            ),
            Expanded(
              child: isLoading
                  ? const LoadingView(message: 'جارٍ تحميل المفضلة...', size: 64)
                  : _buildContent(items, isAnime),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(List<dynamic> items, bool isAnime) {
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.favorite_border_rounded,
        title: 'لا توجد عناصر مفضلة',
        message: isAnime ? 'أضف أنمي إلى المفضلة ليظهر هنا.' : 'أضف مانجا إلى المفضلة ليظهر هنا.',
        actionLabel: 'استكشف المحتوى',
        onAction: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ExploreScreen(initialIsAnime: isAnime)),
          );
        },
      );
    }

    return ContentGrid(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ContentCard(
          title: item['title']?.toString(),
          imageUrl: item['image_url']?.toString(),
          badge: isAnime ? 'أنمي' : item['type']?.toString(),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => isAnime
                    ? AnimeDetailsScreen(url: item['url'])
                    : ComicDetailsScreen(url: item['url'], type: item['type']),
              ),
            ).then((_) => _loadFavorites());
          },
          overlay: Positioned.directional(
            textDirection: Directionality.of(context),
            top: 6,
            end: 6,
            child: Material(
              color: Colors.black.withOpacity(.62),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _removeFavorite(item['id'], isAnime),
                child: const SizedBox(
                  width: 34,
                  height: 34,
                  child: Icon(Icons.delete_outline_rounded, color: Colors.white, size: 18),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
