import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import 'home_screen.dart';
import 'landing_screen.dart';
import 'auth_choice_screen.dart';
import '../theme/app_theme.dart';
import '../providers/app_state_provider.dart';
import '../widgets/auth_ui.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Setup animation
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _controller.forward();

    // Check auth status after animation
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _checkAuthStatus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
    // Initialize AppStateProvider and check login status
    final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
    await appStateProvider.initialize();
    final isLoggedIn = appStateProvider.isLoggedIn;

    // Add a small delay to ensure animation is complete
    await Future.delayed(Duration(milliseconds: 500));

    if (!isLoggedIn) {
      final prefs = await SharedPreferences.getInstance();
      final accepted = prefs.getBool('onboarding_policy_accepted') ?? false;
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => accepted ? const AuthChoiceScreen() : const LandingScreen()),
        );
      }
      return;
    }

    // Let HomeContent load its API sections lazily after the shell appears.
    // The old splash waited for three sequential content requests here.
    _navigateWithPreloadedData(null, null, null);
  }

  void _navigateWithPreloadedData(List<dynamic>? anime, List<dynamic>? comics,
      List<dynamic>? featuredContent) {
    _navigateToHome(anime, comics, featuredContent);
  }

  void _navigateToHome(List<dynamic>? anime, List<dynamic>? comics,
      List<dynamic>? featuredContent) {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            preloadedAnime: anime,
            preloadedComics: comics,
            preloadedFeaturedContent: featuredContent,
            showOfflineNotice: Provider.of<AppStateProvider>(context, listen: false).isOffline,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: AuthPageBackground(child: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Image.asset(
                'assets/images/anitv_logo_transparent.png',
                width: 220,
                height: 104,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 22),
              const Text(
                'AniTV',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'شاهد الأنمي واقرأ المانجا',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondaryColor,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 28),
              // Loading Animation
              Lottie.asset(
                'assets/animations/loading_animation.json',
                width: 64,
                height: 64,
                fit: BoxFit.contain,
              ),
            ],
          ),
        ),
      )),
    );
  }
}
