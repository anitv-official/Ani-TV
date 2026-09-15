import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/news_model.dart';
import '../services/news_service.dart';
import 'app_state_provider.dart';

class NewsProvider extends ChangeNotifier {
  NewsProvider(this.account);
  final AppStateProvider account;
  final NewsService service = NewsService.instance;
  static const _cacheKey = 'anitv_news_cache_v1';
  final List<NewsItem> items = [];
  final List<Map<String, dynamic>> commentsItems = [];
  bool loading = false, loadingMore = false, hasMore = true, offline = false;
  String? error;
  String query = '';
  String category = 'الكل';
  Future<void>? _request;

  List<NewsItem> get visibleItems {
    final q = query.trim().toLowerCase();
    var result = items.where((item) {
      if (category != 'الكل' && category != 'الأحدث' && category != 'الأكثر تفاعلًا' && item.category != category) return false;
      if (q.isEmpty) return true;
      return [item.titleArabic, item.titleOriginal, item.summaryArabic, item.source, item.category, ...item.tags].join(' ').toLowerCase().contains(q);
    }).toList();
    if (category == 'الأكثر تفاعلًا') result.sort((a, b) => (b.likeCount + b.commentCount * 2).compareTo(a.likeCount + a.commentCount * 2));
    return result;
  }

  Future<void> load({bool refresh = false}) async {
    if (_request != null) return _request!;
    if (!refresh && items.isNotEmpty && !hasMore) return;
    final future = _loadInternal(refresh);
    _request = future;
    try { await future; } finally { if (identical(_request, future)) _request = null; }
  }

  Future<void> _loadInternal(bool refresh) async {
    if (refresh) { items.clear(); hasMore = true; }
    if (!hasMore) return;
    if (items.isEmpty) { loading = true; await _readCache(); } else loadingMore = true;
    error = null; offline = false; notifyListeners();
    try {
      final rows = await service.listNews(offset: items.length, category: category, query: query, popular: category == 'الأكثر تفاعلًا');
      final mapped = rows.map((row) => NewsItem.fromMap({'id': row.$id, ...Map<String, dynamic>.from(row.data)})).toList();
      final ids = items.map((e) => e.id).toSet(); items.addAll(mapped.where((e) => ids.add(e.id)));
      final userId = account.userId;
      if (userId != null && items.isNotEmpty) {
        final liked = await service.likedNewsIds(userId, items.map((e) => e.id).toList());
        for (var i = 0; i < items.length; i++) items[i] = items[i].copyWith(likedByMe: liked.contains(items[i].id));
      }
      hasMore = rows.length == NewsService.pageSize;
      await _writeCache();
    } catch (e) {
      offline = true;
      if (items.isEmpty) error = 'تعذر تحميل الأخبار. تحقق من الاتصال وحاول مرة أخرى.';
      if (kDebugMode) debugPrint('News load failed: $e');
    } finally { loading = false; loadingMore = false; notifyListeners(); }
  }

  void setQuery(String value) { query = value.trimLeft(); notifyListeners(); }
  void setCategory(String value) { if (category == value) return; category = value; hasMore = true; items.clear(); notifyListeners(); load(refresh: true); }

  Future<void> toggleLike(NewsItem item) async {
    final userId = account.userId;
    if (userId == null) throw const NewsException('سجّل الدخول للإعجاب.');
    final next = !item.likedByMe;
    final index = items.indexWhere((e) => e.id == item.id);
    if (index < 0) return;
    items[index] = item.copyWith(likedByMe: next, likeCount: (item.likeCount + (next ? 1 : -1)).clamp(0, 1 << 30)); notifyListeners();
    try { await service.toggleLike(userId: userId, newsId: item.id, liked: next); await _writeCache(); } catch (e) { items[index] = item; notifyListeners(); rethrow; }
  }

  Future<List<Map<String, dynamic>>> loadComments(String newsId) async {
    final rows = await service.comments(newsId);
    return rows.map((row) => {'id': row.$id, ...Map<String, dynamic>.from(row.data)}).toList();
  }

  Future<void> addComment(NewsItem item, String text) async {
    final userId = account.userId;
    final value = text.trim();
    if (userId == null) throw const NewsException('سجّل الدخول للتعليق.');
    if (value.isEmpty) throw const NewsException('اكتب تعليقًا أولًا.');
    await service.addComment(userId: userId, username: account.username, displayName: account.displayName, profileImageId: account.profileImageId ?? '', newsId: item.id, text: value);
    final index = items.indexWhere((e) => e.id == item.id);
    if (index >= 0) items[index] = item.copyWith(commentCount: item.commentCount + 1);
    notifyListeners();
  }

  Future<void> deleteComment(String id) async { final userId = account.userId; if (userId == null) throw const NewsException('يجب تسجيل الدخول.'); await service.deleteComment(userId, id); }

  Future<void> _readCache() async {
    if (items.isNotEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return;
    try { final list = jsonDecode(raw); if (list is List) items.addAll(list.whereType<Map>().map((e) => NewsItem.fromMap(Map<String, dynamic>.from(e)))); } catch (_) {}
  }

  Future<void> _writeCache() async { if (items.isEmpty) return; final prefs = await SharedPreferences.getInstance(); await prefs.setString(_cacheKey, jsonEncode(items.take(50).map((e) => e.toMap()).toList())); }
}
