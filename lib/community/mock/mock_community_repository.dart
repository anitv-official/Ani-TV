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
      {int offset = 0, int limit = 8, String query = ''}) async {
    await Future<void>.delayed(const Duration(milliseconds: 260));
    final q = query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _posts
        : _posts
            .where((post) =>
                '${post.text} ${post.author.username} ${post.author.displayName}'
                    .toLowerCase()
                    .contains(q))
            .toList();
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
          {int offset = 0, int limit = 8, String query = ''}) =>
      source.fetchPosts(offset: offset, limit: limit, query: query);
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
