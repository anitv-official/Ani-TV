import 'package:flutter/material.dart';
import '../community/mock/mock_community_repository.dart';
import '../community/models/community_models.dart';
import '../community/widgets/community_widgets.dart';
import '../theme/app_theme.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.userId});
  final String userId;
  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final profiles = MockProfileRepository(MockCommunityRepository());
  final friends = MockFriendRepository();
  late Future<CommunityProfile> profileFuture;
  late Future<List<CommunityPost>> postsFuture;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    profileFuture = profiles.getProfile(widget.userId);
    postsFuture = profiles.postsByUser(widget.userId);
  }

  Future<void> _addFriend() async {
    final status = await friends.sendRequest(widget.userId);
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(status == FriendStatus.pending
              ? 'تم إرسال طلب الصداقة.'
              : 'تم تحديث حالة الصداقة.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body: FutureBuilder<CommunityProfile>(
          future: profileFuture,
          builder: (_, snapshot) {
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final profile = snapshot.data!;
            return FutureBuilder<List<CommunityPost>>(
                future: postsFuture,
                builder: (_, postsSnapshot) {
                  final posts = postsSnapshot.data ?? const <CommunityPost>[];
                  return ListView(children: [
                    _ProfileHeader(
                        profile: profile,
                        onFriend: profile.friendStatus == FriendStatus.friends
                            ? null
                            : _addFriend,
                        onMessage: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ConversationScreen(
                                    conversation: Conversation(
                                        id: 'conversation-${profile.author.id}',
                                        participant: profile.author,
                                        lastMessage: '',
                                        updatedAt: DateTime.now()))))),
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
                          onLike: () {},
                          onComment: () {},
                          onProfile: () {},
                          onShare: () {}))
                  ]);
                });
          }));
}

class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => const UserProfileScreen(userId: 'sora');
}

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final chat = MockChatRepository();
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
  final chat = MockChatRepository();
  final input = TextEditingController();
  final scroll = ScrollController();
  late Future<List<CommunityMessage>> future;
  List<CommunityMessage> messages = [];
  @override
  void initState() {
    super.initState();
    future = chat.messages(widget.conversation.id);
  }

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final value = input.text.trim();
    if (value.isEmpty) return;
    final message = await chat.sendMessage(widget.conversation.id, value);
    if (!mounted) return;
    setState(() {
      messages.add(message);
      input.clear();
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
                              _MessageBubble(message: messages[index]))),
              SafeArea(
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
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
  const _MessageBubble({required this.message});
  final CommunityMessage message;
  @override
  Widget build(BuildContext context) {
    final mine = message.senderId == 'guest';
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

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader(
      {required this.profile, required this.onFriend, required this.onMessage});
  final CommunityProfile profile;
  final VoidCallback? onFriend;
  final VoidCallback onMessage;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      child: Column(children: [
        CommunityAvatar(author: profile.author, radius: 48),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(profile.author.displayName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900)),
          if (profile.author.isVerified) ...[
            const SizedBox(width: 5),
            const VerifiedBadge(size: 18)
          ]
        ]),
        const SizedBox(height: 4),
        Text('@${profile.author.username}',
            style: const TextStyle(color: AppTheme.textSecondaryColor)),
        if (profile.country.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(profile.country,
                  style: const TextStyle(color: AppTheme.textMutedColor))),
        if (profile.birthDate.isNotEmpty)
          Text(profile.birthDate,
              style: const TextStyle(color: AppTheme.textMutedColor)),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          OutlinedButton.icon(
              onPressed: onFriend,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(onFriend == null ? 'أصدقاء' : 'إضافة صديق')),
          const SizedBox(width: 10),
          FilledButton.icon(
              onPressed: onMessage,
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: const Text('محادثة'))
        ])
      ]));
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
