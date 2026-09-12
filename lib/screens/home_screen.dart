import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../widgets/custom_side_nav_bar.dart';
import '../widgets/update_bottom_sheet.dart';
import '../services/app_version_service.dart';
import 'home_content.dart';
import 'explore_screen.dart';
import 'favorites_screen.dart';
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
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _currentNavIndex = 0;
  int _previousNavIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(_fadeAnimation);
    _animationController.forward();
    _checkForAppUpdate();
    _pages = [
      HomeContent(
        preloadedAnime: widget.preloadedAnime,
        preloadedComics: widget.preloadedComics,
        preloadedFeaturedContent: widget.preloadedFeaturedContent,
      ),
      ExploreScreen(showBackButton: false),
      FavoritesScreen(showBackButton: false),
      ProfileScreen(),
    ];
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkForAppUpdate() async {
    try {
      final isUpdateAvailable = await AppVersionService.isUpdateAvailable();
      if (isUpdateAvailable && mounted) {
        final versionData = await AppVersionService.getAppVersion();
        final changelog = await AppVersionService.getChangelog();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            UpdateBottomSheet.show(
              context: context,
              latestVersion: versionData?['version'],
              changelog: changelog,
            );
          }
        });
      }
    } catch (e) {
      print('Error checking for app update: $e');
    }
  }

  void _handleNavigation(int index) {
    if (index == _currentNavIndex) return;
    setState(() {
      _previousNavIndex = _currentNavIndex;
      _currentNavIndex = index;
    });
    _animationController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final bodyContent = Stack(
      children: List.generate(_pages.length, (index) {
        final isCurrent = index == _currentNavIndex;
        final isPrevious = index == _previousNavIndex;
        final isAnimating = _animationController.isAnimating;
        final bool isVisible = isCurrent || (isPrevious && isAnimating);
        return Offstage(
          offstage: !isVisible,
          child: TickerMode(
            enabled: isCurrent,
            child: IgnorePointer(
              ignoring: !isCurrent,
              child: Builder(
                builder: (context) {
                  if (isCurrent) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(position: _slideAnimation, child: _pages[index]),
                    );
                  } else if (isPrevious && isAnimating) {
                    return FadeTransition(
                      opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_fadeAnimation),
                      child: _pages[index],
                    );
                  }
                  return _pages[index];
                },
              ),
            ),
          ),
        );
      }),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.systemOverlay,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: isDesktop
            ? Row(
                children: [
                  CustomSideNavBar(currentIndex: _currentNavIndex, onTap: _handleNavigation),
                  Expanded(child: bodyContent),
                ],
              )
            : bodyContent,
        bottomNavigationBar: isDesktop
            ? null
            : CustomBottomNavBar(currentIndex: _currentNavIndex, onTap: _handleNavigation),
      ),
    );
  }
}
