import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../services/appwrite_service.dart';

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
  String _username = '';
  String _displayName = '';
  String _email = '';
  String _birthDate = '';
  String _country = '';
  bool _isLoggedIn = false;
  bool _emailVerified = false;
  bool _isDarkMode = true;
  final AppwriteService _appwrite = AppwriteService.instance;
  String? _userId;
  String? _profileDocumentId;
  String? _profileImageId;
  Future<Uint8List>? get profileImageBytes => _profileImageId == null || _profileImageId!.isEmpty ? null : _appwrite.profileImageBytes(_profileImageId!);

  List<dynamic> _favoriteAnime = [];
  List<dynamic> _favoriteComics = [];
  List<dynamic> _animeHistory = [];
  List<dynamic> _comicHistory = [];
  bool _isLoading = false;
  String _errorMessage = '';
  Future<void>? _initializationFuture;

  String get username => _username;
  String get displayName => _displayName;
  String? get userId => _userId;
  String get email => _email;
  String get birthDate => _birthDate;
  String get country => _country;
  bool get isLoggedIn => _isLoggedIn;
  bool get emailVerified => _emailVerified;
  bool get isDarkMode => _isDarkMode;
  List<dynamic> get favoriteAnime => _favoriteAnime;
  List<dynamic> get favoriteComics => _favoriteComics;
  List<dynamic> get animeHistory => _animeHistory;
  List<dynamic> get comicHistory => _comicHistory;
  bool get isLoading => _isLoading;
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
    if (!_isLoggedIn) await _loadFavorites();
    await _loadHistory();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = await _appwrite.getCurrentUser();
      final themeScope = user == null ? 'guest' : 'user_${user.$id}';
      _isDarkMode = prefs.getBool('dark_mode_$themeScope') ?? true;
      await _applyAuthenticatedUser(user, syncCloud: user != null);
      notifyListeners();
    } catch (_) {
      _clearUser();
      _setErrorMessage('تعذر التحقق من جلسة الحساب. حاول مرة أخرى.');
    }
  }

  Future<void> _applyAuthenticatedUser(dynamic user, {required bool syncCloud}) async {
    if (user == null) {
      _clearUser();
      return;
    }
    _userId = user.$id as String;
    _displayName = (user.name as String?)?.trim() ?? '';
    _email = (user.email as String?)?.trim() ?? '';
    _emailVerified = user.emailVerification == true;
    _isLoggedIn = _emailVerified;
    if (syncCloud && _emailVerified) await _syncAccountFromCloud();
  }

  Future<void> _syncAccountFromCloud() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      // OAuth users may not have chosen a username yet. Keep it empty until
      // the user explicitly chooses one; never use displayName as identity.
      final profile = await _appwrite.ensureProfile(userId: userId, username: _username);
      _profileDocumentId = profile.$id;
      final data = profile.data;
      final cloudName = (data['username'] ?? '').toString().trim();
      if (cloudName.isNotEmpty) _username = cloudName;
      _displayName = (data['displayname'] ?? _displayName).toString().trim();
      _birthDate = (data['birthdate'] ?? '').toString();
      _country = (data['country'] ?? '').toString();
      _profileImageId = (data['profileImageId'] ?? '').toString();
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
    } catch (_) {
      debugPrint('Favorites cloud sync failed for current user: $_');
      _setErrorMessage('تعذر مزامنة بياناتك. ستبقى التغييرات محفوظة محليًا.');
    }
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
    await _appwrite.loginWithGoogle();
  }

  Future<void> completeGoogleLogin({required String userId, required String secret}) async {
    try {
      final user = await _appwrite.completeGoogleLogin(userId: userId, secret: secret);
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
      await _appwrite.logout();
      _clearUser();
      notifyListeners();
    } catch (_) { _setErrorMessage('تعذر تسجيل الخروج. حاول مرة أخرى.'); rethrow; }
  }

  Future<void> updateProfileName(String name) async {
    final user = await _appwrite.updateName(name);
    final documentId = _profileDocumentId;
    if (documentId != null) {
      final profile = await _appwrite.updateProfile(documentId: documentId, username: _username, displayName: name);
      _profileDocumentId = profile.$id;
    }
    _displayName = user.name.trim();
    notifyListeners();
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
  Future<void> sendPasswordRecovery(String email) async => _appwrite.sendPasswordRecovery(email, 'https://anitv-manga-lord.vercel.app/reset-password');
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
      final existing = await _appwrite.findFavorite(userId: _userId!, itemId: itemId, source: source);
      if (existing != null) return;
      final document = await _appwrite.createFavorite(userId: _userId!, data: {
        'itemId': itemId, 'title': item['title'] ?? '', 'coverUrl': item['image_url'] ?? item['coverUrl'] ?? '',
        'source': item['source'] ?? '', 'type': isAnime ? 'anime' : 'comic', 'addAt': DateTime.now().toUtc().toIso8601String(),
      });
      final newItem = {...Map<String, dynamic>.from(item as Map), 'id': document.$id, 'type': isAnime ? 'anime' : 'comic'};
      list.insert(0, newItem);
      if (isAnime) { _favoriteAnime = list; } else { _favoriteComics = list; }
      await prefs.setString(_favoritesKey(isAnime ? 'favorite_anime' : 'favorite_comics'), jsonEncode(list));
      notifyListeners();
    } catch (_) { _setErrorMessage('تعذر الإضافة إلى المفضلة. حاول مرة أخرى.'); }
  }

  Future<void> removeFromFavorites(String id, bool isAnime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = List<dynamic>.from(isAnime ? _favoriteAnime : _favoriteComics);
      final removed = list.firstWhere((item) => item['id'] == id, orElse: () => null);
      if (!_isLoggedIn || _userId == null || removed == null) return;
      final document = await _appwrite.findFavorite(
        userId: _userId!,
        itemId: (removed['url'] ?? removed['itemId']).toString(),
        source: (removed['source'] ?? '').toString(),
      );
      if (document != null) await _appwrite.deleteFavorite(userId: _userId!, documentId: document.$id);
      list.removeWhere((item) => item['id'] == id);
      if (isAnime) { _favoriteAnime = list; } else { _favoriteComics = list; }
      await prefs.setString(_favoritesKey(isAnime ? 'favorite_anime' : 'favorite_comics'), jsonEncode(list));
      notifyListeners();
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
