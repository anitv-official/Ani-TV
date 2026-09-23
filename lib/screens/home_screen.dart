import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/update_bottom_sheet.dart';
import '../services/app_version_service.dart';
import '../widgets/app_navigation_drawer.dart';
import '../widgets/app_section.dart';
import '../widgets/ui/app_fixed_header.dart';
import '../sources/source_registry.dart';
import 'home_content.dart';
import 'explore_screen.dart';
import 'favorites_screen.dart';
import 'downloads_screen.dart';
import 'sources_screen.dart';
import 'profile_screen.dart';
import 'about_screen.dart';
import 'novel_explore_screen.dart';
import 'extensions_screen.dart';
import 'youtube_screen.dart';
import 'community_screen.dart';
import '../widgets/ai_floating_button.dart';

class HomeScreen extends StatefulWidget {
  final List<dynamic>? preloadedAnime;
  final List<dynamic>? preloadedComics;
  final List<dynamic>? preloadedFeaturedContent;
  final bool showOfflineNotice;

  const HomeScreen({
    Key? key,
    this.preloadedAnime,
    this.preloadedComics,
    this.preloadedFeaturedContent,
    this.showOfflineNotice = false,
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
    if (widget.showOfflineNotice) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showOfflineNotice());
    }
  }

  void _showOfflineNotice() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(children: [
          Icon(Icons.cloud_off_rounded, color: AppTheme.primaryColor),
          SizedBox(width: 10),
          Expanded(
              child: Text('أنت غير متصل بالإنترنت',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800))),
        ]),
        content: Text(
            'يمكنك متابعة المحتوى الذي سبق تنزيله حتى يعود اتصال الإنترنت.',
            style: TextStyle(color: AppTheme.textSecondaryColor, height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('حسنًا')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const DownloadsScreen(embedded: false)));
            },
            icon: const Icon(Icons.download_for_offline_rounded),
            label: const Text('التوجه إلى التنزيلات'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkForAppUpdate() async {
    try {
      final isUpdateAvailable = await AppVersionService.isUpdateAvailable();
      if (!isUpdateAvailable || !mounted) return;
      final versionData = await AppVersionService.getAppVersion();
      final changelog = await AppVersionService.getChangelog();
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        UpdateBottomSheet.show(
            context: context,
            latestVersion: versionData?['version'],
            changelog: changelog);
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
      case AppSection.community:
        return const CommunityScreen(embedded: true);
      case AppSection.anime:
        return const ExploreScreen(
            initialIsAnime: true, embedded: true, title: 'لائحة الأنمي');
      case AppSection.manga:
        return const ExploreScreen(
            initialIsAnime: false, embedded: true, title: 'لائحة المانجا');
      case AppSection.drama:
        return const ExploreScreen(
            initialIsAnime: true,
            embedded: true,
            sourceId: 'drama_slayer',
            title: 'لائحة الدراما');
      case AppSection.movies:
        return const ExploreScreen(
          embedded: true,
          sourceId: 'aflaam',
          title: 'لائحة الأفلام والمسلسلات',
        );
      case AppSection.youtube:
        return const YoutubeScreen(embedded: true);
      case AppSection.novels:
        return const NovelExploreScreen(embedded: true);
      case AppSection.extensions:
        return const ExtensionsScreen(embedded: true);
      case AppSection.favorites:
        return const FavoritesScreen(embedded: true);
      case AppSection.downloads:
        return const DownloadsScreen(embedded: true);
      case AppSection.sources:
        return const SourcesScreen(embedded: true);
      case AppSection.account:
        return ProfileScreen(embedded: true);
      case AppSection.settings:
        return const ProfileScreen(embedded: true, settingsOnly: true);
      case AppSection.about:
        return const AboutScreen(embedded: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.systemOverlay,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        endDrawer: AppNavigationDrawer(
          currentSection: _section,
          onSectionSelected: _selectSection,
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  const AppFixedHeader(),
                  Expanded(
                      child: KeyedSubtree(
                          key: ValueKey(_section), child: _buildSection())),
                ],
              ),
              const AiFloatingButton(),
            ],
          ),
        ),
      ),
    );
  }
}
