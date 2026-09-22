import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/community_models.dart';
import 'community_repositories.dart';
import '../services/appwrite_community_identity.dart';
import '../services/community_backend_config.dart';
import '../services/community_media_api.dart';
import '../services/community_write_api.dart';

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
          .select('*, community_profiles(*), community_post_media(*)')
          .isFilter('deleted_at', null)
          .ilike('content', query.trim().isEmpty ? '%' : '%${query.trim()}%');
      if (before != null)
        request = request.lt('created_at', before.toUtc().toIso8601String());
      final rows = await request.order('created_at', ascending: false).range(
          before == null ? offset : 0,
          (before == null ? offset : 0) + limit - 1);
      return (rows as List)
          .map((row) => _postFromRow(Map<String, dynamic>.from(row as Map)))
          .toList();
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
        'post_type': draft.link != null ? 'link' : 'text',
      });
      final row = await client
          .from('community_posts')
          .select('*, community_profiles(*), community_post_media(*)')
          .eq('id', result['id'].toString())
          .single();
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
          .select('*, community_profiles(*)')
          .eq('post_id', postId)
          .isFilter('deleted_at', null)
          .order('created_at');
      return (rows as List)
          .map((row) => _commentFromRow(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (error) {
      throw this.error(error);
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
      final row = await client
          .from('community_comments')
          .select('*, community_profiles(*)')
          .eq('id', result['id'].toString())
          .single();
      return _commentFromRow(Map<String, dynamic>.from(row));
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
      return _profileFromRow(Map<String, dynamic>.from(row));
    } catch (error) {
      if (error is PostgrestException && error.code == 'PGRST116') {
        final current = await requireUser();
        if (current == userId) {
          final row = await writeApi.invoke('ensure_profile');
          return _profileFromRow(row);
        }
      }
      throw this.error(error);
    }
  }

  @override
  Future<List<CommunityPost>> postsByUser(String userId) async =>
      SupabasePostRepository(client: client, identity: identity)
          .fetchPosts(limit: 50)
          .then((rows) =>
              rows.where((post) => post.author.id == userId).toList());
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
      final rows = await client
          .from('community_friend_requests')
          .select('requester_id,recipient_id,status')
          .or('and(requester_id.eq.$me,recipient_id.eq.$userId),and(requester_id.eq.$userId,recipient_id.eq.$me)')
          .order('created_at', ascending: false)
          .limit(1);
      if ((rows as List).isEmpty) return FriendStatus.none;
      final row = Map<String, dynamic>.from((rows as List).first);
      if (row['status'] == 'accepted') return FriendStatus.friends;
      if (row['requester_id'] == me) return FriendStatus.pending;
      return FriendStatus.incoming;
    } catch (error) {
      throw this.error(error);
    }
  }

  @override
  Future<FriendStatus> sendRequest(String userId) async {
    try {
      final result = await writeApi.invoke('send_friend_request', {'user_id': userId});
      if (result['status'] == 'accepted') return FriendStatus.friends;
      return FriendStatus.pending;
    } catch (error) {
      throw this.error(error);
    }
  }

  @override
  Future<List<Friend>> friends() async {
    final me = await requireUser();
    try {
      final rows = await client
          .from('community_friendships')
          .select('*')
          .or('user_low_id.eq.$me,user_high_id.eq.$me');
      final ids = (rows as List).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        return map['user_low_id'] == me
            ? map['user_high_id']
            : map['user_low_id'];
      }).toList();
      if (ids.isEmpty) return [];
      final profiles = await client
          .from('community_profiles')
          .select('*')
          .inFilter('user_id', ids);
      return (profiles as List).map((row) {
        final profile = _profileFromRow(Map<String, dynamic>.from(row as Map));
        return Friend(id: profile.author.id, user: profile.author);
      }).toList();
    } catch (error) {
      throw this.error(error);
    }
  }
}

class SupabaseChatRepository extends SupabaseRepositoryBase
    implements ChatRepository {
  SupabaseChatRepository({super.client, super.identity});
  @override
  Future<List<Conversation>> conversations() async {
    final me = await requireUser();
    try {
      final members = await client
          .from('community_conversation_members')
          .select('conversation_id')
          .eq('user_id', me);
      final ids =
          (members as List).map((row) => row['conversation_id']).toList();
      if (ids.isEmpty) return [];
      final rows = await client
          .from('community_conversations')
          .select('*')
          .inFilter('id', ids)
          .order('updated_at', ascending: false);
      return (rows as List)
          .map((row) => Conversation(
              id: row['id'].toString(),
              participant: const PostAuthor(
                  id: '', username: 'community', displayName: 'Community'),
              lastMessage: '',
              updatedAt: DateTime.parse(row['updated_at'].toString())))
          .toList();
    } catch (error) {
      throw this.error(error);
    }
  }

  @override
  Future<List<CommunityMessage>> messages(String conversationId) async {
    await _assertMember(conversationId);
    try {
      final rows = await client
          .from('community_messages')
          .select('*')
          .eq('conversation_id', conversationId)
          .isFilter('deleted_at', null)
          .order('created_at')
          .range(0, 99);
      return (rows as List).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        return CommunityMessage(
            id: map['id'].toString(),
            conversationId: conversationId,
            senderId: map['sender_id'].toString(),
            text: map['content']?.toString() ?? '',
            sentAt: DateTime.parse(map['created_at'].toString()),
            status: MessageStatus.sent);
      }).toList();
    } catch (error) {
      throw this.error(error);
    }
  }

  @override
  Future<CommunityMessage> sendMessage(
      String conversationId, String text) async {
    if (text.trim().isEmpty)
      throw const ValidationError('Message cannot be empty.');
    await _assertMember(conversationId);
    try {
      final result = await writeApi.invoke('send_message', {
        'conversation_id': conversationId,
        'content': text.trim(),
      });
      final row = Map<String, dynamic>.from(result);
      return CommunityMessage(
          id: row['id'].toString(),
          conversationId: conversationId,
          senderId: row['sender_id'].toString(),
          text: row['content'].toString(),
          sentAt: DateTime.parse(row['created_at'].toString()),
          status: MessageStatus.sent);
    } catch (error) {
      throw this.error(error);
    }
  }

  Future<void> _assertMember(String conversationId) async {
    final me = await requireUser();
    final rows = await client
        .from('community_conversation_members')
        .select('conversation_id')
        .eq('conversation_id', conversationId)
        .eq('user_id', me);
    if ((rows as List).isEmpty)
      throw const PermissionError('You are not a member of this conversation.');
  }
}

class SupabaseNotificationRepository extends SupabaseRepositoryBase
    implements NotificationRepository {
  SupabaseNotificationRepository({super.client, super.identity});
  @override
  Future<List<CommunityNotification>> fetchNotifications() async {
    final me = await requireUser();
    try {
      final rows = await client
          .from('community_notifications')
          .select('*')
          .eq('recipient_id', me)
          .order('created_at', ascending: false)
          .range(0, 49);
      return (rows as List).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        return CommunityNotification(
            id: map['id'].toString(),
            type: _notificationType(map['type'].toString()),
            title: map['type'].toString(),
            body: '',
            createdAt: DateTime.parse(map['created_at'].toString()),
            isRead: map['is_read'] == true);
      }).toList();
    } catch (error) {
      throw this.error(error);
    }
  }

  @override
  Future<int> unreadCount() async {
    final me = await requireUser();
    try {
      final rows = await client
          .from('community_notifications')
          .select('id')
          .eq('recipient_id', me)
          .eq('is_read', false);
      return (rows as List).length;
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
