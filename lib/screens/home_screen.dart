import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/update_bottom_sheet.dart';
import '../services/app_version_service.dart';
import '../widgets/app_navigation_drawer.dart';
import '../widgets/app_section.dart';
import '../widgets/ui/app_fixed_header.dart';
import 'home_content.dart';
import 'explore_screen.dart';
import 'favorites_screen.dart';
import 'downloads_screen.dart';
import 'sources_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<dynamic>? preloadedAnime;
  final List<dynamic>? preloadedComics;
  final List<dynamic>? preloadedFeaturedContent;

  const HomeScreen({
    Key? key,
    this.preloadedAnime,
    this.preloadedComics,
    this.preloadedFeaturedContent,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppSection _section = AppSection.latest;

  @override
  void initState() {
    super.initState();
    _checkForAppUpdate();
  }

  Future<void> _checkForAppUpdate() async {
    try {
      final isUpdateAvailable = await AppVersionService.isUpdateAvailable();
      if (!isUpdateAvailable || !mounted) return;
      final versionData = await AppVersionService.getAppVersion();
      final changelog = await AppVersionService.getChangelog();
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        UpdateBottomSheet.show(context: context, latestVersion: versionData?['version'], changelog: changelog);
      });
    } catch (error) {
      debugPrint('Error checking for app update: $error');
    }
  }

  void _selectSection(AppSection section) => setState(() => _section = section);

  Widget _buildSection() {
    switch (_section) {
      case AppSection.latest:
        return HomeContent(
          preloadedAnime: widget.preloadedAnime,
          preloadedComics: widget.preloadedComics,
          preloadedFeaturedContent: widget.preloadedFeaturedContent,
        );
      case AppSection.anime:
        return const ExploreScreen(initialIsAnime: true, embedded: true);
      case AppSection.manga:
        return const ExploreScreen(initialIsAnime: false, embedded: true);
      case AppSection.favorites:
        return const FavoritesScreen(embedded: true);
      case AppSection.downloads:
        return const DownloadsScreen(embedded: true);
      case AppSection.sources:
        return const SourcesScreen(embedded: true);
      case AppSection.account:
        return ProfileScreen(embedded: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.systemOverlay,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        endDrawer: AppNavigationDrawer(onSectionSelected: _selectSection),
        body: SafeArea(
          child: Column(
            children: [
              const AppFixedHeader(),
              Expanded(child: KeyedSubtree(key: ValueKey(_section), child: _buildSection())),
            ],
          ),
        ),
      ),
    );
  }
}
