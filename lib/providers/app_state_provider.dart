import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:appwrite/appwrite.dart';
import '../services/appwrite_service.dart';
import '../services/local_cache_service.dart';
import '../services/fcm_service.dart';

class RegistrationResult {
  final bool accountCreated;
  final bool profileSaved;
  final String? warning;

  const RegistrationResult({
    required this.accountCreated,
    required this.profileSaved,
    this.warning,
  });
}

class AppStateProvider extends ChangeNotifier {
  static const _lastUserIdKey = 'anitv_last_authenticated_user_id';
  String _username = '';
  String _displayName = '';
  String _email = '';
  String _birthDate = '';
  String _country = '';
  bool _isLoggedIn = false;
  bool _emailVerified = false;
  bool _isDarkMode = true;
  final AppwriteService _appwrite = AppwriteService.instance;
  final LocalCacheService _cache = LocalCacheService.instance;
  String? _userId;
  String? _profileDocumentId;
  String? _profileImageId;
  Future<Uint8List>? get profileImageBytes => _profileImageId == null || _profileImageId!.isEmpty ? null : _appwrite.profileImageBytes(_profileImageId!);

  List<dynamic> _favoriteAnime = [];
  List<dynamic> _favoriteComics = [];
  List<dynamic> _animeHistory = [];
  List<dynamic> _comicHistory = [];
  bool _isLoading = false;
  bool _isOffline = false;
  String _errorMessage = '';
  Future<void>? _initializationFuture;
  Future<void>? _cloudSyncFuture;
  DateTime? _lastCloudSyncAt;

  String get username => _username;
  String get displayName => _displayName;
  String? get userId => _userId;
  String get email => _email;
  String get birthDate => _birthDate;
  String get country => _country;
  String? get profileImageId => _profileImageId;
  bool get isLoggedIn => _isLoggedIn;
  bool get emailVerified => _emailVerified;
  bool get isDarkMode => _isDarkMode;
  List<dynamic> get favoriteAnime => _favoriteAnime;
  List<dynamic> get favoriteComics => _favoriteComics;
  List<dynamic> get animeHistory => _animeHistory;
  List<dynamic> get comicHistory => _comicHistory;
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  String get errorMessage => _errorMessage;

  Future<void> initialize() {
    final running = _initializationFuture;
    if (running != null) return running;
    final future = _initializeInternal();
    _initializationFuture = future;
    return future;
  }

  Future<void> _initializeInternal() async {
    await _loadUserData();
    // Authenticated users are hydrated by _syncAccountFromCloud. Reading the
    // local cache afterwards used to overwrite that cloud snapshot.
    if (_isLoggedIn) {
      await _loadHistory();
    } else {
      // Guest mode is deliberately stateless: do not hydrate account data
      // from SharedPreferences and do not create a local browsing history.
      _favoriteAnime = [];
      _favoriteComics = [];
      _animeHistory = [];
      _comicHistory = [];
    }
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = await _appwrite.getCurrentUser();
      _isOffline = false;
      final themeScope = user == null ? 'guest' : 'user_${user.$id}';
      _isDarkMode = prefs.getBool('dark_mode_$themeScope') ?? true;
      await _applyAuthenticatedUser(user, syncCloud: false);
      if (_isLoggedIn && _userId != null) await _loadLocalAccountCache(_userId!);
      notifyListeners();
      if (_isLoggedIn) unawaited(_syncAccountFromCloud());
    } catch (error) {
      final prefs = await SharedPreferences.getInstance();
      final cachedUserId = prefs.getString(_lastUserIdKey);
      final errorCode = error is AppwriteException ? (error.code ?? -1) : -1;
      final isNetworkFailure = error is AppwriteException && (errorCode == 0 || errorCode >= 500);
      if (isNetworkFailure && cachedUserId != null && cachedUserId.isNotEmpty) {
        await _loadLocalAccountCache(cachedUserId);
        _userId = cachedUserId;
        _isLoggedIn = true;
        _emailVerified = true;
        _isOffline = true;
        notifyListeners();
        return;
      }
      _clearUser();
      _setErrorMessage('تعذر التحقق من جلسة الحساب. حاول مرة أخرى.');
    }
  }

  Future<void> _applyAuthenticatedUser(dynamic user, {required bool syncCloud}) async {
    if (user == null) {
      _clearUser();
      await FcmService.instance.clearUser();
      return;
    }
    _userId = user.$id as String;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastUserIdKey, _userId!);
    _isOffline = false;
    _displayName = (user.name as String?)?.trim() ?? '';
    _email = (user.email as String?)?.trim() ?? '';
    _emailVerified = user.emailVerification == true;
    _isLoggedIn = _emailVerified;
    if (_isLoggedIn) await FcmService.instance.setUser(_userId);
    if (syncCloud && _emailVerified) await _syncAccountFromCloud();
  }

  Future<void> _loadLocalAccountCache(String userId) async {
    final profile = await _cache.readProfile(userId);
    if (profile != null) {
      final documentId = (profile['profileDocumentId'] ?? '').toString();
      _profileDocumentId = documentId.isEmpty ? null : documentId;
      _username = (profile['username'] ?? _username).toString();
      _displayName = (profile['displayName'] ?? _displayName).toString();
      _birthDate = (profile['birthDate'] ?? '').toString();
      _country = (profile['country'] ?? '').toString();
      _profileImageId = (profile['profileImageId'] ?? '').toString();
    }
    _favoriteAnime = await _cache.readFavorites(userId, 'anime');
    _favoriteComics = await _cache.readFavorites(userId, 'comics');
  }

  Future<void> _syncAccountFromCloud() async {
    final lastSync = _lastCloudSyncAt;
    if (lastSync != null && DateTime.now().toUtc().difference(lastSync) < const Duration(minutes: 5)) return;
    final running = _cloudSyncFuture;
    if (running != null) return running;
    final future = _syncAccountFromCloudInternal();
    _cloudSyncFuture = future;
    try {
      await future;
    } finally {
      if (identical(_cloudSyncFuture, future)) _cloudSyncFuture = null;
    }
  }

  Future<void> _syncAccountFromCloudInternal() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      // OAuth users may not have chosen a username yet. Keep it empty until
      // the user explicitly chooses one; never use displayName as identity.
      final profile = await _appwrite.ensureProfile(userId: userId, username: _username);
      _profileDocumentId = profile.$id;
      await FcmService.instance.setUser(userId);
      final data = profile.data;
      final cloudName = (data['username'] ?? '').toString().trim();
      if (cloudName.isNotEmpty) _username = cloudName;
      _displayName = (data['displayname'] ?? _displayName).toString().trim();
      _birthDate = (data['birthdate'] ?? '').toString();
      _country = (data['country'] ?? '').toString();
      _profileImageId = (data['profileImageId'] ?? '').toString();
      await _cache.writeProfile(userId, {
        'profileDocumentId': _profileDocumentId,
        'username': _username,
        'displayName': _displayName,
        'birthDate': _birthDate,
        'country': _country,
        'profileImageId': _profileImageId,
      });
      await _syncFavoriteQueue(userId);
      final cloudFavorites = await _appwrite.getFavorites(userId);
      final prefs = await SharedPreferences.getInstance();
      final anime = <dynamic>[];
      final comics = <dynamic>[];
      for (final document in cloudFavorites) {
        final item = _favoriteFromDocument(document);
        if (item['type'] == 'anime') {
          anime.add(item);
        } else {
          comics.add(item);
        }
      }
      _favoriteAnime = anime;
      _favoriteComics = comics;
      await prefs.setString(_favoritesKey('favorite_anime'), jsonEncode(anime));
      await prefs.setString(_favoritesKey('favorite_comics'), jsonEncode(comics));
      await _cache.writeFavorites(userId, 'anime', anime);
      await _cache.writeFavorites(userId, 'comics', comics);
      _lastCloudSyncAt = DateTime.now().toUtc();
      notifyListeners();
    } catch (_) {
      debugPrint('Favorites cloud sync failed for current user: $_');
      _setErrorMessage('تعذر مزامنة بياناتك. ستبقى التغييرات محفوظة محليًا.');
    }
  }

  Future<void> _syncFavoriteQueue(String userId) async {
    final queue = await _cache.pendingFavorites(userId);
    if (queue.isEmpty) return;
    final remaining = <Map<String, dynamic>>[];
    for (final operation in queue) {
      try {
        final op = operation['op']?.toString();
        if (op == 'create' && operation['data'] is Map) {
          final data = Map<String, dynamic>.from(operation['data'] as Map);
          final existing = await _appwrite.findFavorite(userId: userId, itemId: data['itemId']?.toString() ?? '', source: data['source']?.toString());
          if (existing == null) await _appwrite.createFavorite(userId: userId, data: data);
        } else if (op == 'delete') {
          final document = await _appwrite.findFavorite(userId: userId, itemId: operation['itemId']?.toString() ?? '', source: operation['source']?.toString());
          if (document != null) await _appwrite.deleteFavorite(userId: userId, documentId: document.$id);
        }
      } catch (_) {
        remaining.add(operation);
      }
    }
    await _cache.writePendingFavorites(userId, remaining);
  }

  String _usernameCandidate(String userId) {
    final base = _displayName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_|_$'), '');
    final safeBase = base.isEmpty ? 'user' : base;
    final suffix = userId.length > 5 ? userId.substring(userId.length - 5).toLowerCase() : userId.toLowerCase();
    final value = '${safeBase}_$suffix';
    return value.length <= 100 ? value : value.substring(0, 100);
  }

  Map<String, dynamic> _favoriteFromDocument(dynamic document) {
    final data = Map<String, dynamic>.from(document.data as Map);
    final itemId = (data['itemId'] ?? '').toString();
    return {
      'id': document.$id,
      'url': itemId,
      'itemId': itemId,
      'title': data['title'] ?? '',
      'image_url': data['coverUrl'] ?? '',
      'coverUrl': data['coverUrl'] ?? '',
      'source': data['source'] ?? '',
      'type': data['type'] ?? 'anime',
      'addAt': data['addAt'] ?? '',
    };
  }

  void _clearUser() {
    _username = '';
    _displayName = '';
    _email = '';
    _birthDate = '';
    _country = '';
    _emailVerified = false;
    _userId = null;
    _profileDocumentId = null;
    _profileImageId = null;
    _isLoggedIn = false;
    _favoriteAnime = [];
    _favoriteComics = [];
    _animeHistory = [];
    _comicHistory = [];
    _lastCloudSyncAt = null;
  }

  Future<void> login({required String email, required String password}) async {
    try {
      final user = await _appwrite.login(email: email, password: password);
      _favoriteAnime = [];
      _favoriteComics = [];
      _animeHistory = [];
      _comicHistory = [];
      await _applyAuthenticatedUser(user, syncCloud: user.emailVerification == true);
      // _applyAuthenticatedUser already hydrates the account from Appwrite.
      // Loading SharedPreferences after that used to overwrite fresh cloud
      // data with an old/empty local snapshot.
      if (_isLoggedIn) await _loadHistory();
      notifyListeners();
    } catch (_) {
      _clearUser();
      rethrow;
    }
  }

  Future<void> loginWithUsername({required String username, required String password}) async {
    try {
      final user = await _appwrite.loginWithUsername(username: username, password: password);
      _favoriteAnime = [];
      _favoriteComics = [];
      _animeHistory = [];
      _comicHistory = [];
      await _applyAuthenticatedUser(user, syncCloud: user.emailVerification == true);
      if (_isLoggedIn) await _loadHistory();
      notifyListeners();
    } catch (_) {
      _clearUser();
      rethrow;
    }
  }

  Future<void> loginWithGoogle() async {
    try {
      final existingUser = await _appwrite.getCurrentUser();
      final user = existingUser ?? await _appwrite.loginWithGoogle();
      _favoriteAnime = [];
      _favoriteComics = [];
      _animeHistory = [];
      _comicHistory = [];
      await _applyAuthenticatedUser(user, syncCloud: user.emailVerification == true);
      if (_isLoggedIn) await _loadHistory();
      notifyListeners();
    } catch (_) {
      _clearUser();
      rethrow;
    }
  }

  Future<RegistrationResult> register({
    required String email,
    required String password,
    required String name,
    required String username,
    required String birthDate,
    required String country,
    String? profileImagePath,
  }) async {
    var accountCreated = false;
    try {
      final normalizedUsername = UsernameValidation.normalize(username);
      if (!UsernameValidation.isValid(normalizedUsername) || !await _appwrite.isUsernameAvailable(normalizedUsername)) {
        throw const UsernameTakenException();
      }
      final user = await _appwrite.register(email: email, password: password, name: name);
      accountCreated = true;
      await _applyAuthenticatedUser(user, syncCloud: false);
      var profileSaved = true;
      String? profileWarning;
      if (_userId != null) {
        try {
          final profile = await _appwrite.ensureProfile(
            userId: _userId!,
            username: normalizedUsername,
            displayName: name,
            birthDate: birthDate,
            country: country,
          );
          _profileDocumentId = profile.$id;
          await FcmService.instance.setUser(_userId);
          final savedUsername = (profile.data['username'] ?? '').toString().trim();
          if (savedUsername.isNotEmpty) _username = savedUsername;
          _displayName = (profile.data['displayname'] ?? name).toString();
          _birthDate = (profile.data['birthdate'] ?? birthDate).toString();
          _country = (profile.data['country'] ?? country).toString();
          if (profileImagePath != null && profileImagePath.trim().isNotEmpty) {
            final imageId = await _appwrite.uploadProfileImage(userId: _userId!, path: profileImagePath);
            await _appwrite.updateProfile(documentId: profile.$id, username: _username, profileImageId: imageId);
            _profileImageId = imageId;
          }
        } catch (error) {
          profileSaved = false;
          profileWarning = 'تم إنشاء الحساب، لكن تعذر حفظ بعض بيانات الملف الشخصي. يمكنك إكمالها لاحقًا.';
          debugPrint('Registration profile step failed after account creation: $error');
        }
      }
      notifyListeners();
      return RegistrationResult(accountCreated: true, profileSaved: profileSaved, warning: profileWarning);
    } on AccountCreatedButSessionUnavailableException catch (error) {
      _clearUser();
      debugPrint('Account created but session could not be opened: ${error.cause}');
      return const RegistrationResult(
        accountCreated: true,
        profileSaved: false,
        warning: 'تم إنشاء الحساب، لكن تعذر تسجيل الدخول تلقائيًا. سجّل الدخول باستخدام بياناتك.',
      );
    } catch (_) {
      if (accountCreated) {
        debugPrint('Registration failed after account creation; preserving account: $_');
      }
      // Never leave the newly-created account session active after the
      // Profile step fails. The Appwrite User is preserved for recovery, but
      // the client must return to a signed-out, retryable state.
      try { await _appwrite.logout(); } catch (cleanupError) { debugPrint('Registration session cleanup failed: $cleanupError'); }
      _clearUser();
      rethrow;
    }
  }

  Future<void> sendEmailVerification() => _appwrite.sendEmailVerification();

  Future<void> confirmEmailVerification({required String userId, required String secret}) async {
    final user = await _appwrite.confirmEmailVerification(userId: userId, secret: secret);
    await _applyAuthenticatedUser(user, syncCloud: true);
    await _loadFavorites();
    notifyListeners();
  }

  Future<void> refreshEmailVerification() async {
    final user = await _appwrite.getCurrentUser();
    if (user == null) return;
    await _applyAuthenticatedUser(user, syncCloud: user.emailVerification == true);
    if (user.emailVerification == true) await _loadFavorites();
    notifyListeners();
  }

  Future<void> updateUserData({String? username, String? email, bool? isLoggedIn, bool? isDarkMode}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (username != null) { _username = username; await prefs.setString('username', username); }
      if (email != null) { _email = email; await prefs.setString('email', email); }
      if (isLoggedIn != null) { _isLoggedIn = isLoggedIn; await prefs.setBool('isLoggedIn', isLoggedIn); }
      if (isDarkMode != null) {
        _isDarkMode = isDarkMode;
        final scope = _userId == null ? 'guest' : 'user_$_userId';
        await prefs.setBool('dark_mode_$scope', isDarkMode);
      }
      notifyListeners();
    } catch (_) { _setErrorMessage('تعذر حفظ بيانات الحساب. حاول مرة أخرى.'); }
  }

  Future<void> logout() async {
    try {
      await FcmService.instance.clearUser();
      await _appwrite.logout();
      _clearUser();
      notifyListeners();
    } catch (_) { _setErrorMessage('تعذر تسجيل الخروج. حاول مرة أخرى.'); rethrow; }
  }

  Future<void> deleteAccount({required String password}) async {
    final userId = _userId;
    if (userId == null || userId.isEmpty || !_isLoggedIn) {
      throw const AccountDeletionException('NO_SESSION');
    }
    await FcmService.instance.clearUser();
    await _appwrite.deleteCurrentAccount(password: password);
    await _cache.clearUserData(userId);
    _clearUser();
    notifyListeners();
  }

  Future<void> updateProfileName(String name) async {
    final user = await _appwrite.updateName(name);
    final documentId = _profileDocumentId;
    if (documentId != null) {
      final profile = await _appwrite.updateProfile(documentId: documentId, username: _username, displayName: name);
      _profileDocumentId = profile.$id;
    }
    _displayName = user.name.trim();
    if (_userId != null) await _writeCurrentProfileCache();
    notifyListeners();
  }

  Future<void> _writeCurrentProfileCache() async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) return;
    await _cache.writeProfile(userId, {
      'profileDocumentId': _profileDocumentId,
      'username': _username,
      'displayName': _displayName,
      'birthDate': _birthDate,
      'country': _country,
      'profileImageId': _profileImageId,
    });
  }

  Future<String> _ensureCurrentProfileId() async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      throw Exception('يجب تسجيل الدخول أولًا');
    }
    if (_profileDocumentId != null && _profileDocumentId!.isNotEmpty) return _profileDocumentId!;
    final profile = await _appwrite.ensureProfile(userId: userId, username: _username);
    _profileDocumentId = profile.$id;
    final cloudName = (profile.data['username'] ?? '').toString().trim();
    if (cloudName.isNotEmpty) _username = cloudName;
    _displayName = (profile.data['displayname'] ?? _displayName).toString().trim();
    _birthDate = (profile.data['birthdate'] ?? _birthDate).toString();
    _country = (profile.data['country'] ?? _country).toString();
    _profileImageId = (profile.data['profileImageId'] ?? '').toString();
    return profile.$id;
  }

  Future<void> updateUsername(String value) async {
    final normalized = value.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(normalized)) {
      throw Exception('Username يجب أن يتكون من 3 إلى 24 حرفًا إنجليزيًا صغيرًا أو رقمًا أو _');
    }
    final documentId = await _ensureCurrentProfileId();
    if (normalized == _username.toLowerCase()) return;
    if (!await _appwrite.isUsernameAvailable(normalized, currentDocumentId: documentId)) {
      throw Exception('Username مستخدم بالفعل، اختر اسمًا آخر');
    }
    await _appwrite.updateUsername(documentId: documentId, username: normalized);
    _username = normalized;
    await _writeCurrentProfileCache();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username_$_userId', normalized);
    notifyListeners();
  }

  Future<void> updateProfileImage(String path) async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) throw Exception('يجب تسجيل الدخول أولًا');
    String? newImageId;
    try {
      final oldImageId = _profileImageId;
      final documentId = await _ensureCurrentProfileId();
      newImageId = await _appwrite.uploadProfileImage(userId: userId, path: path);
      await _appwrite.updateProfile(documentId: documentId, username: _username, profileImageId: newImageId);
      _profileImageId = newImageId;
      await _writeCurrentProfileCache();
      if (oldImageId != null && oldImageId.isNotEmpty && oldImageId != newImageId) {
        try { await _appwrite.deleteProfileImage(oldImageId); } catch (_) {}
      }
      notifyListeners();
    } catch (_) {
      if (newImageId != null && newImageId!.isNotEmpty && newImageId != _profileImageId) {
        try { await _appwrite.deleteProfileImage(newImageId!); } catch (_) {}
      }
      _setErrorMessage('تعذر تحديث صورة الملف الشخصي. تحقق من صلاحية التخزين وحاول مرة أخرى.');
      rethrow;
    }
  }

  Future<void> updatePassword({required String password, required String oldPassword}) async => _appwrite.updatePassword(password: password, oldPassword: oldPassword);
  Future<void> sendPasswordRecovery(String email) async => _appwrite.sendPasswordRecovery(email, 'https://anitv-tau.vercel.app/reset-password');
  Future<void> completePasswordRecovery({required String userId, required String secret, required String password}) async => _appwrite.completePasswordRecovery(userId: userId, secret: secret, password: password);
  Future<void> pingAppwrite() => _appwrite.ping();

  String _favoritesKey(String key) => _userId == null ? key : '${key}_$_userId';
  String _historyKey(String key) => _userId == null ? key : '${key}_$_userId';

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final anime = jsonDecode(prefs.getString(_favoritesKey('favorite_anime')) ?? '[]');
      final comics = jsonDecode(prefs.getString(_favoritesKey('favorite_comics')) ?? '[]');
      _favoriteAnime = anime is List ? List<dynamic>.from(anime) : <dynamic>[];
      _favoriteComics = comics is List ? List<dynamic>.from(comics) : <dynamic>[];
      notifyListeners();
    } catch (_) { _setErrorMessage('تعذر تحميل المفضلة. حاول مرة أخرى.'); }
  }

  Future<void> addToFavorites(dynamic item, bool isAnime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = List<dynamic>.from(isAnime ? _favoriteAnime : _favoriteComics);
      final itemId = (item['url'] ?? item['id'] ?? '').toString();
      if (list.any((existingItem) => (existingItem['url'] ?? existingItem['itemId']) == itemId)) {
        _setErrorMessage('العنصر موجود بالفعل في المفضلة');
        return;
      }
      if (!_isLoggedIn || _userId == null) {
        _setErrorMessage('سجّل الدخول لحفظ المفضلة على حسابك.');
        return;
      }
      final source = (item['source'] ?? '').toString();
      final userId = _userId!;
      final localId = 'local_${DateTime.now().microsecondsSinceEpoch}';
      final newItem = {...Map<String, dynamic>.from(item as Map), 'id': localId, 'type': isAnime ? 'anime' : 'comic'};
      list.insert(0, newItem);
      if (isAnime) { _favoriteAnime = list; } else { _favoriteComics = list; }
      await prefs.setString(_favoritesKey(isAnime ? 'favorite_anime' : 'favorite_comics'), jsonEncode(list));
      await _cache.writeFavorites(userId, isAnime ? 'anime' : 'comics', list);
      notifyListeners();
      try {
        final existing = await _appwrite.findFavorite(userId: userId, itemId: itemId, source: source);
        if (existing != null) {
          final withoutDuplicate = list.where((value) => value['id'] != localId).toList();
          if (isAnime) { _favoriteAnime = withoutDuplicate; } else { _favoriteComics = withoutDuplicate; }
          await prefs.setString(_favoritesKey(isAnime ? 'favorite_anime' : 'favorite_comics'), jsonEncode(withoutDuplicate));
          await _cache.writeFavorites(userId, isAnime ? 'anime' : 'comics', withoutDuplicate);
          notifyListeners();
          return;
        }
        final document = await _appwrite.createFavorite(userId: userId, data: {
        'itemId': itemId, 'title': item['title'] ?? '', 'coverUrl': item['image_url'] ?? item['coverUrl'] ?? '',
        'source': item['source'] ?? '', 'type': isAnime ? 'anime' : 'comic', 'addAt': DateTime.now().toUtc().toIso8601String(),
        });
        final updated = list.map((value) => value is Map && value['id'] == localId ? {...Map<String, dynamic>.from(value), 'id': document.$id} : value).toList();
        if (isAnime) { _favoriteAnime = updated; } else { _favoriteComics = updated; }
        await prefs.setString(_favoritesKey(isAnime ? 'favorite_anime' : 'favorite_comics'), jsonEncode(updated));
        await _cache.writeFavorites(userId, isAnime ? 'anime' : 'comics', updated);
        notifyListeners();
      } catch (_) {
        await _cache.enqueueFavorite(userId, {'op': 'create', 'isAnime': isAnime, 'data': {
          'itemId': itemId, 'title': item['title'] ?? '', 'coverUrl': item['image_url'] ?? item['coverUrl'] ?? '',
          'source': item['source'] ?? '', 'type': isAnime ? 'anime' : 'comic', 'addAt': DateTime.now().toUtc().toIso8601String(),
        }});
        _setErrorMessage('تم حفظ المفضلة محليًا، وستتم مزامنتها عند عودة الاتصال.');
      }
    } catch (_) { _setErrorMessage('تعذر الإضافة إلى المفضلة. حاول مرة أخرى.'); }
  }

  Future<void> removeFromFavorites(String id, bool isAnime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = List<dynamic>.from(isAnime ? _favoriteAnime : _favoriteComics);
      final removed = list.firstWhere((item) => item['id'] == id, orElse: () => null);
      if (!_isLoggedIn || _userId == null || removed == null) return;
      list.removeWhere((item) => item['id'] == id);
      if (isAnime) { _favoriteAnime = list; } else { _favoriteComics = list; }
      await prefs.setString(_favoritesKey(isAnime ? 'favorite_anime' : 'favorite_comics'), jsonEncode(list));
      await _cache.writeFavorites(_userId!, isAnime ? 'anime' : 'comics', list);
      notifyListeners();
      try {
        final document = await _appwrite.findFavorite(
          userId: _userId!,
          itemId: (removed['url'] ?? removed['itemId']).toString(),
          source: (removed['source'] ?? '').toString(),
        );
        if (document != null) await _appwrite.deleteFavorite(userId: _userId!, documentId: document.$id);
      } catch (_) {
        await _cache.enqueueFavorite(_userId!, {'op': 'delete', 'itemId': (removed['url'] ?? removed['itemId']).toString(), 'source': (removed['source'] ?? '').toString()});
        _setErrorMessage('تمت الإزالة محليًا، وستتم مزامنة الحذف عند عودة الاتصال.');
      }
    } catch (_) { _setErrorMessage('تعذر إزالة العنصر من المفضلة. حاول مرة أخرى.'); }
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final anime = jsonDecode(prefs.getString(_historyKey('anime_history')) ?? '[]');
      final comics = jsonDecode(prefs.getString(_historyKey('comic_history')) ?? '[]');
      _animeHistory = anime is List ? List<dynamic>.from(anime) : <dynamic>[];
      _comicHistory = comics is List ? List<dynamic>.from(comics) : <dynamic>[];
      notifyListeners();
    } catch (_) { _setErrorMessage('تعذر تحميل السجل. حاول مرة أخرى.'); }
  }
  Future<void> addToHistory(dynamic item, bool isAnime) async {
    if (!_isLoggedIn) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = isAnime ? 'anime_history' : 'comic_history';
      final list = List<dynamic>.from(isAnime ? _animeHistory : _comicHistory);
      list.removeWhere((existingItem) => existingItem['url'] == item['url']);
      list.insert(0, {...Map<String, dynamic>.from(item as Map), 'id': DateTime.now().millisecondsSinceEpoch.toString(), 'type': isAnime ? 'anime' : 'comic', 'timestamp': DateTime.now().toString()});
      if (list.length > 50) list.removeRange(50, list.length);
      if (isAnime) { _animeHistory = list; } else { _comicHistory = list; }
      await prefs.setString(_historyKey(key), jsonEncode(list)); notifyListeners();
    } catch (_) { _setErrorMessage('تعذر إضافة العنصر إلى السجل. حاول مرة أخرى.'); }
  }
  Future<void> removeFromHistory(String id, bool isAnime) async { await _changeHistory(id, isAnime, false); }
  Future<void> clearHistory(bool isAnime) async { await _changeHistory('', isAnime, true); }
  Future<void> _changeHistory(String id, bool isAnime, bool clear) async {
    try {
      final prefs = await SharedPreferences.getInstance(); final key = isAnime ? 'anime_history' : 'comic_history';
      final list = clear ? <dynamic>[] : List<dynamic>.from(isAnime ? _animeHistory : _comicHistory)..removeWhere((item) => item['id'] == id);
      if (isAnime) { _animeHistory = list; } else { _comicHistory = list; }
      await prefs.setString(_historyKey(key), jsonEncode(list)); notifyListeners();
    } catch (_) { _setErrorMessage(clear ? 'تعذر مسح السجل. حاول مرة أخرى.' : 'تعذر إزالة العنصر من السجل. حاول مرة أخرى.'); }
  }

  void setLoading(bool loading) { _isLoading = loading; notifyListeners(); }
  void _setErrorMessage(String message) { _errorMessage = message; notifyListeners(); }
  void clearErrorMessage() { _errorMessage = ''; notifyListeners(); }
}
