import 'package:flutter/foundation.dart';
import '../models/community_models.dart';
import '../repositories/community_repositories.dart';

class CommunityFeedProvider extends ChangeNotifier {
  CommunityFeedProvider({required this.repository});
  final CommunityRepository repository;
  final List<CommunityPost> posts = [];
  bool loading = false;
  bool loadingMore = false;
  bool hasMore = true;
  String query = '';
  Object? error;
  Future<void>? _request;
  DateTime? _cursor;

  List<CommunityPost> get visiblePosts => List.unmodifiable(posts);

  Future<void> load({bool refresh = false}) {
    if (_request != null) return _request!;
    if (!refresh && posts.isNotEmpty && !hasMore) return Future<void>.value();
    final future = _load(refresh: refresh);
    _request = future;
    return future.whenComplete(() {
      if (identical(_request, future)) _request = null;
    });
  }

  Future<void> _load({required bool refresh}) async {
    if (refresh) {
      posts.clear();
      hasMore = true;
      _cursor = null;
    }
    if (!hasMore) return;
    loading = posts.isEmpty;
    loadingMore = posts.isNotEmpty;
    error = null;
    notifyListeners();
    try {
      final next = await repository.fetchPosts(
          offset: _cursor == null ? posts.length : 0,
          query: query,
          before: _cursor);
      final existing = posts.map((post) => post.id).toSet();
      posts.addAll(next.where((post) => existing.add(post.id)));
      if (next.isNotEmpty) _cursor = next.last.createdAt;
      hasMore = next.length == 8;
    } catch (value) {
      error = value;
    } finally {
      loading = false;
      loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> search(String value) async {
    final next = value.trim();
    if (next == query) return;
    query = next;
    await load(refresh: true);
  }

  Future<void> publish(CreatePostDraft draft) async {
    if (!draft.hasContent)
      throw const CommunityInputException(
          'أضف نصًا أو صورة أو رابطًا أو مقطعًا صوتيًا.');
    final post = await repository.publishPost(
        text: draft.text,
        imagePath: draft.imagePath,
        link: draft.link,
        audioPath: draft.audioPath,
        audioDuration: draft.audioDuration);
    posts.insert(0, post);
    notifyListeners();
  }

  Future<void> toggleLike(CommunityPost post) async {
    final index = posts.indexWhere((item) => item.id == post.id);
    if (index < 0) return;
    final optimistic = post.copyWith(
        likedByMe: !post.likedByMe,
        likeCount:
            (post.likeCount + (post.likedByMe ? -1 : 1)).clamp(0, 1 << 30));
    posts[index] = optimistic;
    notifyListeners();
    try {
      posts[index] = await repository.toggleLike(optimistic);
    } catch (_) {
      posts[index] = post;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> deletePost(String postId) async {
    final index = posts.indexWhere((post) => post.id == postId);
    if (index < 0) return;
    final removed = posts.removeAt(index);
    notifyListeners();
    try {
      await repository.deletePost(postId);
    } catch (_) {
      posts.insert(index, removed);
      notifyListeners();
      rethrow;
    }
  }

  Future<List<CommunityComment>> comments(String postId) =>
      repository.fetchComments(postId);
  Future<CommunityComment> addComment(String postId, String text) async {
    final value = text.trim();
    if (value.isEmpty)
      throw const CommunityInputException('اكتب تعليقًا أولًا.');
    final comment = await repository.addComment(postId, value);
    final index = posts.indexWhere((post) => post.id == postId);
    if (index >= 0)
      posts[index] =
          posts[index].copyWith(commentCount: posts[index].commentCount + 1);
    notifyListeners();
    return comment;
  }
}

class CommunityInputException implements Exception {
  final String message;
  const CommunityInputException(this.message);
  @override
  String toString() => message;
}
