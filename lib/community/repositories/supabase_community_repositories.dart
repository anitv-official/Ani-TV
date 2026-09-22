import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/community_models.dart';
import 'community_repositories.dart';
import '../services/appwrite_community_identity.dart';
import '../services/community_backend_config.dart';
import '../services/community_media_api.dart';
import '../services/community_write_api.dart';
import '../../services/appwrite_service.dart';

class SupabaseRepositoryBase {
  SupabaseRepositoryBase(
      {SupabaseClient? client, CommunityIdentityProvider? identity})
      : client = client ?? CommunityBackend.client,
        identity = identity ?? const AppwriteCommunityIdentity();
  final SupabaseClient client;
  final CommunityIdentityProvider identity;
  final CommunityWriteApi writeApi = CommunityWriteApi();
  Future<String> requireUser() async =>
      (await identity.currentUserId()) ??
      (throw const AuthenticationError(
          'Sign in with Appwrite to use Community.'));
  CommunityBackendError error(Object error) => mapSupabaseError(error);
}

class SupabaseCommunityRepository extends SupabaseRepositoryBase
    implements CommunityRepository {
  SupabaseCommunityRepository({super.client, super.identity})
      : _posts = SupabasePostRepository(client: client, identity: identity),
        _comments =
            SupabaseCommentRepository(client: client, identity: identity);
  final SupabasePostRepository _posts;
  final SupabaseCommentRepository _comments;
  @override
  Future<List<CommunityPost>> fetchPosts(
          {int offset = 0,
          int limit = 8,
          String query = '',
          DateTime? before}) =>
      _posts.fetchPosts(
          offset: offset, limit: limit, query: query, before: before);
  @override
  Future<CommunityPost> publishPost(
      {required String text,
      String? imagePath,
      String? link,
      String? audioPath,
      Duration audioDuration = Duration.zero}) async {
    final draft = CreatePostDraft(
        text: text,
        imagePath: imagePath,
        link: link,
        audioPath: audioPath,
        audioDuration: audioDuration);
    final post = await _posts.create(draft);
    if (imagePath == null && audioPath == null) return post;
    try {
      final api = CommunityMediaApi();
      final media = imagePath != null
          ? await api.uploadFile(
              postId: post.id,
              path: imagePath,
              mediaType: MediaType.image,
              mimeType: _mimeFor(imagePath),
            )
          : await api.uploadFile(
              postId: post.id,
              path: audioPath!,
              mediaType: MediaType.audio,
              mimeType: _mimeFor(audioPath),
              duration: audioDuration,
            );
      return post.copyWith(media: [
        media
      ], type: media.type == MediaType.image ? PostType.image : PostType.audio);
    } catch (_) {
      try {
        await client.from('community_posts').delete().eq('id', post.id);
      } catch (_) {}
      rethrow;
    }
  }

  @override
  Future<CommunityPost> toggleLike(CommunityPost post) =>
      SupabaseLikeRepository(client: client, identity: identity).toggle(post);
  @override
  Future<void> deletePost(String postId) async {
    try {
      await writeApi.invoke('delete_post', {'post_id': postId});
    } catch (error) {
      throw this.error(error);
    }
  }
  @override
  Future<List<CommunityComment>> fetchComments(String postId) =>
      _comments.fetchForPost(postId);
  @override
  Future<CommunityComment> addComment(String postId, String text) =>
      _comments.create(postId, text);
}

class SupabasePostRepository extends SupabaseRepositoryBase
    implements PostRepository {
  SupabasePostRepository({super.client, super.identity});
  @override
  Future<List<CommunityPost>> fetchPosts(
      {int offset = 0,
      int limit = 8,
      String query = '',
      DateTime? before}) async {
    try {
      var request = client
          .from('community_posts')
          .select('*, community_profiles!community_posts_author_id_fkey(*), community_post_media(*)')
          .isFilter('deleted_at', null)
          .ilike('content', query.trim().isEmpty ? '%' : '%${query.trim()}%');
      if (before != null)
        request = request.lt('created_at', before.toUtc().toIso8601String());
      final rows = await request.order('created_at', ascending: false).range(
          before == null ? offset : 0,
          (before == null ? offset : 0) + limit - 1);
      final posts = (rows as List)
          .map((row) => _postFromRow(Map<String, dynamic>.from(row as Map)))
          .toList();
      return Future.wait(posts.map(_hydratePostAuthor));
    } catch (error) {
      throw this.error(error);
    }
  }

  @override
  Future<CommunityPost> create(CreatePostDraft draft) async {
    if (!draft.hasContent)
      throw const ValidationError('A post needs text, a link, or media.');
    try {
      final result = await writeApi.invoke('create_post', {
        'content': draft.text.trim(),
        if (draft.link != null) 'link': draft.link,
        'post_type': draft.link != null
            ? 'link'
            : draft.imagePath != null
                ? (draft.text.trim().isEmpty ? 'image' : 'mixed')
                : draft.audioPath != null
                    ? (draft.text.trim().isEmpty ? 'audio' : 'mixed')
                    : 'text',
      });
      final profile = await writeApi.invoke('ensure_profile');
      final row = <String, dynamic>{
        ...result,
        'community_profiles': profile,
        'community_post_media': const <dynamic>[],
      };
      return _postFromRow(Map<String, dynamic>.from(row));
    } catch (error) {
      throw this.error(error);
    }
  }
}

class SupabaseCommentRepository extends SupabaseRepositoryBase
    implements CommentRepository {
  SupabaseCommentRepository({super.client, super.identity});
  @override
  Future<List<CommunityComment>> fetchForPost(String postId) async {
    try {
      final rows = await client
          .from('community_comments')
          .select('*, community_profiles!community_comments_author_id_fkey(*)')
          .eq('post_id', postId)
          .isFilter('deleted_at', null)
          .order('created_at');
      final comments = (rows as List)
          .map((row) => _commentFromRow(Map<String, dynamic>.from(row as Map)))
          .toList();
      return Future.wait(comments.map(_hydrateCommentAuthor));
    } catch (error) {
      throw this.error(error);
    }
  }

  Future<CommunityComment> _hydrateCommentAuthor(
      CommunityComment comment) async {
    try {
      final document =
          await AppwriteService.instance.getProfile(comment.author.id);
      final data = document?.data ?? const <String, dynamic>{};
      final username = data['username']?.toString().trim();
      final displayName = data['displayname']?.toString().trim();
      final imageId = data['profileImageId']?.toString().trim();
      return CommunityComment(
          id: comment.id,
          postId: comment.postId,
          author: PostAuthor(
              id: comment.author.id,
              username: username?.isNotEmpty == true
                  ? username!
                  : comment.author.username,
              displayName: displayName?.isNotEmpty == true
                  ? displayName!
                  : comment.author.displayName,
              avatarPath: imageId?.isNotEmpty == true
                  ? imageId
                  : comment.author.avatarPath,
              isVerified: comment.author.isVerified),
          text: comment.text,
          createdAt: comment.createdAt);
    } catch (_) {
      return comment;
    }
  }

  @override
  Future<CommunityComment> create(String postId, String text) async {
    if (text.trim().isEmpty)
      throw const ValidationError('Comment cannot be empty.');
    try {
      final result = await writeApi.invoke('create_comment', {
        'post_id': postId,
        'content': text.trim(),
      });
      final profile = await writeApi.invoke('ensure_profile');
      final row = <String, dynamic>{...result, 'community_profiles': profile};
      return _commentFromRow(Map<String, dynamic>.from(row));
    } catch (error) {
      throw this.error(error);
    }
  }
  @override
  Future<void> delete(String commentId) async {
    try {
      await writeApi.invoke('delete_comment', {'comment_id': commentId});
    } catch (error) {
      throw this.error(error);
    }
  }
}

class SupabaseLikeRepository extends SupabaseRepositoryBase
    implements LikeRepository {
  SupabaseLikeRepository({super.client, super.identity});
  @override
  Future<CommunityPost> toggle(CommunityPost post) async {
    try {
      final result = await writeApi.invoke('toggle_like', {'post_id': post.id});
      final liked = result['liked'] == true;
      return post.copyWith(
          likeCount: (post.likeCount + (liked ? 1 : -1)).clamp(0, 1 << 30),
          likedByMe: liked);
    } catch (error) {
      throw this.error(error);
    }
  }
}

class SupabaseProfileRepository extends SupabaseRepositoryBase
    implements ProfileRepository {
  SupabaseProfileRepository({super.client, super.identity});
  @override
  Future<CommunityProfile> getProfile(String userId) async {
    try {
      final row = await client
          .from('community_profiles')
          .select('*')
          .eq('user_id', userId)
          .single();
      var profile = await _withAppwriteData(
          _profileFromRow(Map<String, dynamic>.from(row)), userId);
      final current = await identity.currentUserId();
      if (current == null || current == userId) return profile;
      try {
        final status = await SupabaseFriendRepository(
                client: client, identity: identity)
            .statusFor(userId);
        return profile.copyWith(friendStatus: status);
      } catch (_) {
        return profile;
      }
    } catch (error) {
      if (error is PostgrestException && error.code == 'PGRST116') {
        final current = await requireUser();
        if (current == userId) {
          final row = await writeApi.invoke('ensure_profile');
          return _withAppwriteData(_profileFromRow(row), userId);
        }
      }
      throw this.error(error);
    }
  }

  Future<CommunityProfile> _withAppwriteData(
      CommunityProfile profile, String userId) async {
    try {
      final appwriteProfile =
          await AppwriteService.instance.getProfile(userId);
      final data = appwriteProfile?.data ?? const <String, dynamic>{};
      final username = data['username']?.toString().trim();
      final displayName = data['displayname']?.toString().trim();
      final imageId = data['profileImageId']?.toString().trim();
      return CommunityProfile(
          author: PostAuthor(
              id: userId,
              username: username?.isNotEmpty == true
                  ? username!
                  : profile.author.username,
              displayName: displayName?.isNotEmpty == true
                  ? displayName!
                  : profile.author.displayName,
              avatarPath: imageId?.isNotEmpty == true
                  ? imageId
                  : profile.author.avatarPath,
              isVerified: profile.author.isVerified),
          country: data['country']?.toString() ?? profile.country,
          birthDate: data['birthdate']?.toString() ?? profile.birthDate,
          bio: profile.bio,
          friendStatus: profile.friendStatus,
          favoriteTitles: profile.favoriteTitles);
    } catch (_) {
      return profile;
    }
  }

  @override
  Future<List<CommunityPost>> postsByUser(String userId) async {
    try {
      final rows = await client
          .from('community_posts')
          .select('*, community_profiles!community_posts_author_id_fkey(*), community_post_media(*)')
          .eq('author_id', userId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .range(0, 49);
      final posts = (rows as List)
          .map((row) => _postFromRow(Map<String, dynamic>.from(row as Map)))
          .toList();
      return Future.wait(posts.map(_hydratePostAuthor));
    } catch (error) {
      throw this.error(error);
    }
  }
  @override
  Future<CommunityProfile> updateBio(String userId, String bio) async {
    if (userId != await requireUser())
      throw const PermissionError('You can only update your own profile.');
    try {
      final result = await writeApi.invoke('update_profile', {'bio': bio.trim()});
      final row = result['user_id'] == null
          ? await client.from('community_profiles').select().eq('user_id', userId).single()
          : result;
      return _profileFromRow(Map<String, dynamic>.from(row));
    } catch (error) {
      throw this.error(error);
    }
  }
}

class SupabaseFriendRepository extends SupabaseRepositoryBase
    implements FriendRepository {
  SupabaseFriendRepository({super.client, super.identity});
  @override
  Future<FriendStatus> statusFor(String userId) async {
    final me = await requireUser();
    if (me == userId) return FriendStatus.none;
    try {
      final result = await writeApi.invoke('friend_status', {'user_id': userId});
      return switch (result['status']) {
        'friends' => FriendStatus.friends,
        'pending' => FriendStatus.pending,
        'incoming' => FriendStatus.incoming,
        _ => FriendStatus.none,
      };
    } catch (error) {
      throw this.error(error);
    }
  }

  @override
  Future<FriendStatus> sendRequest(String userId) async {
    try {
      final result = await writeApi.invoke('send_friend_request', {'user_id': userId});
      if (result['status'] == 'accepted') return FriendStatus.friends;
      if (result['status'] == 'friends') return FriendStatus.friends;
      if (result['status'] == 'incoming') return FriendStatus.incoming;
      return FriendStatus.pending;
    } catch (error) {
      throw this.error(error);
    }
  }

  @override
  Future<FriendStatus> respondToRequest(String requestId,
      {required bool accept}) async {
    try {
      final result = await writeApi.invoke('respond_friend_request', {
        'request_id': requestId,
        'accept': accept,
      });
      return result['status'] == 'friends'
          ? FriendStatus.friends
          : FriendStatus.none;
    } catch (error) {
      throw this.error(error);
    }
  }

  @override
  Future<List<FriendRequest>> incomingRequests() async {
    try {
      final result = await writeApi.invoke('list_friend_requests');
      final requests = (result['requests'] as List?) ?? const [];
      return requests.map((value) {
        final row = Map<String, dynamic>.from(value as Map);
        final from = _profileFromRow(Map<String, dynamic>.from(
            (row['requester_profile'] as Map?) ?? const {}));
        return FriendRequest(
            id: row['id'].toString(),
            from: from.author,
            to: const PostAuthor(
                id: '', username: 'me', displayName: 'Me'),
            status: FriendStatus.incoming);
      }).toList();
    } catch (error) {
      throw this.error(error);
    }
  }

  @override
  Future<List<Friend>> friends() async {
    try {
      final result = await writeApi.invoke('list_friends');
      final profiles = (result['friends'] as List?) ?? const [];
      return Future.wait(profiles.map((row) async {
        final profile = _profileFromRow(Map<String, dynamic>.from(row as Map));
        final author = await _hydrateAuthor(profile.author);
        return Friend(id: author.id, user: author);
      }));
    } catch (error) {
      throw this.error(error);
    }
  }
}

class SupabaseChatRepository extends SupabaseRepositoryBase
    implements ChatRepository {
  SupabaseChatRepository({super.client, super.identity});
  @override
  Future<Conversation> openConversation(
      String userId, PostAuthor participant) async {
    try {
      final result = await writeApi.invoke('open_conversation', {
        'user_id': userId,
      });
      return Conversation(
          id: result['conversation_id'].toString(),
          participant: participant,
          lastMessage: '',
          updatedAt: DateTime.now());
    } catch (error) {
      throw this.error(error);
    }
  }
  @override
  Future<List<Conversation>> conversations() async {
    try {
      final result = await writeApi.invoke('list_conversations');
      final rows = (result['conversations'] as List?) ?? const [];
      return Future.wait(rows.map((value) async {
        final row = Map<String, dynamic>.from(value as Map);
        final participant = Map<String, dynamic>.from(
            (row['participant'] as Map?) ?? const {});
        final last = Map<String, dynamic>.from(
            (row['last_message'] as Map?) ?? const {});
        final hydratedParticipant = await _hydrateAuthor(_authorFromProfile(participant));
        return Conversation(
            id: row['id'].toString(),
            participant: hydratedParticipant,
            lastMessage: last['content']?.toString() ?? '',
            updatedAt: DateTime.parse(row['updated_at'].toString()));
      }));
    } catch (error) {
      throw this.error(error);
    }
  }

  @override
  Future<List<CommunityMessage>> messages(String conversationId) async {
    try {
      final result = await writeApi.invoke('list_messages', {
        'conversation_id': conversationId,
      });
      final rows = (result['messages'] as List?) ?? const [];
      return (rows as List).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        return CommunityMessage(
            id: map['id'].toString(),
            conversationId: conversationId,
            senderId: map['sender_id'].toString(),
            text: map['content']?.toString() ?? '',
            sentAt: DateTime.parse(map['created_at'].toString()),
            status: MessageStatus.sent,
            mediaReference: map['media_reference']?.toString());
      }).toList();
    } catch (error) {
      throw this.error(error);
    }
  }

  @override
  Future<CommunityMessage> sendMessage(String conversationId, String text,
      {String? mediaReference}) async {
    if (text.trim().isEmpty && (mediaReference == null || mediaReference.isEmpty))
      throw const ValidationError('Message cannot be empty.');
    try {
      final result = await writeApi.invoke('send_message', {
        'conversation_id': conversationId,
        'content': text.trim(),
        if (mediaReference != null) 'media_reference': mediaReference,
      });
      final row = Map<String, dynamic>.from(result);
      return CommunityMessage(
          id: row['id'].toString(),
          conversationId: conversationId,
          senderId: row['sender_id'].toString(),
          text: row['content'].toString(),
          sentAt: DateTime.parse(row['created_at'].toString()),
          status: MessageStatus.sent,
          mediaReference: row['media_reference']?.toString());
    } catch (error) {
      throw this.error(error);
    }
  }

}

class SupabaseNotificationRepository extends SupabaseRepositoryBase
    implements NotificationRepository {
  SupabaseNotificationRepository({super.client, super.identity});
  @override
  Future<List<CommunityNotification>> fetchNotifications() async {
    try {
      final result = await writeApi.invoke('list_notifications');
      final rows = (result['notifications'] as List?) ?? const [];
      return (rows as List).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        final actor = Map<String, dynamic>.from(
            (map['actor_profile'] as Map?) ?? const {});
        final actorName = (actor['display_name'] ?? actor['username'] ?? 'مستخدم')
            .toString();
        final type = _notificationType(map['type'].toString());
        return CommunityNotification(
            id: map['id'].toString(),
            type: type,
            title: type == NotificationType.friendRequest
                ? 'طلب صداقة من $actorName'
                : type == NotificationType.friendRequestAccepted
                    ? '$actorName قبل طلب صداقتك'
                    : type == NotificationType.message
                        ? 'رسالة جديدة من $actorName'
                    : type == NotificationType.comment
                        ? 'تعليق جديد من $actorName'
                        : 'إعجاب جديد من $actorName',
            body: type == NotificationType.friendRequest
                ? 'يمكنك قبول الطلب أو رفضه.'
                : type == NotificationType.friendRequestAccepted
                    ? 'أصبحتم أصدقاء الآن.'
                    : type == NotificationType.message
                        ? 'لديك رسالة جديدة في المحادثة.'
                    : 'لديك تفاعل جديد على منشورك.',
            createdAt: DateTime.parse(map['created_at'].toString()),
            isRead: map['is_read'] == true,
            friendRequestId: map['friend_request_id']?.toString());
      }).toList();
    } catch (error) {
      throw this.error(error);
    }
  }

  @override
  Future<int> unreadCount() async {
    try {
      final result = await writeApi.invoke('list_notifications');
      final rows = (result['notifications'] as List?) ?? const [];
      return rows.where((row) => row is Map && row['is_read'] != true).length;
    } catch (error) {
      throw this.error(error);
    }
  }

  @override
  Future<void> markRead(String notificationId) async {
    try {
      await writeApi.invoke('mark_notification_read', {
        'notification_id': notificationId,
      });
    } catch (error) {
      throw this.error(error);
    }
  }
}

class SupabaseVerificationRepository extends SupabaseRepositoryBase
    implements VerificationRepository {
  SupabaseVerificationRepository({super.client, super.identity});
  @override
  Future<VerificationStatus> statusFor(String userId) async {
    try {
      final row = await client
          .from('community_profiles')
          .select('is_verified')
          .eq('user_id', userId)
          .single();
      return VerificationStatus(verified: row['is_verified'] == true);
    } catch (error) {
      throw this.error(error);
    }
  }
}

class SupabaseMediaRepository extends SupabaseRepositoryBase
    implements MediaRepository {
  SupabaseMediaRepository({super.client, super.identity})
      : api = CommunityMediaApi();
  final CommunityMediaApi api;

  Future<PostMedia> uploadForPost({
    required String postId,
    required String path,
    required MediaType type,
    required String mimeType,
    Duration duration = Duration.zero,
  }) =>
      api.uploadFile(
          postId: postId,
          path: path,
          mediaType: type,
          mimeType: mimeType,
          duration: duration);

  @override
  Future<PostMedia> uploadImage(String path) => throw const ValidationError(
      'A post id is required before uploading media.');
  @override
  Future<PostMedia> uploadAudio(String path,
          {Duration duration = Duration.zero}) =>
      throw const ValidationError(
          'A post id is required before uploading media.');
  @override
  Future<void> deleteMedia(String mediaId) =>
      api.delete(PostMedia(id: mediaId, type: MediaType.image, path: ''));
  @override
  Future<String> getMediaUrl(PostMedia media) => api.secureUrl(media);
}

String _mimeFor(String path) {
  final extension = path.split('.').last.toLowerCase();
  return switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'mp3' => 'audio/mpeg',
    'm4a' => 'audio/mp4',
    'aac' => 'audio/aac',
    'ogg' => 'audio/ogg',
    'wav' => 'audio/wav',
    'webm' => 'audio/webm',
    _ =>
      throw const ValidationError('The selected media type is not supported.'),
  };
}

class SupabaseShareRepository implements ShareRepository {
  @override
  Future<ShareReceipt> shareExternally(CommunityPost post) =>
      Future.value(ShareReceipt(postId: post.id, external: true));
  @override
  Future<ShareReceipt> shareToUser(CommunityPost post, String userId) =>
      Future.value(
          ShareReceipt(postId: post.id, recipientId: userId, external: false));
}

Future<CommunityPost> _hydratePostAuthor(CommunityPost post) async {
  try {
    final document = await AppwriteService.instance.getProfile(post.author.id);
    final data = document?.data ?? const <String, dynamic>{};
    final username = data['username']?.toString().trim();
    final displayName = data['displayname']?.toString().trim();
    final imageId = data['profileImageId']?.toString().trim();
    return post.copyWith(author: PostAuthor(
        id: post.author.id,
        username: username?.isNotEmpty == true ? username! : post.author.username,
        displayName: displayName?.isNotEmpty == true ? displayName! : post.author.displayName,
        avatarPath: imageId?.isNotEmpty == true ? imageId : post.author.avatarPath,
        isVerified: post.author.isVerified));
  } catch (_) {
    return post;
  }
}

CommunityPost _postFromRow(Map<String, dynamic> row) {
  final profile = _profileFromRow(Map<String, dynamic>.from(
      (row['community_profiles'] as Map?) ?? const {}));
  final media =
      ((row['community_post_media'] as List?) ?? const []).map((value) {
    final map = Map<String, dynamic>.from(value as Map);
    return PostMedia(
        id: map['id'].toString(),
        type: map['media_type'] == 'audio' ? MediaType.audio : MediaType.image,
        path: map['storage_key'].toString(),
        duration:
            Duration(milliseconds: (map['duration_ms'] as num?)?.toInt() ?? 0));
  }).toList();
  return CommunityPost(
      id: row['id'].toString(),
      author: profile.author,
      text: row['content']?.toString() ?? '',
      link: row['link_url']?.toString(),
      media: media,
      type: PostType.values.firstWhere((type) => type.name == row['post_type'],
          orElse: () => PostType.text),
      createdAt: DateTime.parse(row['created_at'].toString()),
      likeCount: (row['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (row['comment_count'] as num?)?.toInt() ?? 0);
}

CommunityProfile _profileFromRow(Map<String, dynamic> row) {
  final author = PostAuthor(
      id: row['user_id']?.toString() ?? '',
      username: row['username']?.toString() ?? 'user',
      displayName: row['display_name']?.toString() ??
          row['username']?.toString() ??
          'User',
      avatarPath: row['profile_image_reference']?.toString(),
      isVerified: row['is_verified'] == true);
  return CommunityProfile(
      author: author,
      country: row['country']?.toString() ?? '',
      birthDate: row['date_of_birth']?.toString() ?? '',
      bio: row['bio']?.toString() ?? '',
      friendStatus: FriendStatus.none);
}

PostAuthor _authorFromProfile(Map<String, dynamic> row) => PostAuthor(
    id: row['user_id']?.toString() ?? '',
    username: row['username']?.toString() ?? 'user',
    displayName: row['display_name']?.toString() ??
        row['username']?.toString() ?? 'User',
    avatarPath: row['profile_image_reference']?.toString(),
    isVerified: row['is_verified'] == true);

Future<PostAuthor> _hydrateAuthor(PostAuthor author) async {
  try {
    final document = await AppwriteService.instance.getProfile(author.id);
    final data = document?.data ?? const <String, dynamic>{};
    final username = data['username']?.toString().trim();
    final displayName = data['displayname']?.toString().trim();
    final imageId = data['profileImageId']?.toString().trim();
    return PostAuthor(
        id: author.id,
        username: username?.isNotEmpty == true ? username! : author.username,
        displayName:
            displayName?.isNotEmpty == true ? displayName! : author.displayName,
        avatarPath: imageId?.isNotEmpty == true ? imageId : author.avatarPath,
        isVerified: author.isVerified);
  } catch (_) {
    return author;
  }
}

CommunityComment _commentFromRow(Map<String, dynamic> row) {
  final profile = _profileFromRow(Map<String, dynamic>.from(
      (row['community_profiles'] as Map?) ?? const {}));
  return CommunityComment(
      id: row['id'].toString(),
      postId: row['post_id'].toString(),
      author: profile.author,
      text: row['content']?.toString() ?? '',
      createdAt: DateTime.parse(row['created_at'].toString()));
}

NotificationType _notificationType(String value) => value == 'comment'
    ? NotificationType.comment
    : value == 'friend_request'
        ? NotificationType.friendRequest
        : value == 'friend_request_accepted'
            ? NotificationType.friendRequestAccepted
        : value == 'message'
            ? NotificationType.message
        : NotificationType.reaction;

class SupabaseCommunityRealtimeRepository extends SupabaseRepositoryBase
    implements CommunityRealtimeRepository {
  SupabaseCommunityRealtimeRepository({super.client, super.identity});
  @override
  Stream<List<CommunityMessage>> watchMessages(String conversationId) => client
      .from('community_messages')
      .stream(primaryKey: ['id'])
      .eq('conversation_id', conversationId)
      .map((rows) => rows
          .map((row) => CommunityMessage(
              id: row['id'].toString(),
              conversationId: conversationId,
              senderId: row['sender_id'].toString(),
              text: row['content']?.toString() ?? '',
              sentAt: DateTime.parse(row['created_at'].toString()),
              status: MessageStatus.sent))
          .toList());
  @override
  Stream<List<CommunityNotification>> watchNotifications(String userId) =>
      client
          .from('community_notifications')
          .stream(primaryKey: ['id'])
          .eq('recipient_id', userId)
          .map((rows) => rows
              .map((row) => CommunityNotification(
                  id: row['id'].toString(),
                  type: _notificationType(row['type'].toString()),
                  title: row['type'].toString(),
                  body: '',
                  createdAt: DateTime.parse(row['created_at'].toString()),
                  isRead: row['is_read'] == true))
              .toList());
  @override
  Stream<List<CommunityComment>> watchComments(String postId) => client
      .from('community_comments')
      .stream(primaryKey: ['id'])
      .eq('post_id', postId)
      .map((rows) => rows
          .map((row) => CommunityComment(
              id: row['id'].toString(),
              postId: postId,
              author: const PostAuthor(
                  id: '', username: 'community', displayName: 'Community'),
              text: row['content']?.toString() ?? '',
              createdAt: DateTime.parse(row['created_at'].toString())))
          .toList());
  @override
  Stream<List<CommunityPost>> watchLikes(String postId) => client
      .from('community_post_likes')
      .stream(primaryKey: ['post_id', 'user_id'])
      .eq('post_id', postId)
      .map((rows) => rows
          .map((row) => CommunityPost(
              id: postId,
              author: const PostAuthor(
                  id: '', username: 'community', displayName: 'Community'),
              type: PostType.text,
              createdAt: DateTime.parse(row['created_at'].toString()),
              likeCount: rows.length))
          .toList());
}
