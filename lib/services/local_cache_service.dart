import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Small, reversible persistence layer for non-secret account data.
///
/// Authentication remains Appwrite-backed. This class never stores passwords,
/// Appwrite session secrets, OAuth data, API keys, or other credentials.
class LocalCacheService {
  LocalCacheService._();
  static final LocalCacheService instance = LocalCacheService._();

  static const Duration profileTtl = Duration(minutes: 15);
  static const Duration favoritesTtl = Duration(minutes: 5);
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  String _scope(String userId) => 'user_${Uri.encodeComponent(userId)}';
  String _key(String userId, String name) => 'cache_${_scope(userId)}_$name';

  Future<Map<String, dynamic>?> readProfile(String userId) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_key(userId, 'profile'));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['userId']?.toString() != userId) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeProfile(String userId, Map<String, dynamic> profile) async {
    final prefs = await _prefs;
    await prefs.setString(_key(userId, 'profile'), jsonEncode({...profile, 'userId': userId, 'cachedAt': DateTime.now().toUtc().toIso8601String()}));
    await prefs.setString(_key(userId, 'profile_cached_at'), DateTime.now().toUtc().toIso8601String());
  }

  Future<bool> isProfileFresh(String userId) async => _isFresh(userId, 'profile_cached_at', profileTtl);

  Future<List<dynamic>> readFavorites(String userId, String type) async => _readList(_key(userId, 'favorites_$type'));

  Future<void> writeFavorites(String userId, String type, List<dynamic> values) async {
    final prefs = await _prefs;
    await prefs.setString(_key(userId, 'favorites_$type'), jsonEncode(values));
    await prefs.setString(_key(userId, 'favorites_cached_at'), DateTime.now().toUtc().toIso8601String());
  }

  Future<bool> areFavoritesFresh(String userId) async => _isFresh(userId, 'favorites_cached_at', favoritesTtl);

  Future<List<Map<String, dynamic>>> pendingFavorites(String userId) async {
    final values = await _readList(_key(userId, 'pending_favorites'));
    return values.whereType<Map>().map((value) => Map<String, dynamic>.from(value)).toList();
  }

  Future<void> writePendingFavorites(String userId, List<Map<String, dynamic>> values) async {
    final prefs = await _prefs;
    await prefs.setString(_key(userId, 'pending_favorites'), jsonEncode(values));
  }

  Future<void> enqueueFavorite(String userId, Map<String, dynamic> operation) async {
    final values = await pendingFavorites(userId);
    values.add({...operation, 'queuedAt': DateTime.now().toUtc().toIso8601String()});
    await writePendingFavorites(userId, values);
  }

  Future<void> clearUserData(String userId) async {
    final prefs = await _prefs;
    final encoded = Uri.encodeComponent(userId);
    final keys = prefs.getKeys().where((key) =>
        key.contains('user_$userId') ||
        key.contains('user_$encoded') ||
        key.endsWith('_$userId'));
    for (final key in keys.toList()) {
      await prefs.remove(key);
    }
    // These legacy keys are account data from older app versions. Do not
    // remove general app settings or local downloads.
    for (final key in <String>[
      'username',
      'email',
      'isLoggedIn',
      'remembered_email',
      'profile_avatar_path_$userId',
      'favorite_anime_$userId',
      'favorite_comics_$userId',
      'anime_history_$userId',
      'comic_history_$userId',
    ]) {
      await prefs.remove(key);
    }
  }

  Future<List<dynamic>> _readList(String key) async {
    final prefs = await _prefs;
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return <dynamic>[];
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? List<dynamic>.from(decoded) : <dynamic>[];
    } catch (_) {
      return <dynamic>[];
    }
  }

  Future<bool> _isFresh(String userId, String name, Duration ttl) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_key(userId, name));
    final timestamp = raw == null ? null : DateTime.tryParse(raw);
    return timestamp != null && DateTime.now().toUtc().difference(timestamp) < ttl;
  }
}
