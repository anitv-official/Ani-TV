import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'screens/password_reset_screen.dart';
import 'theme/app_theme.dart';
import 'providers/app_state_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:flutter/services.dart';
import 'utils/toast_utils.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  WebViewPlatform.instance =
      WebViewPlatform.instance ?? AndroidWebViewPlatform();

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black, // Set to black as requested
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  ));
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: AppTheme.backgroundColor,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'تعذر عرض هذه الصفحة. حاول مرة أخرى.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  };

  runApp(
    ChangeNotifierProvider(
      create: (context) => AppStateProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  String? _lastRecoveryLink;

  @override
  void initState() {
    super.initState();
    _linkSubscription = _appLinks.uriLinkStream.listen(_handleUri);
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleUri(uri);
    });
  }

  void _handleUri(Uri uri) {
    final userId = uri.queryParameters['userId'];
    final secret = uri.queryParameters['secret'];
    if (userId == null || secret == null || userId.isEmpty || secret.isEmpty) return;
    final key = '$userId:$secret';
    if (_lastRecoveryLink == key) return;
    _lastRecoveryLink = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = appNavigatorKey.currentState;
      if (navigator != null) {
        navigator.push(MaterialPageRoute(builder: (_) => PasswordResetScreen(userId: userId, secret: secret)));
      }
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appStateProvider, child) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          scaffoldMessengerKey: ToastUtils.scaffoldMessengerKey,
          title: 'AniTV',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode:
              appStateProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const SplashScreen(),
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
