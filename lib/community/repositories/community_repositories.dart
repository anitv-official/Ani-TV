import '../models/community_models.dart';

abstract class CommunityRepository {
  Future<List<CommunityPost>> fetchPosts(
      {int offset = 0, int limit = 8, String query = '', DateTime? before});
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
      {int offset = 0, int limit = 8, String query = '', DateTime? before});
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

abstract class ProfileRepository {
  Future<CommunityProfile> getProfile(String userId);
  Future<List<CommunityPost>> postsByUser(String userId);
  Future<CommunityProfile> updateBio(String userId, String bio);
}

abstract class FriendRepository {
  Future<FriendStatus> statusFor(String userId);
  Future<FriendStatus> sendRequest(String userId);
  Future<List<Friend>> friends();
}

abstract class ChatRepository {
  Future<List<Conversation>> conversations();
  Future<List<CommunityMessage>> messages(String conversationId);
  Future<CommunityMessage> sendMessage(String conversationId, String text);
}

abstract class VerificationRepository {
  Future<VerificationStatus> statusFor(String userId);
}

abstract class ShareRepository {
  Future<ShareReceipt> shareExternally(CommunityPost post);
  Future<ShareReceipt> shareToUser(CommunityPost post, String userId);
}

abstract class CommunityRealtimeRepository {
  Stream<List<CommunityMessage>> watchMessages(String conversationId);
  Stream<List<CommunityNotification>> watchNotifications(String userId);
  Stream<List<CommunityComment>> watchComments(String postId);
  Stream<List<CommunityPost>> watchLikes(String postId);
}
