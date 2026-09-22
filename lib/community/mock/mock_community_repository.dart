import '../models/community_models.dart';
import '../repositories/community_repositories.dart';

class MockCommunityRepository implements CommunityRepository {
  MockCommunityRepository() {
    _posts = _seedPosts();
    _comments = {
      'post-1': [
        CommunityComment(
            id: 'comment-1',
            postId: 'post-1',
            author: _authors[1],
            text: 'فكرة جميلة، متحمس للمناقشة.',
            createdAt: DateTime.now().subtract(const Duration(minutes: 32)))
      ],
      'post-2': [
        CommunityComment(
            id: 'comment-2',
            postId: 'post-2',
            author: _authors[2],
            text: 'الصورة رائعة جدًا.',
            createdAt: DateTime.now().subtract(const Duration(hours: 2)))
      ],
    };
  }

  late List<CommunityPost> _posts;
  late Map<String, List<CommunityComment>> _comments;
  final Map<String, bool> _likes = {};

  static const _authors = <PostAuthor>[
    PostAuthor(
        id: 'anitv', username: 'AniTV', displayName: 'AniTV', isVerified: true),
    PostAuthor(id: 'sora', username: 'sora_ani', displayName: 'سارة الأنمي'),
    PostAuthor(
        id: 'otaku', username: 'otaku_world', displayName: 'عالم الأوتاكو'),
    PostAuthor(
        id: 'manga_fan', username: 'manga_fan', displayName: 'قارئ مانغا'),
  ];

  List<CommunityPost> _seedPosts() => [
        CommunityPost(
            id: 'post-1',
            author: _authors[0],
            text:
                'مرحبًا بكم في مجتمع AniTV! شاركونا أعمالكم المفضلة وانطباعاتكم.',
            type: PostType.text,
            createdAt: DateTime.now().subtract(const Duration(minutes: 18)),
            likeCount: 42,
            commentCount: 1),
        CommunityPost(
            id: 'post-2',
            author: _authors[1],
            text: 'ما الأنمي الذي تنصحون بمشاهدته هذا الأسبوع؟',
            media: const [
              PostMedia(
                  id: 'media-1',
                  type: MediaType.image,
                  path:
                      'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=900')
            ],
            type: PostType.image,
            createdAt: DateTime.now().subtract(const Duration(hours: 1)),
            likeCount: 18,
            commentCount: 1),
        CommunityPost(
            id: 'post-3',
            author: _authors[2],
            text: 'دليل سريع لمحبي القصص المصورة والأنمي.',
            link: 'https://anitv-tau.vercel.app',
            type: PostType.link,
            createdAt: DateTime.now().subtract(const Duration(hours: 3)),
            likeCount: 9),
        CommunityPost(
            id: 'post-4',
            author: _authors[3],
            text: 'رسالة صوتية قصيرة من مجتمع القراء.',
            media: const [
              PostMedia(
                  id: 'media-2',
                  type: MediaType.audio,
                  path: 'mock://community/audio',
                  duration: Duration(seconds: 24))
            ],
            type: PostType.audio,
            createdAt: DateTime.now().subtract(const Duration(hours: 5)),
            likeCount: 7),
        CommunityPost(
            id: 'post-5',
            author: _authors[1],
            text: 'أجمل لحظة شاهدتموها في موسم الشتاء؟',
            type: PostType.text,
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
            likeCount: 12),
        CommunityPost(
            id: 'post-6',
            author: _authors[0],
            text: 'تذكير: يمكنكم استخدام قائمة المصادر لاكتشاف محتوى جديد.',
            type: PostType.text,
            createdAt:
                DateTime.now().subtract(const Duration(days: 1, hours: 2)),
            likeCount: 25),
        CommunityPost(
            id: 'post-7',
            author: _authors[2],
            text: 'هل تفضلون القراءة بالألوان أم بالأبيض والأسود؟',
            type: PostType.text,
            createdAt: DateTime.now().subtract(const Duration(days: 2)),
            likeCount: 6),
        CommunityPost(
            id: 'post-8',
            author: _authors[3],
            text: 'اقتراحاتكم لفصل مانغا يستحق القراءة الليلة؟',
            type: PostType.text,
            createdAt:
                DateTime.now().subtract(const Duration(days: 2, hours: 3)),
            likeCount: 14),
      ];

  @override
  Future<List<CommunityPost>> fetchPosts(
      {int offset = 0,
      int limit = 8,
      String query = '',
      DateTime? before}) async {
    await Future<void>.delayed(const Duration(milliseconds: 260));
    final q = query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _posts
        : _posts
            .where((post) =>
                '${post.text} ${post.author.username} ${post.author.displayName}'
                    .toLowerCase()
                    .contains(q))
            .toList()
      ..removeWhere(
          (post) => before != null && !post.createdAt.isBefore(before));
    if (offset >= filtered.length) return [];
    return filtered.skip(offset).take(limit).toList();
  }

  @override
  Future<CommunityPost> publishPost(
      {required String text,
      String? imagePath,
      String? link,
      String? audioPath,
      Duration audioDuration = Duration.zero}) async {
    await Future<void>.delayed(const Duration(milliseconds: 320));
    final media = <PostMedia>[];
    if (imagePath != null)
      media.add(PostMedia(
          id: 'media-${DateTime.now().microsecondsSinceEpoch}',
          type: MediaType.image,
          path: imagePath));
    if (audioPath != null)
      media.add(PostMedia(
          id: 'media-${DateTime.now().microsecondsSinceEpoch}',
          type: MediaType.audio,
          path: audioPath,
          duration: audioDuration));
    final type =
        media.any((item) => item.type == MediaType.image) && link != null
            ? PostType.mixed
            : media.any((item) => item.type == MediaType.image)
                ? PostType.image
                : media.any((item) => item.type == MediaType.audio)
                    ? PostType.audio
                    : link != null
                        ? PostType.link
                        : PostType.text;
    final post = CommunityPost(
        id: 'post-${DateTime.now().microsecondsSinceEpoch}',
        author: _authors[0],
        text: text.trim(),
        link: link?.trim(),
        media: media,
        type: type,
        createdAt: DateTime.now());
    _posts.insert(0, post);
    return post;
  }

  @override
  Future<CommunityPost> toggleLike(CommunityPost post) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final next = !(post.likedByMe || _likes[post.id] == true);
    _likes[post.id] = next;
    final updated = post.copyWith(
        likedByMe: next,
        likeCount: (post.likeCount + (next ? 1 : -1)).clamp(0, 1 << 30));
    final index = _posts.indexWhere((item) => item.id == post.id);
    if (index >= 0) _posts[index] = updated;
    return updated;
  }

  @override
  Future<void> deletePost(String postId) async {
    _posts.removeWhere((post) => post.id == postId);
    _comments.remove(postId);
  }

  @override
  Future<List<CommunityComment>> fetchComments(String postId) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return List.unmodifiable(_comments[postId] ?? const []);
  }

  @override
  Future<CommunityComment> addComment(String postId, String text) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    final comment = CommunityComment(
        id: 'comment-${DateTime.now().microsecondsSinceEpoch}',
        postId: postId,
        author: _authors[0],
        text: text.trim(),
        createdAt: DateTime.now());
    (_comments[postId] ??= []).add(comment);
    final index = _posts.indexWhere((post) => post.id == postId);
    if (index >= 0)
      _posts[index] =
          _posts[index].copyWith(commentCount: _posts[index].commentCount + 1);
    return comment;
  }
}

class MockPostRepository implements PostRepository {
  MockPostRepository(this.source);
  final MockCommunityRepository source;
  @override
  Future<List<CommunityPost>> fetchPosts(
          {int offset = 0,
          int limit = 8,
          String query = '',
          DateTime? before}) =>
      source.fetchPosts(
          offset: offset, limit: limit, query: query, before: before);
  @override
  Future<CommunityPost> create(CreatePostDraft draft) => source.publishPost(
      text: draft.text,
      imagePath: draft.imagePath,
      link: draft.link,
      audioPath: draft.audioPath,
      audioDuration: draft.audioDuration);
}

class MockCommentRepository implements CommentRepository {
  MockCommentRepository(this.source);
  final MockCommunityRepository source;
  @override
  Future<List<CommunityComment>> fetchForPost(String postId) =>
      source.fetchComments(postId);
  @override
  Future<CommunityComment> create(String postId, String text) =>
      source.addComment(postId, text);

  @override
  Future<void> delete(String commentId) async {}
}

class MockLikeRepository implements LikeRepository {
  MockLikeRepository(this.source);
  final MockCommunityRepository source;
  @override
  Future<CommunityPost> toggle(CommunityPost post) => source.toggleLike(post);
}

class MockNotificationRepository implements NotificationRepository {
  final List<CommunityNotification> _items = [
    CommunityNotification(
        id: 'notification-1',
        type: NotificationType.reaction,
        title: 'تفاعل جديد',
        body: 'أعجب AniTV بمنشورك',
        createdAt: DateTime.now().subtract(const Duration(minutes: 12))),
    CommunityNotification(
        id: 'notification-2',
        type: NotificationType.comment,
        title: 'تعليق جديد',
        body: 'أضاف أحد الأعضاء تعليقًا على منشورك',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        isRead: true),
  ];
  @override
  Future<List<CommunityNotification>> fetchNotifications() async =>
      List.unmodifiable(_items);
  @override
  Future<int> unreadCount() async =>
      _items.where((item) => !item.isRead).length;
}

class MockMediaRepository implements MediaRepository {
  @override
  Future<PostMedia> uploadImage(String path) async => PostMedia(
      id: 'mock-image-${DateTime.now().microsecondsSinceEpoch}',
      type: MediaType.image,
      path: path);
  @override
  Future<PostMedia> uploadAudio(String path,
          {Duration duration = Duration.zero}) async =>
      PostMedia(
          id: 'mock-audio-${DateTime.now().microsecondsSinceEpoch}',
          type: MediaType.audio,
          path: path,
          duration: duration);
  @override
  Future<void> deleteMedia(String mediaId) async {}
  @override
  Future<String> getMediaUrl(PostMedia media) async => media.url ?? media.path;
}

class MockProfileRepository implements ProfileRepository {
  MockProfileRepository(this.source);
  final MockCommunityRepository source;
  final Map<String, CommunityProfile> _profiles = {
    'anitv': CommunityProfile(
        author: MockCommunityRepository._authors[0],
        bio: 'الحساب الرسمي لمجتمع AniTV.',
        country: 'العالم العربي',
        favoriteTitles: ['One Piece', 'Solo Leveling']),
    'sora': CommunityProfile(
        author: MockCommunityRepository._authors[1],
        bio: 'أشارك انطباعاتي عن الأنمي والمانغا.',
        country: 'المغرب',
        birthDate: '2000-05-12',
        favoriteTitles: ['Frieren', 'Blue Lock']),
    'otaku': CommunityProfile(
        author: MockCommunityRepository._authors[2],
        bio: 'أكتشف أعمالًا جديدة كل يوم.',
        country: 'مصر',
        favoriteTitles: ['Naruto']),
    'manga_fan': CommunityProfile(
        author: MockCommunityRepository._authors[3],
        bio: 'قارئ مانغا ومحب للقصص المصورة.',
        country: 'الأردن',
        favoriteTitles: ['Berserk']),
  };
  @override
  Future<CommunityProfile> getProfile(String userId) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    return _profiles[userId] ??
        CommunityProfile(author: MockCommunityRepository._authors[1]);
  }

  @override
  Future<List<CommunityPost>> postsByUser(String userId) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return source.fetchPosts(limit: 50).then(
        (items) => items.where((post) => post.author.id == userId).toList());
  }

  @override
  Future<CommunityProfile> updateBio(String userId, String bio) async {
    final profile = await getProfile(userId);
    final updated = profile.copyWith(bio: bio.trim());
    _profiles[userId] = updated;
    return updated;
  }
}

class MockFriendRepository implements FriendRepository {
  final Map<String, FriendStatus> _statuses = {
    'sora': FriendStatus.none,
    'otaku': FriendStatus.friends
  };
  @override
  Future<FriendStatus> statusFor(String userId) async =>
      _statuses[userId] ?? FriendStatus.none;
  @override
  Future<FriendStatus> sendRequest(String userId) async {
    _statuses[userId] = FriendStatus.pending;
    return FriendStatus.pending;
  }

  @override
  Future<FriendStatus> respondToRequest(String requestId,
      {required bool accept}) async =>
      accept ? FriendStatus.friends : FriendStatus.none;

  @override
  Future<List<FriendRequest>> incomingRequests() async => const [];

  @override
  Future<List<Friend>> friends() async => [
        Friend(id: 'friend-1', user: MockCommunityRepository._authors[2]),
        Friend(id: 'friend-2', user: MockCommunityRepository._authors[3])
      ];
}

class MockChatRepository implements ChatRepository {
  @override
  Future<Conversation> openConversation(String userId, PostAuthor participant) async =>
      Conversation(id: 'conversation-$userId', participant: participant, lastMessage: '', updatedAt: DateTime.now());
  final conversationsData = <Conversation>[
    Conversation(
        id: 'conversation-1',
        participant: MockCommunityRepository._authors[2],
        lastMessage: 'سأرسل لك اقتراحات جديدة قريبًا.',
        updatedAt: _chatTime(1),
        unreadCount: 2),
    Conversation(
        id: 'conversation-2',
        participant: MockCommunityRepository._authors[1],
        lastMessage: 'هل شاهدت الحلقة الجديدة؟',
        updatedAt: _chatTime(4)),
  ];
  final Map<String, List<CommunityMessage>> messagesData = {
    'conversation-1': [
      CommunityMessage(
          id: 'message-1',
          conversationId: 'conversation-1',
          senderId: 'otaku',
          text: 'مرحبًا! ما العمل الذي تتابعه حاليًا؟',
          sentAt: _chatTime(12),
          status: MessageStatus.read),
      CommunityMessage(
          id: 'message-2',
          conversationId: 'conversation-1',
          senderId: 'guest',
          text: 'أتابع موسمًا جديدًا ومتحمس للنقاش.',
          sentAt: _chatTime(10),
          status: MessageStatus.read),
      CommunityMessage(
          id: 'message-3',
          conversationId: 'conversation-1',
          senderId: 'otaku',
          text: 'سأرسل لك اقتراحات جديدة قريبًا.',
          sentAt: _chatTime(1),
          status: MessageStatus.delivered),
    ],
  };
  static DateTime _chatTime(int minutesAgo) =>
      DateTime.now().subtract(Duration(minutes: minutesAgo));
  @override
  Future<List<Conversation>> conversations() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return List.unmodifiable(conversationsData);
  }

  @override
  Future<List<CommunityMessage>> messages(String conversationId) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    return List.unmodifiable(messagesData[conversationId] ?? const []);
  }

  @override
  Future<CommunityMessage> sendMessage(
      String conversationId, String text) async {
    final message = CommunityMessage(
        id: 'message-${DateTime.now().microsecondsSinceEpoch}',
        conversationId: conversationId,
        senderId: 'guest',
        text: text.trim(),
        sentAt: DateTime.now(),
        status: MessageStatus.sent);
    (messagesData[conversationId] ??= []).add(message);
    return message;
  }
}

class MockVerificationRepository implements VerificationRepository {
  @override
  Future<VerificationStatus> statusFor(String userId) async =>
      VerificationStatus(verified: userId == 'anitv');
}

class MockShareRepository implements ShareRepository {
  @override
  Future<ShareReceipt> shareExternally(CommunityPost post) async =>
      ShareReceipt(postId: post.id, external: true);
  @override
  Future<ShareReceipt> shareToUser(CommunityPost post, String userId) async =>
      ShareReceipt(postId: post.id, recipientId: userId, external: false);
}
