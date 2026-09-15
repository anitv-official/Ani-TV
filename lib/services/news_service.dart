import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:appwrite/src/enums.dart' show HttpMethod;
import 'package:flutter/foundation.dart';

import 'appwrite_service.dart';

class NewsService {
  NewsService._();
  static final instance = NewsService._();
  static const newsTableId = 'community_news';
  static const likesTableId = 'news_likes';
  static const commentsTableId = 'news_comments';
  static const reportsTableId = 'news_reports';
  static const pageSize = 20;
  final _appwrite = AppwriteService.instance;

  String _rowsPath(String table, [String? row]) => '/tablesdb/${AppwriteService.databaseId}/tables/$table/rows${row == null ? '' : '/$row'}';

  Future<Response> _call(HttpMethod method, String path, {Map<String, dynamic> params = const {}}) async {
    try {
      return await _appwrite.client.call(method, path: path, params: params, headers: method == HttpMethod.get || method == HttpMethod.delete ? const {} : const {'content-type': 'application/json'});
    } on AppwriteException catch (e) {
      debugPrint('News Appwrite error: ${e.code} ${e.type} ${e.message}');
      rethrow;
    }
  }

  models.Document _document(Map<String, dynamic> row, String table) => models.Document.fromMap({...row, r'$collectionId': table, r'$databaseId': AppwriteService.databaseId, r'$permissions': row[r'$permissions'] ?? <String>[]});
  List<models.Document> _rows(dynamic data, String table) {
    if (data is! Map || data['rows'] is! List) throw const FormatException('Invalid news rows response');
    return (data['rows'] as List).whereType<Map>().map((r) => _document(Map<String, dynamic>.from(r), table)).toList();
  }

  Future<List<models.Document>> listNews({int offset = 0, String? category, String? query, bool popular = false}) async {
    final queries = <String>[];
    if (category != null && category.isNotEmpty && category != 'الكل' && category != 'الأحدث' && category != 'الأكثر تفاعلًا') queries.add(Query.equal('category', category));
    if (query != null && query.trim().isNotEmpty) queries.add(Query.search('searchText', query.trim()));
    queries.add(popular ? Query.orderDesc('engagementScore') : Query.orderDesc('publishedAt'));
    queries..add(Query.limit(pageSize))..add(Query.offset(offset));
    final response = await _call(HttpMethod.get, _rowsPath(newsTableId), params: {'queries': queries});
    return _rows(response.data, newsTableId);
  }

  Future<models.Document> getNews(String id) async {
    final response = await _call(HttpMethod.get, _rowsPath(newsTableId, id));
    if (response.data is! Map) throw const FormatException('Invalid news response');
    return _document(Map<String, dynamic>.from(response.data as Map), newsTableId);
  }

  Future<List<models.Document>> comments(String newsId, {int offset = 0}) async {
    final response = await _call(HttpMethod.get, _rowsPath(commentsTableId), params: {'queries': [Query.equal('newsId', newsId), Query.orderDesc('createdAt'), Query.limit(pageSize), Query.offset(offset)]});
    return _rows(response.data, commentsTableId);
  }

  Future<Set<String>> likedNewsIds(String userId, List<String> ids) async {
    if (ids.isEmpty) return <String>{};
    final response = await _call(HttpMethod.get, _rowsPath(likesTableId), params: {'queries': [Query.equal('userId', userId), Query.equal('newsId', ids), Query.limit(500)]});
    return _rows(response.data, likesTableId).map((r) => r.data['newsId']?.toString() ?? '').where((e) => e.isNotEmpty).toSet();
  }

  Future<models.Document?> _existingLike(String userId, String newsId) async {
    final response = await _call(HttpMethod.get, _rowsPath(likesTableId), params: {'queries': [Query.equal('userId', userId), Query.equal('newsId', newsId), Query.limit(1)]});
    final rows = _rows(response.data, likesTableId);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> toggleLike({required String userId, required String newsId, required bool liked}) async {
    final current = await _existingLike(userId, newsId);
    if (liked && current == null) {
      await _call(HttpMethod.post, _rowsPath(likesTableId), params: {'rowId': ID.unique(), 'data': {'userId': userId, 'newsId': newsId, 'createdAt': DateTime.now().toUtc().toIso8601String()}, 'permissions': [Permission.read(Role.any()), Permission.delete(Role.user(userId))]});
    } else if (!liked && current != null) {
      await _call(HttpMethod.delete, _rowsPath(likesTableId, current.$id));
    }
  }

  Future<models.Document> addComment({required String userId, required String username, required String displayName, required String profileImageId, required String newsId, required String text}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final response = await _call(HttpMethod.post, _rowsPath(commentsTableId), params: {'rowId': ID.unique(), 'data': {'userId': userId, 'username': username, 'displayName': displayName, 'profileImageId': profileImageId, 'newsId': newsId, 'text': text.trim(), 'createdAt': now, 'updatedAt': now}, 'permissions': [Permission.read(Role.any()), Permission.delete(Role.user(userId))]});
    if (response.data is! Map) throw const FormatException('Invalid comment response');
    return _document(Map<String, dynamic>.from(response.data as Map), commentsTableId);
  }

  Future<void> deleteComment(String userId, String commentId) async {
    final response = await _call(HttpMethod.get, _rowsPath(commentsTableId, commentId));
    if (response.data is! Map || (response.data as Map)['userId']?.toString() != userId) throw const NewsException('لا يمكنك حذف تعليق مستخدم آخر.');
    await _call(HttpMethod.delete, _rowsPath(commentsTableId, commentId));
  }

  Future<void> report({required String userId, required String newsId, required String reason, String details = ''}) async {
    await _call(HttpMethod.post, _rowsPath(reportsTableId), params: {'rowId': ID.unique(), 'data': {'userId': userId, 'newsId': newsId, 'reason': reason, 'details': details.trim(), 'createdAt': DateTime.now().toUtc().toIso8601String()}, 'permissions': [Permission.create(Role.user(userId))]});
  }
}

class NewsException implements Exception {
  final String message;
  const NewsException(this.message);
  @override String toString() => message;
}
