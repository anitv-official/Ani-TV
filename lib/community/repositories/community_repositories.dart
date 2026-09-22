import '../models/community_models.dart';

abstract class CommunityRepository {
  Future<List<CommunityPost>> fetchPosts(
      {int offset = 0, int limit = 8, String query = ''});
  Future<CommunityPost> publishPost(
      {required String text,
      String? imagePath,
      String? link,
      String? audioPath,
      Duration audioDuration = Duration.zero});
  Future<CommunityPost> toggleLike(CommunityPost post);
  Future<List<CommunityComment>> fetchComments(String postId);
  Future<CommunityComment> addComment(String postId, String text);
}

abstract class PostRepository {
  Future<List<CommunityPost>> fetchPosts(
      {int offset = 0, int limit = 8, String query = ''});
  Future<CommunityPost> create(CreatePostDraft draft);
}

abstract class CommentRepository {
  Future<List<CommunityComment>> fetchForPost(String postId);
  Future<CommunityComment> create(String postId, String text);
}

abstract class LikeRepository {
  Future<CommunityPost> toggle(CommunityPost post);
}

abstract class NotificationRepository {
  Future<List<CommunityNotification>> fetchNotifications();
  Future<int> unreadCount();
}

abstract class MediaRepository {
  Future<PostMedia> uploadImage(String path);
  Future<PostMedia> uploadAudio(String path,
      {Duration duration = Duration.zero});
  Future<void> deleteMedia(String mediaId);
  Future<String> getMediaUrl(PostMedia media);
}
