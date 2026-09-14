import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/update_bottom_sheet.dart';
import '../services/app_version_service.dart';
import 'home_content.dart';
import '../widgets/app_navigation_drawer.dart';

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
        UpdateBottomSheet.show(
          context: context,
          latestVersion: versionData?['version'],
          changelog: changelog,
        );
      });
    } catch (error) {
      debugPrint('Error checking for app update: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.systemOverlay,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        drawer: const AppNavigationDrawer(),
        body: HomeContent(
          preloadedAnime: widget.preloadedAnime,
          preloadedComics: widget.preloadedComics,
          preloadedFeaturedContent: widget.preloadedFeaturedContent,
        ),
      ),
    );
  }
}
