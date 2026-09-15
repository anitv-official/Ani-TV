import 'package:flutter/foundation.dart';
import '../services/community_service.dart';
import '../services/cloudinary_service.dart';
import 'app_state_provider.dart';

class CommunityProvider extends ChangeNotifier {
  final CommunityService service = CommunityService.instance;
  final AppStateProvider account;
  CommunityProvider(this.account);
  final posts = <Map<String, dynamic>>[];
  bool loading = false, loadingMore = false, hasMore = true;
  String? error;
  Future<void>? _request;

  Future<void> load({bool refresh = false}) async {
    if (_request != null) return _request!;
    if (!refresh && posts.isNotEmpty && !hasMore) return;
    final future = _loadInternal(refresh);
    _request = future;
    try { await future; } finally { if (identical(_request, future)) _request = null; }
  }
  Future<void> _loadInternal(bool refresh) async {
    if (refresh) { posts.clear(); hasMore = true; }
    if (!hasMore) return;
    if (posts.isEmpty) { loading = true; } else { loadingMore = true; }
    error = null; notifyListeners();
    try {
      final rows = await service.listPosts(offset: posts.length);
      final mapped = rows.map(_map).toList();
      posts.addAll(mapped.where((p) => !posts.any((old) => old['id'] == p['id'])));
      if (account.userId != null && posts.isNotEmpty) {
        final likedIds = await service.likedPostIds(userId: account.userId!, postIds: posts.map((p) => p['id'].toString()).toList());
        for (final post in posts) { post['likedByMe'] = likedIds.contains(post['id'].toString()); }
      }
      hasMore = rows.length == CommunityService.pageSize;
    } catch (_) { error = 'تعذر تحميل منشورات المجتمع. تحقق من الاتصال وحاول مرة أخرى.'; }
    loading = false; loadingMore = false; notifyListeners();
  }
  Map<String, dynamic> _map(dynamic d) => {'id': d.$id, ...Map<String, dynamic>.from(d.data as Map)};
  Future<void> createPost({required String text, String? imagePath}) async {
    final userId = account.userId;
    if (!account.isLoggedIn || userId == null) throw const CommunityException('سجّل الدخول لإنشاء منشور.');
    CloudinaryUploadResult? uploaded;
    if (imagePath != null) uploaded = await CloudinaryService.uploadPostImage(imagePath);
    final doc = await service.createPost(userId: userId, data: {'username': account.username, 'displayName': account.displayName, 'profileImageId': '', 'text': text.trim(), 'imageUrl': uploaded?.url ?? '', 'imagePublicId': uploaded?.publicId ?? ''});
    posts.insert(0, _map(doc)); notifyListeners();
  }
  Future<void> deletePost(String postId) async { final id = account.userId; if (id == null) return; await service.deletePost(userId: id, postId: postId); posts.removeWhere((p) => p['id'] == postId); notifyListeners(); }
  Future<bool> toggleLike(Map<String, dynamic> post) async {
    final id = account.userId; if (id == null) throw const CommunityException('سجّل الدخول للإعجاب.');
    final liked = !(post['likedByMe'] == true); final count = (post['likeCount'] as num? ?? 0).toInt();
    post['likedByMe'] = liked; post['likeCount'] = (count + (liked ? 1 : -1)).clamp(0, 1 << 30); notifyListeners();
    try { await service.toggleLike(userId: id, postId: post['id'].toString(), liked: liked); await service.updatePostCount(userId: id, postId: post['id'].toString(), likeCount: (post['likeCount'] as num).toInt(), commentCount: (post['commentCount'] as num? ?? 0).toInt()); return liked; } catch (_) { post['likedByMe'] = !liked; post['likeCount'] = count; notifyListeners(); rethrow; }
  }
  Future<List<Map<String, dynamic>>> comments(String postId) async => (await service.listComments(postId)).map(_map).toList();
  Future<void> addComment(String postId, String text) async { final id = account.userId; if (id == null) throw const CommunityException('سجّل الدخول للتعليق.'); await service.createComment(userId: id, postId: postId, data: {'username': account.username, 'displayName': account.displayName, 'profileImageId': '', 'text': text.trim()}); final post = posts.firstWhere((p) => p['id'] == postId); final count = (post['commentCount'] as num? ?? 0).toInt() + 1; post['commentCount'] = count; await service.updatePostCount(userId: id, postId: postId, likeCount: (post['likeCount'] as num? ?? 0).toInt(), commentCount: count); notifyListeners(); }
  Future<void> deleteComment(String commentId) async { final id = account.userId; if (id != null) await service.deleteComment(userId: id, commentId: commentId); }
  Future<void> report(String postId, String reason, String details) async { final id = account.userId; if (id == null) throw const CommunityException('سجّل الدخول للإبلاغ.'); await service.report(userId: id, postId: postId, reason: reason, details: details); }
}
