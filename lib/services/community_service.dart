import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
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
    if (user == null || user.$id != userId) throw const CommunityException('يجب تسجيل الدخول لاستخدام المجتمع.');
  }
  List<String> _permissions(String userId) => [Permission.read(Role.any()), Permission.update(Role.user(userId)), Permission.delete(Role.user(userId))];

  Future<List<models.Document>> listPosts({int offset = 0, String? userId}) async {
    final result = await _appwrite.databases.listDocuments(databaseId: AppwriteService.databaseId, collectionId: postsTableId, queries: [if (userId != null) Query.equal('userId', userId), Query.orderDesc('createdAt'), Query.limit(pageSize), Query.offset(offset)]);
    return result.documents;
  }
  Future<models.Document> createPost({required String userId, required Map<String, dynamic> data}) async {
    await _auth(userId);
    final now = DateTime.now().toUtc().toIso8601String();
    return _appwrite.databases.createDocument(databaseId: AppwriteService.databaseId, collectionId: postsTableId, documentId: ID.unique(), data: {...data, 'userId': userId, 'createdAt': now, 'updatedAt': now, 'likeCount': 0, 'commentCount': 0}, permissions: _permissions(userId));
  }
  Future<void> deletePost({required String userId, required String postId}) async {
    await _auth(userId);
    final post = await _appwrite.databases.getDocument(databaseId: AppwriteService.databaseId, collectionId: postsTableId, documentId: postId);
    if (post.data['userId']?.toString() != userId) throw const CommunityException('لا يمكنك حذف منشور مستخدم آخر.');
    await _appwrite.databases.deleteDocument(databaseId: AppwriteService.databaseId, collectionId: postsTableId, documentId: postId);
  }
  Future<List<models.Document>> listComments(String postId, {int offset = 0}) async => (await _appwrite.databases.listDocuments(databaseId: AppwriteService.databaseId, collectionId: commentsTableId, queries: [Query.equal('postId', postId), Query.orderAsc('createdAt'), Query.limit(pageSize), Query.offset(offset)])).documents;
  Future<models.Document> createComment({required String userId, required String postId, required Map<String, dynamic> data}) async {
    await _auth(userId); final now = DateTime.now().toUtc().toIso8601String();
    return _appwrite.databases.createDocument(databaseId: AppwriteService.databaseId, collectionId: commentsTableId, documentId: ID.unique(), data: {...data, 'userId': userId, 'postId': postId, 'createdAt': now, 'updatedAt': now}, permissions: _permissions(userId));
  }
  Future<void> deleteComment({required String userId, required String commentId}) async {
    await _auth(userId); final c = await _appwrite.databases.getDocument(databaseId: AppwriteService.databaseId, collectionId: commentsTableId, documentId: commentId);
    if (c.data['userId']?.toString() != userId) throw const CommunityException('لا يمكنك حذف تعليق مستخدم آخر.');
    await _appwrite.databases.deleteDocument(databaseId: AppwriteService.databaseId, collectionId: commentsTableId, documentId: commentId);
  }
  Future<models.Document?> findLike({required String userId, required String postId}) async => (await _appwrite.databases.listDocuments(databaseId: AppwriteService.databaseId, collectionId: likesTableId, queries: [Query.equal('userId', userId), Query.equal('postId', postId), Query.limit(1)])).documents.firstOrNull;
  Future<Set<String>> likedPostIds({required String userId, required List<String> postIds}) async {
    if (postIds.isEmpty) return <String>{};
    await _auth(userId);
    final result = await _appwrite.databases.listDocuments(databaseId: AppwriteService.databaseId, collectionId: likesTableId, queries: [Query.equal('userId', userId), Query.equal('postId', postIds), Query.limit(5000)]);
    return result.documents.map((d) => d.data['postId']?.toString() ?? '').where((id) => id.isNotEmpty).toSet();
  }
  Future<void> toggleLike({required String userId, required String postId, required bool liked}) async {
    await _auth(userId);
    final existing = await findLike(userId: userId, postId: postId);
    if (liked) { if (existing == null) await _appwrite.databases.createDocument(databaseId: AppwriteService.databaseId, collectionId: likesTableId, documentId: ID.unique(), data: {'userId': userId, 'postId': postId, 'createdAt': DateTime.now().toUtc().toIso8601String()}, permissions: _permissions(userId)); }
    else if (existing != null) {
      await _appwrite.databases.deleteDocument(databaseId: AppwriteService.databaseId, collectionId: likesTableId, documentId: existing.$id);
    }
  }
  Future<void> updatePostCount({required String userId, required String postId, required int likeCount, required int commentCount}) async { await _auth(userId); await _appwrite.databases.updateDocument(databaseId: AppwriteService.databaseId, collectionId: postsTableId, documentId: postId, data: {'likeCount': likeCount < 0 ? 0 : likeCount, 'commentCount': commentCount < 0 ? 0 : commentCount, 'updatedAt': DateTime.now().toUtc().toIso8601String()}); }
  Future<void> report({required String userId, required String postId, required String reason, String details = ''}) async { await _auth(userId); await _appwrite.databases.createDocument(databaseId: AppwriteService.databaseId, collectionId: reportsTableId, documentId: ID.unique(), data: {'userId': userId, 'postId': postId, 'reason': reason, 'details': details, 'createdAt': DateTime.now().toUtc().toIso8601String()}, permissions: [Permission.create(Role.user(userId))]); }
}

class CommunityException implements Exception { final String message; const CommunityException(this.message); @override String toString() => message; }
extension _FirstOrNull<T> on List<T> { T? get firstOrNull => isEmpty ? null : first; }
