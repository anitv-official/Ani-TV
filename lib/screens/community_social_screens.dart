import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../community/models/community_models.dart';
import '../community/services/community_repository_factory.dart';
import '../community/services/appwrite_community_identity.dart';
import '../community/widgets/community_widgets.dart';
import '../theme/app_theme.dart';
import '../providers/app_state_provider.dart';
import '../services/appwrite_service.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.userId, this.isCurrentUser = false, this.avatarFuture});
  final String userId;
  final bool isCurrentUser;
  final Future<Uint8List>? avatarFuture;
  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final profiles = CommunityRepositoryFactory.profile();
  final friends = CommunityRepositoryFactory.friends();
  final community = CommunityRepositoryFactory.community();
  late Future<CommunityProfile> profileFuture;
  late Future<List<CommunityPost>> postsFuture;
  List<CommunityPost> loadedPosts = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    profileFuture = profiles.getProfile(widget.userId);
    postsFuture = profiles.postsByUser(widget.userId);
  }

  Future<FriendStatus> _addFriend() async {
    final status = await friends.sendRequest(widget.userId);
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(status == FriendStatus.pending
              ? 'تم إرسال طلب الصداقة.'
              : 'تم تحديث حالة الصداقة.')));
    return status;
  }

  Future<void> _toggleLike(CommunityPost post) async {
    final updated = await community.toggleLike(post);
    if (!mounted) return;
    setState(() {
      final index = loadedPosts.indexWhere((item) => item.id == post.id);
      if (index >= 0) loadedPosts[index] = updated;
    });
  }

  Future<void> _showComments(CommunityPost post) async {
    final items = await community.fetchComments(post.id);
    if (!mounted) return;
    final input = TextEditingController();
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (_, setDialogState) => AlertDialog(
                title: const Text('التعليقات'),
                content: SizedBox(
                    width: double.maxFinite,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      if (items.isEmpty)
                        const Text('لا توجد تعليقات بعد.')
                      else
                        ...items.map((item) => ListTile(
                            dense: true,
                            title: Text(item.author.label),
                            subtitle: Text(item.text))),
                      TextField(
                          controller: input,
                          decoration: const InputDecoration(
                              hintText: 'اكتب تعليقًا...'))
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('إغلاق')),
                  FilledButton(
                      onPressed: () async {
                        if (input.text.trim().isEmpty) return;
                        final comment =
                            await community.addComment(post.id, input.text);
                        input.clear();
                        setDialogState(() => items.add(comment));
                      },
                      child: const Text('إرسال'))
                ])));
    input.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
          title: Text(widget.isCurrentUser ? 'ملفي الشخصي' : 'ملف المستخدم')),
      body: FutureBuilder<CommunityProfile>(
          future: profileFuture,
          builder: (_, snapshot) {
            if (snapshot.hasError)
              return Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('تعذر تحميل الملف الشخصي.')));
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final profile = snapshot.data!;
            return FutureBuilder<List<CommunityPost>>(
                future: postsFuture,
                builder: (_, postsSnapshot) {
                  if (postsSnapshot.hasData && loadedPosts.isEmpty) {
                    loadedPosts = [...postsSnapshot.data!];
                  }
                  final posts = loadedPosts;
                  return ListView(children: [
                    _ProfileHeader(
                        profile: profile,
                        showAddBadge: !widget.isCurrentUser &&
                            profile.friendStatus != FriendStatus.friends,
                        avatarFuture: widget.avatarFuture ??
                            (profile.author.avatarPath == null
                                ? null
                                : AppwriteService.instance.profileImageBytes(
                                    profile.author.avatarPath!)),
                        onFriend: widget.isCurrentUser ||
                                profile.friendStatus != FriendStatus.none
                            ? null
                            : _addFriend,
                        onMessage: widget.isCurrentUser
                            ? null
                            : () async {
                                try {
                                  final conversation = await CommunityRepositoryFactory
                                      .chat()
                                      .openConversation(profile.author.id,
                                          profile.author);
                                  if (!context.mounted) return;
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => ConversationScreen(
                                              conversation: conversation)));
                                } catch (error) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(error.toString())));
                                  }
                                }
                              }),
                    if (profile.bio.isNotEmpty)
                      _InfoSection(
                          title: 'نبذة',
                          child: Text(profile.bio,
                              style: const TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                  height: 1.5))),
                    if (profile.favoriteTitles.isNotEmpty)
                      _InfoSection(
                          title: 'المفضلات',
                          child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: profile.favoriteTitles
                                  .map((value) => Chip(label: Text(value)))
                                  .toList())),
                    const Divider(height: 1, color: AppTheme.borderColor),
                    const Padding(
                        padding: EdgeInsets.fromLTRB(16, 18, 16, 4),
                        child: Text('المنشورات',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900))),
                    if (posts.isEmpty)
                      const Padding(
                          padding: EdgeInsets.all(28),
                          child: Text('لا توجد منشورات بعد.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppTheme.textSecondaryColor)))
                    else
                      ...posts.map((post) => CommunityPostItem(
                          post: post,
                          onLike: () => _toggleLike(post),
                          onComment: () => _showComments(post),
                          onProfile: () {},
                          onShare: () {},
                          canDelete: widget.isCurrentUser,
                          onDelete: () async {
                            try {
                              await community.deletePost(post.id);
                              if (mounted) {
                                setState(() => loadedPosts
                                    .removeWhere((item) => item.id == post.id));
                              }
                            } catch (error) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error.toString())));
                              }
                            }
                          }))
                  ]);
                });
          }));
}

class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final account = context.watch<AppStateProvider>();
    return FutureBuilder<String?>(
      future: const AppwriteCommunityIdentity().currentUserId(),
      builder: (_, snapshot) {
        if (snapshot.hasError)
          return const Scaffold(
              body: Center(child: Text('تعذر التحقق من جلسة المستخدم.')));
        final userId = snapshot.data;
        if (userId == null || userId.isEmpty)
          return const Scaffold(
              body: Center(child: Text('سجّل الدخول أولًا لفتح ملفك الشخصي.')));
        return UserProfileScreen(
            userId: userId,
            isCurrentUser: true,
            avatarFuture: account.profileImageBytes);
      });
  }
}

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final chat = CommunityRepositoryFactory.chat();
  late Future<List<Conversation>> future;
  @override
  void initState() {
    super.initState();
    future = chat.conversations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('الرسائل')),
      body: FutureBuilder<List<Conversation>>(
        future: future,
        builder: (_, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final conversations = snapshot.data!;
          if (conversations.isEmpty)
            return const CommunityEmptyState(
                title: 'لا توجد محادثات بعد',
                subtitle: 'ابدأ محادثة من ملف أحد المستخدمين.');
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: conversations.length,
            separatorBuilder: (_, __) => const Divider(
                height: 1, indent: 78, color: AppTheme.borderColor),
            itemBuilder: (_, index) {
              final item = conversations[index];
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                leading: CommunityAvatar(author: item.participant, radius: 26),
                title: Row(children: [
                  Expanded(
                      child: Text(item.participant.displayName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800))),
                  if (item.participant.isVerified) const VerifiedBadge(size: 15)
                ]),
                subtitle: Text(item.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textSecondaryColor)),
                trailing: item.unreadCount > 0
                    ? CircleAvatar(
                        radius: 12,
                        backgroundColor: AppTheme.primaryColor,
                        child: Text('${item.unreadCount}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)))
                    : null,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            ConversationScreen(conversation: item))),
              );
            },
          );
        },
      ),
    );
  }
}

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key, required this.conversation});
  final Conversation conversation;
  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final chat = CommunityRepositoryFactory.chat();
  final input = TextEditingController();
  final scroll = ScrollController();
  String? pendingImage;
  late Future<List<CommunityMessage>> future;
  List<CommunityMessage> messages = [];
  String? currentUserId;
  Timer? refreshTimer;
  @override
  void initState() {
    super.initState();
    future = chat.messages(widget.conversation.id);
    _loadIdentity();
    refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  Future<void> _loadIdentity() async {
    final id = await const AppwriteCommunityIdentity().currentUserId();
    if (mounted) setState(() => currentUserId = id);
  }

  Future<void> _refresh() async {
    try {
      final latest = await chat.messages(widget.conversation.id);
      if (!mounted) return;
      final byId = {for (final message in messages) message.id: message};
      for (final message in latest) byId[message.id] = message;
      final merged = byId.values.toList()
        ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
      if (merged.length != messages.length ||
          merged.any((message) => !messages.any((old) => old.id == message.id))) {
        setState(() => messages = merged);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final value = input.text.trim();
    if (value.isEmpty && pendingImage == null) return;
    String? mediaReference;
    if (pendingImage != null) {
      final userId = await const AppwriteCommunityIdentity().currentUserId();
      if (userId == null) return;
      mediaReference = await AppwriteService.instance
          .uploadChatImage(userId: userId, path: pendingImage!);
    }
    final message = await chat.sendMessage(widget.conversation.id, value,
        mediaReference: mediaReference);
    if (!mounted) return;
    setState(() {
      messages.add(message);
      input.clear();
      pendingImage = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients)
        scroll.animateTo(scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => UserProfileScreen(
                      userId: widget.conversation.participant.id))),
          child: Row(children: [
            CommunityAvatar(
                author: widget.conversation.participant, radius: 18),
            const SizedBox(width: 9),
            Flexible(
                child: Text(widget.conversation.participant.displayName,
                    overflow: TextOverflow.ellipsis)),
            if (widget.conversation.participant.isVerified) ...[
              const SizedBox(width: 4),
              const VerifiedBadge(size: 15)
            ]
          ]),
        ),
      ),
      body: FutureBuilder<List<CommunityMessage>>(
        future: future,
        builder: (_, snapshot) {
          if (snapshot.hasData && messages.isEmpty)
            messages = [...snapshot.data!];
          return Column(
            children: [
              Expanded(
                  child: messages.isEmpty && !snapshot.hasData
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          controller: scroll,
                          padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
                          itemCount: messages.length,
                          itemBuilder: (_, index) =>
                              _MessageBubble(
                                  message: messages[index],
                                  currentUserId: currentUserId))),
              SafeArea(
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            IconButton(
                                onPressed: () async {
                                  final result = await FilePicker.platform
                                      .pickFiles(type: FileType.image);
                                  final path = result?.files.single.path;
                                  if (path != null && mounted) {
                                    setState(() => pendingImage = path);
                                  }
                                },
                                icon: const Icon(Icons.image_outlined)),
                            Expanded(
                                child: TextField(
                                    controller: input,
                                    minLines: 1,
                                    maxLines: 4,
                                    textInputAction: TextInputAction.newline,
                                    decoration: const InputDecoration(
                                        hintText: 'اكتب رسالة...'))),
                            const SizedBox(width: 8),
                            IconButton.filled(
                                onPressed: _send,
                                icon: const Icon(Icons.send_rounded))
                          ]))),
            ],
          );
        },
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.currentUserId});
  final CommunityMessage message;
  final String? currentUserId;
  @override
  Widget build(BuildContext context) {
    final mine = currentUserId != null && message.senderId == currentUserId;
    return Align(
        alignment: mine
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * .78),
            margin: const EdgeInsets.only(bottom: 9),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
                color: mine
                    ? AppTheme.primaryColor.withOpacity(.22)
                    : AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (message.mediaReference != null &&
                  message.mediaReference!.isNotEmpty)
                FutureBuilder<Uint8List>(
                    future: AppwriteService.instance
                        .profileImageBytes(message.mediaReference!),
                    builder: (_, snapshot) => snapshot.hasData
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(snapshot.data!,
                                width: 190, height: 190, fit: BoxFit.cover))
                        : const SizedBox(
                            width: 190,
                            height: 120,
                            child: Center(
                                child: CircularProgressIndicator(strokeWidth: 2)))),
              if (message.mediaReference != null && message.text.isNotEmpty)
                const SizedBox(height: 6),
              if (message.text.isNotEmpty)
              Text(message.text,
                  style: const TextStyle(color: Colors.white, height: 1.4)),
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_time(message.sentAt),
                    style: const TextStyle(
                        color: AppTheme.textMutedColor, fontSize: 10)),
                if (mine) ...[
                  const SizedBox(width: 4),
                  Icon(
                      message.status == MessageStatus.read
                          ? Icons.done_all_rounded
                          : Icons.done_rounded,
                      size: 14,
                      color: AppTheme.primaryColor)
                ]
              ])
            ])));
  }
}

class _ProfileHeader extends StatefulWidget {
  const _ProfileHeader(
      {required this.profile,
      required this.onFriend,
      required this.onMessage,
      this.showAddBadge = false,
      this.avatarFuture});
  final CommunityProfile profile;
  final Future<FriendStatus> Function()? onFriend;
  final VoidCallback? onMessage;
  final bool showAddBadge;
  final Future<Uint8List>? avatarFuture;
  @override
  State<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<_ProfileHeader> {
  bool busy = false;
  FriendStatus? status;

  @override
  Widget build(BuildContext context) {
    final currentStatus = status ?? widget.profile.friendStatus;
    final canShowBadge = widget.showAddBadge &&
        currentStatus != FriendStatus.friends && !busy;
    final friendLabel = switch (currentStatus) {
      FriendStatus.pending => 'تم إرسال الطلب',
      FriendStatus.incoming => 'لديك طلب صداقة',
      FriendStatus.friends => 'أصدقاء',
      _ => 'إضافة صديق',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Container(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primaryColor.withOpacity(.18),
                    AppTheme.surfaceColor.withOpacity(.72)
                  ]),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(.18))),
          child: Column(children: [
        CommunityAvatar(
            author: widget.profile.author,
            radius: 48,
            avatarFuture: widget.avatarFuture,
            showAddBadge: canShowBadge),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(widget.profile.author.displayName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900)),
          if (widget.profile.author.isVerified) ...[
            const SizedBox(width: 5),
            const VerifiedBadge(size: 18)
          ]
        ]),
        const SizedBox(height: 4),
        Text('@${widget.profile.author.username}',
            style: const TextStyle(color: AppTheme.textSecondaryColor)),
        if (widget.profile.country.isNotEmpty ||
            widget.profile.birthDate.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.profile.country.isNotEmpty)
                  _ProfileChip(
                      icon: Icons.public_rounded,
                      label: widget.profile.country),
                if (widget.profile.birthDate.isNotEmpty)
                  _ProfileChip(
                      icon: Icons.cake_outlined,
                      label: widget.profile.birthDate)
              ])
        ],
        if (currentStatus != FriendStatus.none &&
            currentStatus != FriendStatus.friends) ...[
          const SizedBox(height: 10),
          AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: _StatusPill(
                  key: ValueKey(currentStatus), status: currentStatus))
        ],
        if (widget.onFriend != null || widget.onMessage != null) ...[
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            OutlinedButton.icon(
                onPressed: busy || widget.onFriend == null
                    ? null
                    : () async {
                        setState(() => busy = true);
                        try {
                          final next = await widget.onFriend!.call();
                          if (mounted) setState(() => status = next);
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      },
                icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: busy
                        ? const SizedBox(
                            key: ValueKey('busy'),
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(
                            currentStatus == FriendStatus.pending
                                ? Icons.schedule_rounded
                                : Icons.person_add_alt_1_rounded,
                            key: ValueKey(currentStatus))),
                label: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: Text(friendLabel, key: ValueKey(friendLabel)))),
            const SizedBox(width: 10),
            FilledButton.icon(
                onPressed: widget.onMessage,
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('محادثة'))
          ])
        ]
      ])));
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: AppTheme.backgroundColor.withOpacity(.48),
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: AppTheme.primaryColor),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                color: AppTheme.textSecondaryColor, fontSize: 11))
      ]));
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({super.key, required this.status});
  final FriendStatus status;
  @override
  Widget build(BuildContext context) {
    final incoming = status == FriendStatus.incoming;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
            color: (incoming ? Colors.orangeAccent : AppTheme.primaryColor)
                .withOpacity(.14),
            borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(incoming ? Icons.person_add_alt_1_rounded : Icons.schedule_rounded,
              size: 15,
              color: incoming ? Colors.orangeAccent : AppTheme.primaryColor),
          const SizedBox(width: 6),
          Text(incoming ? 'لديك طلب صداقة' : 'طلب قيد الانتظار',
              style: TextStyle(
                  color: incoming ? Colors.orangeAccent : AppTheme.primaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800))
        ]));
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                color: AppTheme.primaryColor, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        child
      ]));
}

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
