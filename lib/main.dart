import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'screens/password_reset_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/email_verification_screen.dart';
import 'screens/anime_details_screen.dart';
import 'screens/comic_details_screen.dart';
import 'screens/manga_reader_screen.dart';
import 'screens/empty_movies_screen.dart';
import 'theme/app_theme.dart';
import 'l10n/app_strings.dart';
import 'providers/app_state_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'utils/toast_utils.dart';
import 'services/fcm_service.dart';
import 'services/download_service.dart';
import 'community/services/community_backend_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DownloadService.initialize();
  await _initializeCommunityBackend();
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

  // Firebase/FCM is optional infrastructure and must never prevent the app
  // shell from rendering when a device is offline or its push setup is stale.
  unawaited(_initializePushServices());
}

Future<void> _initializeCommunityBackend() async {
  if (CommunityBackend.dataSource != CommunityDataSource.supabase ||
      CommunityBackend.supabaseUrl.isEmpty ||
      CommunityBackend.supabasePublishableKey.isEmpty) return;
  try {
    await Supabase.initialize(
      url: CommunityBackend.supabaseUrl,
      anonKey: CommunityBackend.supabasePublishableKey,
    );
  } catch (error) {
    debugPrint('Community Supabase startup skipped: ${error.runtimeType}');
  }
}

Future<void> _initializePushServices() async {
  try {
    await Firebase.initializeApp();
    await FcmService.instance.initialize();
    if (!kIsWeb && await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  } catch (error) {
    debugPrint('Firebase/FCM startup skipped: $error');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const _deepLinkChannel = MethodChannel('com.anitv.app/deeplink');
  String? _lastRecoveryLink;
  String? _lastVerificationLink;
  String? _lastContentLink;
  bool _verificationInProgress = false;
  bool _facebookCallbackInProgress = false;
  String? _lastFacebookCallback;
  bool _googleCallbackInProgress = false;
  String? _lastGoogleCallback;

  @override
  void initState() {
    super.initState();
    if (Firebase.apps.isNotEmpty) {
      FcmService.instance.onNotificationOpened = _handleNotificationMessage;
      FcmService.instance.onLocalNotificationOpened = _handleNotificationData;
      final pending = FcmService.instance.takePendingOpenedMessage();
      if (pending != null) WidgetsBinding.instance.addPostFrameCallback((_) => _handleNotificationMessage(pending));
    }
    _deepLinkChannel.setMethodCallHandler((call) async {
      if (call.method == 'onLink' && call.arguments is String) _handleUri(Uri.tryParse(call.arguments as String));
      return null;
    });
    _deepLinkChannel.invokeMethod<String>('getInitialLink').then((value) {
      if (value != null) _handleUri(Uri.tryParse(value));
    });
  }

  void _handleNotificationMessage(RemoteMessage message) {
    _handleNotificationData(message.data.map((key, value) => MapEntry(key, value.toString())));
  }

  void _handleNotificationData(Map<String, String> data) {
    final url = (data['url'] ?? data['itemId'])?.toString();
    final type = data['type']?.toString();
    if (url == null || url.isEmpty || type == null) return;
    final source = data['source']?.toLowerCase();
    final normalizedType = type == 'new_content' ? (data['episode'] != null ? 'episode' : 'movie') : type;
    _handleUri(Uri.tryParse('anitv://$normalizedType?url=${Uri.encodeComponent(url)}&source=${Uri.encodeComponent(source ?? '')}'));
  }

  void _handleUri(Uri? uri) {
    if (uri == null) return;
    final userId = uri.queryParameters['userId'];
    final secret = uri.queryParameters['secret'];
    final isFacebookCallback = uri.scheme == 'appwrite-callback-6aa4295900094d600163' && uri.host == 'auth';
    final isGoogleCallback = isFacebookCallback && (uri.path == '/google-success' || uri.path == '/google-failure');
    if (isGoogleCallback) {
      final isSuccess = uri.path == '/google-success';
      final userIdPresent = userId != null && userId.isNotEmpty;
      final secretPresent = secret != null && secret.isNotEmpty;
      if (!isSuccess || !userIdPresent || !secretPresent) {
        final authState = appNavigatorKey.currentContext?.read<AppStateProvider>();
        if (!_googleCallbackInProgress && authState?.isLoggedIn != true && _lastGoogleCallback == null) {
          ToastUtils.show('تعذر إكمال تسجيل الدخول باستخدام Google.', backgroundColor: AppTheme.errorColor);
        }
        return;
      }
      final callbackKey = '$userId:$secret';
      if (_lastGoogleCallback == callbackKey || _googleCallbackInProgress) return;
      _lastGoogleCallback = callbackKey;
      _googleCallbackInProgress = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final context = appNavigatorKey.currentContext;
          final navigator = appNavigatorKey.currentState;
          if (context == null || navigator == null) throw StateError('Navigator unavailable');
          await context.read<AppStateProvider>().completeGoogleLogin(userId: userId, secret: secret);
          navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
        } catch (error) {
          debugPrint('Google OAuth callback failed: ${error.runtimeType}');
          if (appNavigatorKey.currentContext?.read<AppStateProvider>().isLoggedIn != true) {
            ToastUtils.show('تعذر إكمال تسجيل الدخول باستخدام Google.', backgroundColor: AppTheme.errorColor);
          }
          final navigator = appNavigatorKey.currentState;
          if (navigator != null && appNavigatorKey.currentContext?.read<AppStateProvider>().isLoggedIn != true) {
            navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
          }
        } finally {
          _googleCallbackInProgress = false;
        }
      });
      return;
    }
    if (isFacebookCallback) {
      final isSuccess = uri.path == '/success';
      final userIdPresent = userId != null && userId.isNotEmpty;
      final secretPresent = secret != null && secret.isNotEmpty;
      debugPrint('Facebook OAuth callback received = true; userId present = $userIdPresent; secret present = $secretPresent');
      if (!isSuccess || !userIdPresent || !secretPresent) {
        if (_facebookCallbackInProgress || _lastFacebookCallback != null) {
          debugPrint('Facebook OAuth late callback ignored = true');
          return;
        }
        debugPrint('Facebook OAuth callback rejected: success=$isSuccess; userId present=$userIdPresent; secret present=$secretPresent');
        if (appNavigatorKey.currentContext?.read<AppStateProvider>().isLoggedIn == true) return;
        return;
      }
      final callbackKey = '$userId:$secret';
      if (_lastFacebookCallback == callbackKey || _facebookCallbackInProgress) {
        debugPrint('Facebook OAuth duplicate callback ignored = true');
        return;
      }
      _lastFacebookCallback = callbackKey;
      _facebookCallbackInProgress = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final context = appNavigatorKey.currentContext;
          final navigator = appNavigatorKey.currentState;
          if (context == null || navigator == null) throw StateError('Navigator unavailable');
          final provider = context.read<AppStateProvider>();
          await provider.completeFacebookLogin(userId: userId, secret: secret);
          debugPrint('Facebook OAuth createSession success = true');
          navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
        } catch (error) {
          debugPrint('Facebook OAuth createSession success = false; callback processing failed: ${error.runtimeType}');
          final navigator = appNavigatorKey.currentState;
          if (navigator != null && appNavigatorKey.currentContext?.read<AppStateProvider>().isLoggedIn != true) {
            navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
          }
        } finally {
          _facebookCallbackInProgress = false;
        }
      });
      return;
    }
    final isVerificationCallback = (uri.scheme == 'anitv' && uri.host == 'verify-email') ||
        (uri.scheme == 'https' && uri.host == 'anitv-tau.vercel.app' && uri.path == '/verify-email');
    if (isVerificationCallback && userId != null && secret != null && userId.isNotEmpty && secret.isNotEmpty) {
      final key = '$userId:$secret';
      if (_lastVerificationLink == key || _verificationInProgress) return;
      _lastVerificationLink = key;
      _verificationInProgress = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final context = appNavigatorKey.currentContext;
          final navigator = appNavigatorKey.currentState;
          if (context == null || navigator == null) return;
          final provider = context.read<AppStateProvider>();
          await provider.confirmEmailVerification(userId: userId, secret: secret);
          if (provider.emailVerified) {
            navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
            ToastUtils.show('تم تأكيد البريد الإلكتروني بنجاح.', backgroundColor: Colors.green);
          } else {
            navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => EmailVerificationScreen(email: provider.email)), (_) => false);
          }
        } catch (_) {
          final navigator = appNavigatorKey.currentState;
          if (navigator != null) {
            navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
          }
          ToastUtils.show('تعذر تأكيد البريد الإلكتروني. سجّل الدخول وحاول مرة أخرى.', backgroundColor: AppTheme.errorColor);
        } finally {
          _verificationInProgress = false;
        }
      });
      return;
    }
    final isRecoveryCallback = (uri.scheme == 'anitv' && uri.host == 'reset-password') ||
        (uri.scheme == 'https' && uri.host == 'anitv-tau.vercel.app' && uri.path == '/reset-password');
    if (isRecoveryCallback && userId != null && secret != null && userId.isNotEmpty && secret.isNotEmpty) {
      final key = '$userId:$secret';
      if (_lastRecoveryLink == key) return;
      _lastRecoveryLink = key;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navigator = appNavigatorKey.currentState;
        if (navigator != null) {
          navigator.push(MaterialPageRoute(builder: (_) => PasswordResetScreen(userId: userId, secret: secret)));
        }
      });
      return;
    }
    final type = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    final sourceUrl = uri.queryParameters['url'];
    if (sourceUrl == null || sourceUrl.isEmpty || !{'anime', 'episode', 'manga', 'chapter', 'movie', 'series', 'drama'}.contains(type)) return;
    final key = '${type}:$sourceUrl';
    if (_lastContentLink == key) return;
    _lastContentLink = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = appNavigatorKey.currentState;
      if (navigator != null) {
        final Widget destination = switch (type) {
          'movie' || 'series' || 'drama' => const EmptyMoviesScreen(),
          'anime' || 'episode' => AnimeDetailsScreen(url: sourceUrl),
          'manga' => ComicDetailsScreen(url: sourceUrl),
          'chapter' => MangaReaderScreen(url: sourceUrl),
          _ => AnimeDetailsScreen(url: sourceUrl),
        };
        navigator.push(MaterialPageRoute(builder: (_) => destination));
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appStateProvider, child) {
        AppTheme.setPalette(appStateProvider.palette);
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
          locale: appLocale(appStateProvider.languageCode),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => Directionality(
            textDirection: appStateProvider.languageCode == 'en' ? TextDirection.ltr : TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
