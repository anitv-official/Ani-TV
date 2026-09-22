import 'dart:io';

enum PostType { text, image, link, audio, mixed }

enum MediaType { image, audio }

enum NotificationType { friendRequest, comment, reaction }

enum FriendStatus { none, pending, incoming, friends, blocked }

enum MessageStatus { sending, sent, delivered, read, failed }

class PostAuthor {
  final String id;
  final String username;
  final String displayName;
  final String? avatarPath;
  final bool isVerified;
  const PostAuthor(
      {required this.id,
      required this.username,
      required this.displayName,
      this.avatarPath,
      this.isVerified = false});
  String get label => displayName.trim().isEmpty ? '@$username' : displayName;
}

class CommunityProfile {
  final PostAuthor author;
  final String country;
  final String birthDate;
  final String bio;
  final FriendStatus friendStatus;
  final List<String> favoriteTitles;
  const CommunityProfile(
      {required this.author,
      this.country = '',
      this.birthDate = '',
      this.bio = '',
      this.friendStatus = FriendStatus.none,
      this.favoriteTitles = const []});
  CommunityProfile copyWith({String? bio, FriendStatus? friendStatus}) =>
      CommunityProfile(
          author: author,
          country: country,
          birthDate: birthDate,
          bio: bio ?? this.bio,
          friendStatus: friendStatus ?? this.friendStatus,
          favoriteTitles: favoriteTitles);
}

class FriendRequest {
  final String id;
  final PostAuthor from;
  final PostAuthor to;
  final FriendStatus status;
  const FriendRequest(
      {required this.id,
      required this.from,
      required this.to,
      required this.status});
}

class Friend {
  final String id;
  final PostAuthor user;
  final FriendStatus status;
  const Friend(
      {required this.id,
      required this.user,
      this.status = FriendStatus.friends});
}

class Conversation {
  final String id;
  final PostAuthor participant;
  final String lastMessage;
  final DateTime updatedAt;
  final int unreadCount;
  const Conversation(
      {required this.id,
      required this.participant,
      required this.lastMessage,
      required this.updatedAt,
      this.unreadCount = 0});
}

class CommunityMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final DateTime sentAt;
  final MessageStatus status;
  final String? mediaReference;
  const CommunityMessage(
      {required this.id,
      required this.conversationId,
      required this.senderId,
      required this.text,
      required this.sentAt,
      this.status = MessageStatus.read,
      this.mediaReference});
}

class PostMedia {
  final String id;
  final MediaType type;
  final String path;
  final String? url;
  final Duration duration;
  const PostMedia(
      {required this.id,
      required this.type,
      required this.path,
      this.url,
      this.duration = Duration.zero});
  bool get isLocal => path.isNotEmpty && File(path).existsSync();
}

class CommunityPost {
  final String id;
  final PostAuthor author;
  final String text;
  final String? link;
  final List<PostMedia> media;
  final PostType type;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  const CommunityPost(
      {required this.id,
      required this.author,
      this.text = '',
      this.link,
      this.media = const [],
      required this.type,
      required this.createdAt,
      this.likeCount = 0,
      this.commentCount = 0,
      this.likedByMe = false});
  bool get hasImage => media.any((item) => item.type == MediaType.image);
  bool get hasAudio => media.any((item) => item.type == MediaType.audio);
  CommunityPost copyWith(
          {PostAuthor? author,
          String? text,
          String? link,
          List<PostMedia>? media,
          PostType? type,
          int? likeCount,
          int? commentCount,
          bool? likedByMe}) =>
      CommunityPost(
          id: id,
          author: author ?? this.author,
          text: text ?? this.text,
          link: link ?? this.link,
          media: media ?? this.media,
          type: type ?? this.type,
          createdAt: createdAt,
          likeCount: likeCount ?? this.likeCount,
          commentCount: commentCount ?? this.commentCount,
          likedByMe: likedByMe ?? this.likedByMe);
}

class CommunityComment {
  final String id;
  final String postId;
  final PostAuthor author;
  final String text;
  final DateTime createdAt;
  const CommunityComment(
      {required this.id,
      required this.postId,
      required this.author,
      required this.text,
      required this.createdAt});
}

class CommunityNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final String? friendRequestId;
  const CommunityNotification(
      {required this.id,
      required this.type,
      required this.title,
      required this.body,
      required this.createdAt,
      this.isRead = false,
      this.friendRequestId});
}

class CreatePostDraft {
  final String text;
  final String? imagePath;
  final String? link;
  final String? audioPath;
  final Duration audioDuration;
  const CreatePostDraft(
      {this.text = '',
      this.imagePath,
      this.link,
      this.audioPath,
      this.audioDuration = Duration.zero});
  bool get hasContent =>
      text.trim().isNotEmpty ||
      (imagePath?.trim().isNotEmpty ?? false) ||
      (link?.trim().isNotEmpty ?? false) ||
      (audioPath?.trim().isNotEmpty ?? false);
}

class VerificationStatus {
  final bool verified;
  const VerificationStatus({this.verified = false});
}

class CommunityLike {
  final String postId;
  final String userId;
  final bool active;
  const CommunityLike(
      {required this.postId, required this.userId, this.active = true});
}

class ShareReceipt {
  final String postId;
  final String? recipientId;
  final bool external;
  const ShareReceipt(
      {required this.postId, this.recipientId, required this.external});
}
