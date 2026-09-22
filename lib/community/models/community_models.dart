import 'dart:io';

enum PostType { text, image, link, audio, mixed }

enum MediaType { image, audio }

enum NotificationType { friendRequest, comment, reaction }

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
          {String? text,
          String? link,
          List<PostMedia>? media,
          PostType? type,
          int? likeCount,
          int? commentCount,
          bool? likedByMe}) =>
      CommunityPost(
          id: id,
          author: author,
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

  const CommunityNotification(
      {required this.id,
      required this.type,
      required this.title,
      required this.body,
      required this.createdAt,
      this.isRead = false});
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
