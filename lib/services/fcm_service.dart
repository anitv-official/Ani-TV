import 'dart:async';

import 'package:appwrite/appwrite.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'appwrite_service.dart';

/// FCM transport plus Appwrite Messaging target/subscriber lifecycle.
class FcmService {
  FcmService._();

  static final FcmService instance = FcmService._();
  static const _topicId = String.fromEnvironment('ANITV_FCM_TOPIC_ID');
  static const _providerId = String.fromEnvironment('ANITV_FCM_PROVIDER_ID');
  static const _targetIdKey = 'anitv_appwrite_push_target_id';
  static const _subscriberIdKey = 'anitv_appwrite_push_subscriber_id';
  static const notificationsEnabledKey = 'notifications_enabled';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final AppwriteService _appwrite = AppwriteService.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  String? _userId;
  String? _token;
  String? _targetId;
  bool _initialized = false;
  bool _enabled = true;
  RemoteMessage? _pendingOpenedMessage;
  void Function(RemoteMessage message)? onNotificationOpened;
  void Function(RemoteMessage message)? onForegroundMessage;
  void Function(Map<String, String> data)? onLocalNotificationOpened;

  String? get token => _token;
  bool get isConfigured => _topicId.isNotEmpty && _providerId.isNotEmpty;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(notificationsEnabledKey) ?? true;
    if (!_enabled) return;

    const channel = AndroidNotificationChannel('anitv_general', 'AniTV Notifications', description: 'General AniTV updates', importance: Importance.high);
    await _localNotifications.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('launcher_icon')),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        final data = <String, String>{};
        for (final part in payload.split('&')) {
          final index = part.indexOf('=');
          if (index <= 0) continue;
          data[Uri.decodeComponent(part.substring(0, index))] = Uri.decodeComponent(part.substring(index + 1));
        }
        if (data['type']?.isNotEmpty == true && data['url']?.isNotEmpty == true) {
          onLocalNotificationOpened?.call(data);
        }
      },
    );
    await _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);

    await _messaging.requestPermission(alert: true, badge: true, sound: true, provisional: false);
    _token = await _messaging.getToken();
    await _syncTarget();
    _tokenSubscription = _messaging.onTokenRefresh.listen((token) async {
      _token = token;
      await _syncTarget();
    });
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    _messageSubscription = FirebaseMessaging.onMessage.listen((message) async {
      await _showForegroundNotification(message);
      onForegroundMessage?.call(message);
    });
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(_deliverOpenedMessage);
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _deliverOpenedMessage(initialMessage);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (!_enabled) return;
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['message']?.toString() ?? message.data['body']?.toString();
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) return;
    await _localNotifications.show(
      message.hashCode,
      title ?? 'AniTV',
      body,
      const NotificationDetails(android: AndroidNotificationDetails('anitv_general', 'AniTV Notifications', channelDescription: 'General AniTV updates', importance: Importance.high, priority: Priority.high, icon: 'launcher_icon')),
      payload: _encodePayload(message.data),
    );
  }

  RemoteMessage? takePendingOpenedMessage() {
    final message = _pendingOpenedMessage;
    _pendingOpenedMessage = null;
    return message;
  }

  void _deliverOpenedMessage(RemoteMessage message) {
    final callback = onNotificationOpened;
    if (callback == null) {
      _pendingOpenedMessage = message;
    } else {
      callback(message);
    }
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    _enabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(notificationsEnabledKey, enabled);
    if (!enabled) return;
    await _messaging.requestPermission(alert: true, badge: true, sound: true, provisional: false);
    _token ??= await _messaging.getToken();
    await _syncTarget();
  }

  Future<void> setUser(String? userId) async {
    if (_userId != userId && _userId != null) await clearUser();
    _userId = userId;
    await _syncTarget();
  }

  Future<void> clearUser() async {
    final targetId = _targetId;
    _userId = null;
    _targetId = null;
    if (targetId != null && targetId.isNotEmpty) {
      try {
        await _appwrite.deletePushTarget(targetId);
      } catch (error) {
        debugPrint('Push target cleanup failed: $error');
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_targetIdKey);
    await prefs.remove(_subscriberIdKey);
  }

  Future<void> _syncTarget() async {
    if (!_enabled || _userId == null || _token == null || _token!.isEmpty || !isConfigured) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _targetId ??= prefs.getString(_targetIdKey);
      _targetId ??= ID.unique();
      await prefs.setString(_targetIdKey, _targetId!);
      try {
        await _appwrite.updatePushTarget(targetId: _targetId!, identifier: _token!);
      } on AppwriteException catch (error) {
        if (error.code != 404) rethrow;
        await _appwrite.createPushTarget(targetId: _targetId!, identifier: _token!, providerId: _providerId);
      }
      if (_topicId.isNotEmpty) {
        final subscriberId = prefs.getString(_subscriberIdKey) ?? _targetId!;
        await prefs.setString(_subscriberIdKey, subscriberId);
        try {
          await _appwrite.subscribePushTarget(topicId: _topicId, subscriberId: subscriberId, targetId: _targetId!);
        } on AppwriteException catch (error) {
          if (error.code != 409) rethrow;
        }
      }
    } catch (error) {
      debugPrint('Appwrite push target setup failed: $error');
    }
  }

  String _encodePayload(Map<String, dynamic> data) => data.entries
      .where((entry) => entry.value != null)
      .map((entry) => '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value.toString())}')
      .join('&');

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _openedSubscription?.cancel();
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final plugin = FlutterLocalNotificationsPlugin();
  const channel = AndroidNotificationChannel('anitv_general', 'AniTV Notifications', description: 'General AniTV updates', importance: Importance.high);
  await plugin.initialize(const InitializationSettings(android: AndroidInitializationSettings('launcher_icon')));
  await plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
  final title = message.notification?.title ?? message.data['title']?.toString() ?? 'AniTV';
  final body = message.notification?.body ?? message.data['message']?.toString() ?? message.data['body']?.toString();
  if (body == null || body.isEmpty) return;
  final payload = message.data.entries.map((entry) => '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value.toString())}').join('&');
  await plugin.show(message.hashCode, title, body, const NotificationDetails(android: AndroidNotificationDetails('anitv_general', 'AniTV Notifications', channelDescription: 'General AniTV updates', importance: Importance.high, priority: Priority.high, icon: 'launcher_icon')), payload: payload);
}
