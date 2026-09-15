import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:appwrite/src/enums.dart' show HttpMethod;
import 'package:flutter/foundation.dart';
import 'appwrite_service.dart';

class CommunityService {
  CommunityService._();
  static final instance = CommunityService._();
  final _appwrite = AppwriteService.instance;
  static const postsTableId = '6aa88e2400270d97fa76';
  static const commentsTableId = '6aa8901e00133872e901';
  static const likesTableId = '6aa891da00110791b9aa';
  static const reportsTableId = '6aa892ea002c43862989';
  static const pageSize = 15;

  Future<void> _auth(String userId) async {
    final user = await _appwrite.getCurrentUser();
    if (user == null || user.$id != userId) {
      throw const CommunityException('يجب تسجيل الدخول لاستخدام المجتمع.');
    }
  }

  List<String> _permissions(String userId) => [
        Permission.read(Role.any()),
        Permission.update(Role.user(userId)),
        Permission.delete(Role.user(userId)),
      ];

  Future<Response> _call(
    HttpMethod method, {
    required String path,
    Map<String, dynamic> params = const {},
  }) async {
    try {
      return await _appwrite.client.call(
        method,
        path: path,
        params: params,
        headers: method == HttpMethod.get || method == HttpMethod.delete
            ? const {}
            : const {'content-type': 'application/json'},
      );
    } on AppwriteException catch (error) {
      debugPrint(
        'Community Appwrite error: code=${error.code}, '
        'type=${error.type}, message=${error.message}',
      );
      rethrow;
    }
  }

  String _rowsPath(String tableId, [String? rowId]) =>
      '/tablesdb/${AppwriteService.databaseId}/tables/$tableId/rows'
      '${rowId == null ? '' : '/$rowId'}';

  models.Document _rowToDocument(
    Map<String, dynamic> row,
    String tableId,
  ) {
    return models.Document.fromMap({
      ...row,
      r'$collectionId': tableId,
      r'$databaseId': AppwriteService.databaseId,
      r'$permissions': row[r'$permissions'] ?? <String>[],
    });
  }

  List<models.Document> _rowsFromResponse(
    dynamic response,
    String tableId,
  ) {
    if (response is! Map || response['rows'] is! List) {
      throw const FormatException('Invalid Appwrite rows response.');
    }
    return (response['rows'] as List)
        .whereType<Map>()
        .map((row) => _rowToDocument(Map<String, dynamic>.from(row), tableId))
        .toList();
  }

  Future<List<models.Document>> _listRows({
    required String tableId,
    List<String>? queries,
  }) async {
    final response = await _call(
      HttpMethod.get,
      path: _rowsPath(tableId),
      params: {'queries': queries ?? const <String>[]},
    );
    return _rowsFromResponse(response.data, tableId);
  }

  Future<models.Document> _getRow({
    required String tableId,
    required String rowId,
  }) async {
    final response = await _call(
      HttpMethod.get,
      path: _rowsPath(tableId, rowId),
    );
    if (response.data is! Map) {
      throw const FormatException('Invalid Appwrite row response.');
    }
    return _rowToDocument(
      Map<String, dynamic>.from(response.data as Map),
      tableId,
    );
  }

  Future<models.Document> _createRow({
    required String tableId,
    required Map<String, dynamic> data,
    List<String>? permissions,
  }) async {
    final response = await _call(
      HttpMethod.post,
      path: _rowsPath(tableId),
      params: {
        'rowId': ID.unique(),
        'data': data,
        if (permissions != null) 'permissions': permissions,
      },
    );
    if (response.data is! Map) {
      throw const FormatException('Invalid Appwrite created row response.');
    }
    return _rowToDocument(
      Map<String, dynamic>.from(response.data as Map),
      tableId,
    );
  }

  Future<void> _updateRow({
    required String tableId,
    required String rowId,
    required Map<String, dynamic> data,
  }) async {
    await _call(
      HttpMethod.patch,
      path: _rowsPath(tableId, rowId),
      params: {'data': data},
    );
  }

  Future<void> _deleteRow({
    required String tableId,
    required String rowId,
  }) async {
    await _call(
      HttpMethod.delete,
      path: _rowsPath(tableId, rowId),
    );
  }

  Future<List<models.Document>> listPosts({
    int offset = 0,
    String? userId,
  }) async {
    return _listRows(
      tableId: postsTableId,
      queries: [
        if (userId != null) Query.equal('userId', userId),
        Query.orderDesc('createdAt'),
        Query.limit(pageSize),
        Query.offset(offset),
      ],
    );
  }

  Future<models.Document> createPost({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    await _auth(userId);
    final now = DateTime.now().toUtc().toIso8601String();
    return _createRow(
      tableId: postsTableId,
      data: {
        ...data,
        'userId': userId,
        'createdAt': now,
        'updatedAt': now,
        'likeCount': 0,
        'commentCount': 0,
      },
      permissions: _permissions(userId),
    );
  }

  Future<void> deletePost({
    required String userId,
    required String postId,
  }) async {
    await _auth(userId);
    final post = await _getRow(tableId: postsTableId, rowId: postId);
    if (post.data['userId']?.toString() != userId) {
      throw const CommunityException('لا يمكنك حذف منشور مستخدم آخر.');
    }
    await _deleteRow(tableId: postsTableId, rowId: postId);
  }

  Future<List<models.Document>> listComments(
    String postId, {
    int offset = 0,
  }) async {
    return _listRows(
      tableId: commentsTableId,
      queries: [
        Query.equal('postId', postId),
        Query.orderAsc('createdAt'),
        Query.limit(pageSize),
        Query.offset(offset),
      ],
    );
  }

  Future<models.Document> createComment({
    required String userId,
    required String postId,
    required Map<String, dynamic> data,
  }) async {
    await _auth(userId);
    final now = DateTime.now().toUtc().toIso8601String();
    return _createRow(
      tableId: commentsTableId,
      data: {
        ...data,
        'userId': userId,
        'postId': postId,
        'createdAt': now,
        'updatedAt': now,
      },
      permissions: _permissions(userId),
    );
  }

  Future<void> deleteComment({
    required String userId,
    required String commentId,
  }) async {
    await _auth(userId);
    final comment = await _getRow(tableId: commentsTableId, rowId: commentId);
    if (comment.data['userId']?.toString() != userId) {
      throw const CommunityException('لا يمكنك حذف تعليق مستخدم آخر.');
    }
    await _deleteRow(tableId: commentsTableId, rowId: commentId);
  }

  Future<models.Document?> findLike({
    required String userId,
    required String postId,
  }) async {
    final rows = await _listRows(
      tableId: likesTableId,
      queries: [
        Query.equal('userId', userId),
        Query.equal('postId', postId),
        Query.limit(1),
      ],
    );
    return rows.firstOrNull;
  }

  Future<Set<String>> likedPostIds({
    required String userId,
    required List<String> postIds,
  }) async {
    if (postIds.isEmpty) return <String>{};
    await _auth(userId);
    final rows = await _listRows(
      tableId: likesTableId,
      queries: [
        Query.equal('userId', userId),
        Query.equal('postId', postIds),
        Query.limit(5000),
      ],
    );
    return rows
        .map((row) => row.data['postId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<void> toggleLike({
    required String userId,
    required String postId,
    required bool liked,
  }) async {
    await _auth(userId);
    final existing = await findLike(userId: userId, postId: postId);
    if (liked) {
      if (existing == null) {
        await _createRow(
          tableId: likesTableId,
          data: {
            'userId': userId,
            'postId': postId,
            'createdAt': DateTime.now().toUtc().toIso8601String(),
          },
          permissions: _permissions(userId),
        );
      }
    } else if (existing != null) {
      await _deleteRow(tableId: likesTableId, rowId: existing.$id);
    }
  }

  Future<void> updatePostCount({
    required String userId,
    required String postId,
    required int likeCount,
    required int commentCount,
  }) async {
    await _auth(userId);
    await _updateRow(
      tableId: postsTableId,
      rowId: postId,
      data: {
        'likeCount': likeCount < 0 ? 0 : likeCount,
        'commentCount': commentCount < 0 ? 0 : commentCount,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<void> report({
    required String userId,
    required String postId,
    required String reason,
    String details = '',
  }) async {
    await _auth(userId);
    try {
      await _createRow(
        tableId: reportsTableId,
        data: {
          'userId': userId,
          'postId': postId,
          'reason': reason,
          'details': details,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        },
        permissions: [Permission.create(Role.user(userId))],
      );
    } on AppwriteException catch (error) {
      if (error.code == 409 || (error.type ?? '').contains('duplicate')) {
        throw const CommunityException('سبق إرسال بلاغ لهذا المنشور.');
      }
      rethrow;
    }
  }
}

class CommunityException implements Exception {
  final String message;
  const CommunityException(this.message);
  @override
  String toString() => message;
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
