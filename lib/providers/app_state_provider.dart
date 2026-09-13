import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../services/appwrite_service.dart';

class AppStateProvider extends ChangeNotifier {
  String _username = '';
  String _displayName = '';
  String _email = '';
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
  bool _initialized = false;

  String get username => _username;
  String get displayName => _displayName;
  String? get userId => _userId;
  String get email => _email;
  bool get isLoggedIn => _isLoggedIn;
  bool get emailVerified => _emailVerified;
  bool get isDarkMode => _isDarkMode;
  List<dynamic> get favoriteAnime => _favoriteAnime;
  List<dynamic> get favoriteComics => _favoriteComics;
  List<dynamic> get animeHistory => _animeHistory;
  List<dynamic> get comicHistory => _comicHistory;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _loadUserData();
    // Authenticated users are hydrated by _syncAccountFromCloud. Reading the
    // local cache afterwards used to overwrite that cloud snapshot.
    if (!_isLoggedIn) await _loadFavorites();
    await _loadHistory();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool('dark_mode') ?? true;
      final user = await _appwrite.getCurrentUser();
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
      final profile = await _appwrite.ensureProfile(userId: userId, username: _usernameCandidate(userId));
      _profileDocumentId = profile.$id;
      final data = profile.data;
      final cloudName = (data['username'] ?? '').toString().trim();
      if (cloudName.isNotEmpty) _username = cloudName;
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
      'addedAt': data['addedAt'] ?? '',
    };
  }

  void _clearUser() {
    _username = '';
    _displayName = '';
    _email = '';
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
      notifyListeners();
    } catch (_) {
      _clearUser();
      rethrow;
    }
  }

  Future<void> register({required String email, required String password, required String name}) async {
    try {
      final user = await _appwrite.register(email: email, password: password, name: name);
      await _applyAuthenticatedUser(user, syncCloud: false);
      if (_userId != null) {
        final profile = await _appwrite.ensureProfile(userId: _userId!, username: _usernameCandidate(_userId!));
        _profileDocumentId = profile.$id;
        final savedUsername = (profile.data['username'] ?? '').toString().trim();
        if (savedUsername.isNotEmpty) _username = savedUsername;
      }
      notifyListeners();
    } catch (_) {
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
      if (isDarkMode != null) { _isDarkMode = isDarkMode; await prefs.setBool('dark_mode', isDarkMode); }
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
    _displayName = user.name.trim();
    notifyListeners();
  }

  Future<void> updateUsername(String value) async {
    final normalized = value.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(normalized)) {
      throw Exception('Username يجب أن يتكون من 3 إلى 24 حرفًا إنجليزيًا صغيرًا أو رقمًا أو _');
    }
    final documentId = _profileDocumentId;
    if (_userId == null || documentId == null) throw Exception('يجب تسجيل الدخول أولًا');
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
    if (userId == null) return;
    try {
      final oldImageId = _profileImageId;
      final newImageId = await _appwrite.uploadProfileImage(userId: userId, path: path);
      final profile = await _appwrite.ensureProfile(userId: userId, username: _username);
      _profileDocumentId = profile.$id;
      await _appwrite.updateProfile(documentId: profile.$id, username: _username, profileImageId: newImageId);
      _profileImageId = newImageId;
      if (oldImageId != null && oldImageId.isNotEmpty && oldImageId != newImageId) {
        try { await _appwrite.deleteProfileImage(oldImageId); } catch (_) {}
      }
      notifyListeners();
    } catch (_) { _setErrorMessage('تعذر تحديث صورة الملف الشخصي.'); rethrow; }
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
      final newItem = {...Map<String, dynamic>.from(item as Map), 'id': DateTime.now().millisecondsSinceEpoch.toString(), 'type': isAnime ? 'anime' : 'comic'};
      list.insert(0, newItem);
      if (isAnime) { _favoriteAnime = list; } else { _favoriteComics = list; }
      await prefs.setString(_favoritesKey(isAnime ? 'favorite_anime' : 'favorite_comics'), jsonEncode(list));
      notifyListeners();
      // Do not write favorites for a session that has not completed the
      // application's authenticated/verified state.
      final userId = _isLoggedIn ? _userId : null;
      if (userId != null) {
        try {
          final existing = await _appwrite.findFavorite(userId: userId, itemId: itemId);
          if (existing == null) {
            final document = await _appwrite.createFavorite(userId: userId, data: {
              'itemId': itemId, 'title': item['title'] ?? '', 'coverUrl': item['image_url'] ?? item['coverUrl'] ?? '',
              'source': item['source'] ?? '', 'type': isAnime ? 'anime' : 'comic', 'addedAt': DateTime.now().toUtc().toIso8601String(),
            });
            newItem['id'] = document.$id;
            await prefs.setString(_favoritesKey(isAnime ? 'favorite_anime' : 'favorite_comics'), jsonEncode(list));
          }
        } catch (_) {
          debugPrint('Favorite cloud insert failed for $userId/$itemId: $_');
          _setErrorMessage('حُفظت المفضلة محليًا وستتم مزامنتها عند توفر الاتصال.');
        }
      }
    } catch (_) { _setErrorMessage('تعذر الإضافة إلى المفضلة. حاول مرة أخرى.'); }
  }

  Future<void> removeFromFavorites(String id, bool isAnime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = List<dynamic>.from(isAnime ? _favoriteAnime : _favoriteComics);
      final removed = list.firstWhere((item) => item['id'] == id, orElse: () => null);
      list.removeWhere((item) => item['id'] == id);
      if (isAnime) { _favoriteAnime = list; } else { _favoriteComics = list; }
      await prefs.setString(_favoritesKey(isAnime ? 'favorite_anime' : 'favorite_comics'), jsonEncode(list));
      notifyListeners();
      if (_isLoggedIn && _userId != null && removed != null) {
        try {
          final document = await _appwrite.findFavorite(userId: _userId!, itemId: (removed['url'] ?? removed['itemId']).toString());
          if (document != null) await _appwrite.deleteFavorite(document.$id);
        } catch (_) {
          debugPrint('Favorite cloud delete failed for ${_userId}/${removed['itemId'] ?? removed['url']}: $_');
          _setErrorMessage('تمت الإزالة محليًا وتعذر تحديث السحابة مؤقتًا.');
        }
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
