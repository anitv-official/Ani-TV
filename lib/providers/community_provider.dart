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
  String _searchQuery = '';
  Future<void>? _request;

  String get searchQuery => _searchQuery;
  List<Map<String, dynamic>> get visiblePosts {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return List.unmodifiable(posts);
    return posts.where((post) {
      final haystack = [post['text'], post['username'], post['displayName']]
          .map((value) => value?.toString().toLowerCase() ?? '')
          .join(' ');
      return haystack.contains(query);
    }).toList(growable: false);
  }

  void setSearchQuery(String value) {
    final next = value.trimLeft();
    if (_searchQuery == next) return;
    _searchQuery = next;
    notifyListeners();
  }

  Future<void> load({bool refresh = false}) async {
    if (_request != null) return _request!;
    if (!refresh && posts.isNotEmpty && !hasMore) return;
    final future = _loadInternal(refresh);
    _request = future;
    try {
      await future;
    } finally {
      if (identical(_request, future)) _request = null;
    }
  }

  Future<void> _loadInternal(bool refresh) async {
    if (refresh) {
      posts.clear();
      hasMore = true;
    }
    if (!hasMore) return;
    if (posts.isEmpty) {
      loading = true;
    } else {
      loadingMore = true;
    }
    error = null;
    notifyListeners();
    try {
      final rows = await service.listPosts(offset: posts.length);
      final mapped = rows.map(_map).toList();
      posts.addAll(mapped.where((p) => !posts.any((old) => old['id'] == p['id'])));
      if (account.userId != null && posts.isNotEmpty) {
        final likedIds = await service.likedPostIds(
          userId: account.userId!,
          postIds: posts.map((p) => p['id'].toString()).toList(),
        );
        for (final post in posts) {
          post['likedByMe'] = likedIds.contains(post['id'].toString());
        }
      }
      hasMore = rows.length == CommunityService.pageSize;
    } catch (error, stack) {
      if (kDebugMode) debugPrint('Community load failed: $error\n$stack');
      this.error = 'تعذر تحميل منشورات المجتمع.';
    } finally {
      loading = false;
      loadingMore = false;
      notifyListeners();
    }
  }

  Map<String, dynamic> _map(dynamic row) => {
        'id': row.$id,
        ...Map<String, dynamic>.from(row.data as Map),
      };

  Future<void> createPost({required String text, String? imagePath}) async {
    final userId = account.userId;
    if (!account.isLoggedIn || userId == null) {
      throw const CommunityException('سجّل الدخول لإنشاء منشور.');
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty && imagePath == null) {
      throw const CommunityException('اكتب نصًا أو أضف صورة أولًا.');
    }

    CloudinaryUploadResult? uploaded;
    if (imagePath != null) {
      uploaded = await CloudinaryService.uploadPostImage(imagePath);
    }
    final row = await service.createPost(
      userId: userId,
      data: {
        'username': account.username.trim(),
        'displayName': account.displayName.trim(),
        'profileImageId': account.profileImageId ?? '',
        'text': trimmed,
        'imageUrl': uploaded?.url ?? '',
        'imagePublicId': uploaded?.publicId ?? '',
      },
    );
    posts.insert(0, _map(row));
    notifyListeners();
  }

  Future<void> deletePost(String postId) async {
    final id = account.userId;
    if (id == null) throw const CommunityException('يجب تسجيل الدخول.');
    await service.deletePost(userId: id, postId: postId);
    posts.removeWhere((p) => p['id'] == postId);
    notifyListeners();
  }

  Future<bool> toggleLike(Map<String, dynamic> post) async {
    final id = account.userId;
    if (id == null) throw const CommunityException('سجّل الدخول للإعجاب.');
    final liked = post['likedByMe'] != true;
    final count = (post['likeCount'] as num? ?? 0).toInt();
    post['likedByMe'] = liked;
    post['likeCount'] = (count + (liked ? 1 : -1)).clamp(0, 1 << 30);
    notifyListeners();
    try {
      await service.toggleLike(userId: id, postId: post['id'].toString(), liked: liked);
      // Counts are maintained by the post owner/server permission. A client
      // must not make the like operation fail when it cannot mutate that row.
      try {
        await service.updatePostCount(
          userId: id,
          postId: post['id'].toString(),
          likeCount: (post['likeCount'] as num).toInt(),
          commentCount: (post['commentCount'] as num? ?? 0).toInt(),
        );
      } catch (error) {
        if (kDebugMode) debugPrint('Community count update skipped: $error');
      }
      return liked;
    } catch (_) {
      post['likedByMe'] = !liked;
      post['likeCount'] = count;
      notifyListeners();
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> comments(String postId) async =>
      (await service.listComments(postId)).map(_map).toList();

  Future<void> addComment(String postId, String text) async {
    final id = account.userId;
    if (id == null) throw const CommunityException('سجّل الدخول للتعليق.');
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw const CommunityException('اكتب تعليقًا أولًا.');
    await service.createComment(
      userId: id,
      postId: postId,
      data: {
        'username': account.username.trim(),
        'displayName': account.displayName.trim(),
        'profileImageId': account.profileImageId ?? '',
        'text': trimmed,
      },
    );
    final post = posts.firstWhere((p) => p['id'] == postId);
    final count = (post['commentCount'] as num? ?? 0).toInt() + 1;
    post['commentCount'] = count;
    try {
      await service.updatePostCount(
        userId: id,
        postId: postId,
        likeCount: (post['likeCount'] as num? ?? 0).toInt(),
        commentCount: count,
      );
    } catch (error) {
      if (kDebugMode) debugPrint('Community count update skipped: $error');
    }
    notifyListeners();
  }

  Future<void> deleteComment(String commentId) async {
    final id = account.userId;
    if (id == null) throw const CommunityException('يجب تسجيل الدخول.');
    await service.deleteComment(userId: id, commentId: commentId);
  }

  Future<void> report(String postId, String reason, String details) async {
    final id = account.userId;
    if (id == null) throw const CommunityException('سجّل الدخول للإبلاغ.');
    await service.report(userId: id, postId: postId, reason: reason, details: details.trim());
  }
}
