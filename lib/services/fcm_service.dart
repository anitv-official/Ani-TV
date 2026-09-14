import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'appwrite_service.dart';

/// Handles device messaging only; Appwrite remains the application's auth/backend.
class FcmService {
  FcmService._();

  static final FcmService instance = FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final AppwriteService _appwrite = AppwriteService.instance;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  String? _userId;
  String? _token;
  bool _initialized = false;

  String? get token => _token;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    _token = await _messaging.getToken();
    if (_token != null && _token!.isNotEmpty) {
      debugPrint('FCM token acquired.');
      await _syncToken();
    }

    _tokenSubscription = _messaging.onTokenRefresh.listen((token) async {
      _token = token;
      debugPrint('FCM token refreshed.');
      await _syncToken();
    });

    _messageSubscription = FirebaseMessaging.onMessage.listen((message) {
      // Notification payloads are displayed by Android when backgrounded.
      // This callback is the foreground delivery path for app-specific handling.
      debugPrint('FCM foreground message received: ${message.messageId}');
    });

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('FCM notification opened: ${message.messageId}');
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('FCM notification opened from terminated state: ${initialMessage.messageId}');
    }
  }

  Future<void> setUser(String? userId) async {
    final previousUserId = _userId;
    if (previousUserId != null && previousUserId != userId && _token != null) {
      try {
        await _appwrite.updateFcmToken(userId: previousUserId, token: '');
      } catch (error) {
        debugPrint('Previous FCM token cleanup failed: $error');
      }
    }
    _userId = userId;
    await _syncToken();
  }

  Future<void> clearUser() async {
    final userId = _userId;
    _userId = null;
    if (userId != null && _token != null) {
      try {
        await _appwrite.updateFcmToken(userId: userId, token: '');
      } catch (error) {
        debugPrint('FCM token cleanup failed: $error');
      }
    }
  }

  Future<void> _syncToken() async {
    final userId = _userId;
    final token = _token;
    if (userId == null || userId.isEmpty || token == null || token.isEmpty) return;
    try {
      await _appwrite.updateFcmToken(userId: userId, token: token);
    } catch (error) {
      // Messaging must not interrupt sign-in or app startup when the optional
      // profile field is unavailable or the network is temporarily offline.
      debugPrint('FCM token sync failed: $error');
    }
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _openedSubscription?.cancel();
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // The native Firebase plugin displays notification payloads in background.
  // Initialize Firebase here for data-only messages and future background work.
  await Firebase.initializeApp();
  debugPrint('FCM background message received: ${message.messageId}');
}
