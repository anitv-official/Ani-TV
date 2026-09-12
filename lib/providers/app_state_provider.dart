import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/appwrite_service.dart';

class AppStateProvider extends ChangeNotifier {
  // User data is empty until a real authenticated user is available.
  String _username = '';
  String _email = '';
  bool _isLoggedIn = false;
  bool _isDarkMode = true;
  final AppwriteService _appwrite = AppwriteService.instance;
  
  // App data
  List<dynamic> _favoriteAnime = [];
  List<dynamic> _favoriteComics = [];
  List<dynamic> _animeHistory = [];
  List<dynamic> _comicHistory = [];
  bool _isLoading = false;
  String _errorMessage = '';
  
  // Getters
  String get username => _username;
  String get email => _email;
  bool get isLoggedIn => _isLoggedIn;
  bool get isDarkMode => _isDarkMode;
  List<dynamic> get favoriteAnime => _favoriteAnime;
  List<dynamic> get favoriteComics => _favoriteComics;
  List<dynamic> get animeHistory => _animeHistory;
  List<dynamic> get comicHistory => _comicHistory;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  
  // Initialize from SharedPreferences
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _loadUserData();
    await _loadFavorites();
    await _loadHistory();
  }
  
  // User data methods
  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool('dark_mode') ?? true;
      final user = await _appwrite.getCurrentUser();
      _setUserFromAppwrite(user);
      notifyListeners();
    } catch (_) {
      _clearUser();
      _setErrorMessage('تعذر التحقق من جلسة الحساب. حاول مرة أخرى.');
    }
  }

  void _setUserFromAppwrite(dynamic user) {
    if (user == null) {
      _clearUser();
      return;
    }
    _username = (user.name as String?)?.trim() ?? '';
    _email = (user.email as String?)?.trim() ?? '';
    _isLoggedIn = true;
  }

  void _clearUser() {
    _username = '';
    _email = '';
    _isLoggedIn = false;
  }

  Future<void> login({required String email, required String password}) async {
    try {
      final user = await _appwrite.login(email: email, password: password);
      _setUserFromAppwrite(user);
      notifyListeners();
    } catch (_) {
      _clearUser();
      rethrow;
    }
  }

  Future<void> register({required String email, required String password, required String name}) async {
    try {
      final user = await _appwrite.register(email: email, password: password, name: name);
      _setUserFromAppwrite(user);
      notifyListeners();
    } catch (_) {
      _clearUser();
      rethrow;
    }
  }
  
  Future<void> updateUserData({
    String? username,
    String? email,
    bool? isLoggedIn,
    bool? isDarkMode,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (username != null) {
        _username = username;
        await prefs.setString('username', username);
      }
      
      if (email != null) {
        _email = email;
        await prefs.setString('email', email);
      }
      
      if (isLoggedIn != null) {
        _isLoggedIn = isLoggedIn;
        await prefs.setBool('isLoggedIn', isLoggedIn);
      }
      
      if (isDarkMode != null) {
        _isDarkMode = isDarkMode;
        await prefs.setBool('dark_mode', isDarkMode);
      }
      
      notifyListeners();
    } catch (e) {
      _setErrorMessage('تعذر حفظ بيانات الحساب. حاول مرة أخرى.');
    }
  }
  
  Future<void> logout() async {
    try {
      await _appwrite.logout();
      _clearUser();
      notifyListeners();
    } catch (e) {
      _setErrorMessage('تعذر تسجيل الخروج. حاول مرة أخرى.');
      rethrow;
    }
  }

  Future<void> updateProfileName(String name) async {
    final user = await _appwrite.updateName(name);
    _setUserFromAppwrite(user);
    notifyListeners();
  }

  Future<void> updatePassword({required String password, required String oldPassword}) async {
    await _appwrite.updatePassword(password: password, oldPassword: oldPassword);
  }

  Future<void> sendPasswordRecovery(String email) async {
    await _appwrite.sendPasswordRecovery(email, 'https://anitv-manga-lord.vercel.app/reset-password');
  }

  Future<void> completePasswordRecovery({required String userId, required String secret, required String password}) async {
    await _appwrite.completePasswordRecovery(userId: userId, secret: secret, password: password);
  }

  Future<void> pingAppwrite() => _appwrite.ping();

  // Favorites methods
  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final animeJson = prefs.getString('favorite_anime') ?? '[]';
      final comicsJson = prefs.getString('favorite_comics') ?? '[]';
      
      _favoriteAnime = jsonDecode(animeJson);
      _favoriteComics = jsonDecode(comicsJson);
      notifyListeners();
    } catch (e) {
      _setErrorMessage('تعذر تحميل المفضلة. حاول مرة أخرى.');
    }
  }
  
  Future<void> addToFavorites(dynamic item, bool isAnime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = isAnime ? 'favorite_anime' : 'favorite_comics';
      final list = isAnime ? _favoriteAnime : _favoriteComics;
      
      // Check if item already exists
      if (list.any((existingItem) => existingItem['url'] == item['url'])) {
        _setErrorMessage('العنصر موجود بالفعل في المفضلة');
        return;
      }
      
      // Add new item
      final newItem = {
        ...item,
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'type': isAnime ? 'anime' : 'comic',
      };
      
      list.insert(0, newItem);
      
      // Update state and storage
      if (isAnime) {
        _favoriteAnime = list;
      } else {
        _favoriteComics = list;
      }
      
      await prefs.setString(key, jsonEncode(list));
      notifyListeners();
    } catch (e) {
      _setErrorMessage('تعذر الإضافة إلى المفضلة. حاول مرة أخرى.');
    }
  }
  
  Future<void> removeFromFavorites(String id, bool isAnime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = isAnime ? 'favorite_anime' : 'favorite_comics';
      final list = isAnime ? _favoriteAnime : _favoriteComics;
      
      final updatedList = list.where((item) => item['id'] != id).toList();
      
      // Update state and storage
      if (isAnime) {
        _favoriteAnime = updatedList;
      } else {
        _favoriteComics = updatedList;
      }
      
      await prefs.setString(key, jsonEncode(updatedList));
      notifyListeners();
    } catch (e) {
      _setErrorMessage('تعذر إزالة العنصر من المفضلة. حاول مرة أخرى.');
    }
  }
  
  // History methods
  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final animeJson = prefs.getString('anime_history') ?? '[]';
      final comicsJson = prefs.getString('comic_history') ?? '[]';
      
      _animeHistory = jsonDecode(animeJson);
      _comicHistory = jsonDecode(comicsJson);
      notifyListeners();
    } catch (e) {
      _setErrorMessage('تعذر تحميل السجل. حاول مرة أخرى.');
    }
  }
  
  Future<void> addToHistory(dynamic item, bool isAnime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = isAnime ? 'anime_history' : 'comic_history';
      final list = isAnime ? _animeHistory : _comicHistory;
      
      // Remove existing item with same URL
      list.removeWhere((existingItem) => existingItem['url'] == item['url']);
      
      // Add new item at the beginning
      final newItem = {
        ...item,
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'type': isAnime ? 'anime' : 'comic',
        'timestamp': DateTime.now().toString(),
      };
      
      list.insert(0, newItem);
      
      // Limit history to 50 items
      if (list.length > 50) {
        list.removeRange(50, list.length);
      }
      
      // Update state and storage
      if (isAnime) {
        _animeHistory = list;
      } else {
        _comicHistory = list;
      }
      
      await prefs.setString(key, jsonEncode(list));
      notifyListeners();
    } catch (e) {
      _setErrorMessage('تعذر إضافة العنصر إلى السجل. حاول مرة أخرى.');
    }
  }
  
  Future<void> removeFromHistory(String id, bool isAnime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = isAnime ? 'anime_history' : 'comic_history';
      final list = isAnime ? _animeHistory : _comicHistory;
      
      final updatedList = list.where((item) => item['id'] != id).toList();
      
      // Update state and storage
      if (isAnime) {
        _animeHistory = updatedList;
      } else {
        _comicHistory = updatedList;
      }
      
      await prefs.setString(key, jsonEncode(updatedList));
      notifyListeners();
    } catch (e) {
      _setErrorMessage('تعذر إزالة العنصر من السجل. حاول مرة أخرى.');
    }
  }
  
  Future<void> clearHistory(bool isAnime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = isAnime ? 'anime_history' : 'comic_history';
      
      await prefs.setString(key, '[]');
      
      // Update state
      if (isAnime) {
        _animeHistory = [];
      } else {
        _comicHistory = [];
      }
      
      notifyListeners();
    } catch (e) {
      _setErrorMessage('تعذر مسح السجل. حاول مرة أخرى.');
    }
  }
  
  // Loading and error methods
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setErrorMessage(String message) {
    _errorMessage = message;
    notifyListeners();
  }
  
  void clearErrorMessage() {
    _errorMessage = '';
    notifyListeners();
  }
}
