import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../community/mock/mock_community_repository.dart';
import '../community/models/community_models.dart';
import '../community/state/community_feed_provider.dart';
import '../community/widgets/community_widgets.dart';
import '../providers/app_state_provider.dart';
import '../theme/app_theme.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
      create: (_) =>
          CommunityFeedProvider(repository: MockCommunityRepository())..load(),
      child: _CommunityBody(embedded: embedded));
}

class _CommunityBody extends StatefulWidget {
  const _CommunityBody({required this.embedded});
  final bool embedded;
  @override
  State<_CommunityBody> createState() => _CommunityBodyState();
}

class _CommunityBodyState extends State<_CommunityBody> {
  final scroll = ScrollController();
  final search = TextEditingController();
  Timer? debounce;
  bool searching = false;
  @override
  void initState() {
    super.initState();
    scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    scroll.dispose();
    search.dispose();
    debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (scroll.hasClients &&
        scroll.position.pixels > scroll.position.maxScrollExtent - 480)
      context.read<CommunityFeedProvider>().load();
  }

  PostAuthor _currentAuthor(AppStateProvider state) => PostAuthor(
      id: state.userId ?? 'guest',
      username: state.username.trim().isEmpty ? 'guest' : state.username.trim(),
      displayName: state.displayName.trim().isEmpty
          ? 'حساب AniTV'
          : state.displayName.trim(),
      isVerified: false);
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityFeedProvider>();
    final account = context.watch<AppStateProvider>();
    return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: RefreshIndicator(
            onRefresh: () => provider.load(refresh: true),
            color: AppTheme.primaryColor,
            backgroundColor: AppTheme.surfaceColor,
            child: CustomScrollView(controller: scroll, slivers: [
              SliverToBoxAdapter(child: _topBar(context, account)),
              SliverToBoxAdapter(child: _profileStrip(context, account)),
              if (provider.loading && provider.posts.isEmpty)
                const SliverToBoxAdapter(
                    child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Center(child: CircularProgressIndicator()))),
              if (provider.error != null && provider.posts.isEmpty)
                SliverFillRemaining(
                    hasScrollBody: false,
                    child: CommunityEmptyState(
                        title: 'تعذر تحميل المجتمع',
                        subtitle: 'تحقق من الاتصال وحاول مرة أخرى.',
                        onRetry: () => provider.load(refresh: true))),
              if (!provider.loading &&
                  provider.error == null &&
                  provider.posts.isEmpty)
                SliverFillRemaining(
                    hasScrollBody: false,
                    child: CommunityEmptyState(
                        title: provider.query.isEmpty
                            ? 'لا توجد منشورات حتى الآن'
                            : 'لا توجد نتائج',
                        subtitle: provider.query.isEmpty
                            ? 'كن أول من يشارك شيئًا مع محبي AniTV.'
                            : 'جرّب كلمة أخرى أو امسح البحث.')),
              SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                if (index >= provider.posts.length)
                  return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()));
                final post = provider.posts[index];
                return CommunityPostItem(
                    post: post,
                    onLike: () async {
                      try {
                        await provider.toggleLike(post);
                      } catch (error) {
                        if (context.mounted) _snack(context, error.toString());
                      }
                    },
                    onComment: () => _showComments(context, post),
                    onProfile: () => _snack(
                        context, 'ملفات المستخدمين ستتوفر في المرحلة الثانية.'),
                    onShare: () => Share.share(post.text.isEmpty
                        ? 'منشور من مجتمع AniTV'
                        : post.text));
              },
                      childCount: provider.posts.length +
                          (provider.loadingMore ? 1 : 0))),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ])));
  }

  Widget _topBar(BuildContext context, AppStateProvider account) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          if (searching)
            Expanded(
              child: TextField(
                controller: search,
                autofocus: true,
                onChanged: (value) {
                  debounce?.cancel();
                  debounce = Timer(
                      const Duration(milliseconds: 280),
                      () =>
                          context.read<CommunityFeedProvider>().search(value));
                },
                decoration: InputDecoration(
                  hintText: 'ابحث في المجتمع...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    onPressed: () {
                      search.clear();
                      context.read<CommunityFeedProvider>().search('');
                      setState(() => searching = false);
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('المجتمع',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text('شارك ما تحبه مع محبي AniTV',
                      style: TextStyle(color: AppTheme.textSecondaryColor)),
                ],
              ),
            ),
          if (!searching)
            IconButton(
                onPressed: () => setState(() => searching = true),
                icon: const Icon(Icons.search_rounded),
                tooltip: 'بحث'),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                  onPressed: () => _snack(context, 'لا توجد رسائل جديدة.'),
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  tooltip: 'الرسائل'),
              Positioned(
                  top: 5,
                  right: 3,
                  child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profileStrip(BuildContext context, AppStateProvider account) {
    final current = _currentAuthor(account);
    final friends = ['س', 'م', 'أ', 'ن'];
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: [
          Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CommunityAvatar(
                      author: current,
                      radius: 25,
                      avatarFuture: account.profileImageBytes,
                      onTap: () => _snack(context,
                          'ملفك الاجتماعي سيتوفر في المرحلة الثانية.')),
                  Positioned(
                    bottom: -1,
                    right: -2,
                    child: Material(
                      color: AppTheme.primaryColor,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () => _showComposer(context),
                        customBorder: const CircleBorder(),
                        child: Container(
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppTheme.backgroundColor, width: 2)),
                          child: const Icon(Icons.add_rounded,
                              color: Colors.white, size: 17),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text('أنت',
                  style: TextStyle(
                      color: AppTheme.textSecondaryColor, fontSize: 11)),
            ],
          ),
          const SizedBox(width: 18),
          ...friends.map((letter) => Padding(
                padding: const EdgeInsetsDirectional.only(end: 16),
                child: Column(
                  children: [
                    CircleAvatar(
                        radius: 25,
                        backgroundColor: AppTheme.surfaceColor,
                        child: Text(letter,
                            style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w800))),
                    const SizedBox(height: 4),
                    const Text('عضو',
                        style: TextStyle(
                            color: AppTheme.textSecondaryColor, fontSize: 11)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Future<void> _showComposer(BuildContext context) async {
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: AppTheme.surfaceColor,
        builder: (_) => const _ComposerSheet());
  }

  Future<void> _showComments(BuildContext context, CommunityPost post) async {
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: AppTheme.surfaceColor,
        builder: (_) => _CommentsSheet(post: post));
  }

  void _snack(BuildContext context, String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
}

class _ComposerSheet extends StatefulWidget {
  const _ComposerSheet();
  @override
  State<_ComposerSheet> createState() => _ComposerSheetState();
}

class _ComposerSheetState extends State<_ComposerSheet> {
  final text = TextEditingController();
  String? imagePath;
  String? link;
  String? audioPath;
  Duration audioDuration = const Duration(seconds: 24);
  bool publishing = false;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result?.files.single.path != null)
      setState(() => imagePath = result!.files.single.path);
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result?.files.single.path != null)
      setState(() => audioPath = result!.files.single.path);
  }

  Future<void> _addLink() async {
    final controller = TextEditingController(text: link);
    final value = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('إضافة رابط'),
                content: TextField(
                    controller: controller,
                    keyboardType: TextInputType.url,
                    textDirection: TextDirection.ltr,
                    decoration:
                        const InputDecoration(hintText: 'https://example.com')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, controller.text),
                      child: const Text('إضافة'))
                ]));
    controller.dispose();
    if (value?.trim().isNotEmpty == true) setState(() => link = value!.trim());
  }

  Future<void> _publish() async {
    final draft = CreatePostDraft(
        text: text.text,
        imagePath: imagePath,
        link: link,
        audioPath: audioPath,
        audioDuration: audioDuration);
    if (!draft.hasContent) {
      _message('أضف نصًا أو صورة أو رابطًا أو صوتًا.');
      return;
    }
    setState(() => publishing = true);
    try {
      await context.read<CommunityFeedProvider>().publish(draft);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم نشر المنشور بنجاح.')));
      }
    } catch (error) {
      _message(error.toString());
    } finally {
      if (mounted) setState(() => publishing = false);
    }
  }

  void _message(String value) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(value)));
  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.only(
          left: 18,
          right: 18,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16),
      child: SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('إنشاء منشور',
            style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        TextField(
            controller: text,
            minLines: 4,
            maxLines: 7,
            autofocus: true,
            decoration: const InputDecoration(
                hintText: 'ما الذي تريد مشاركته؟', alignLabelWithHint: true)),
        if (imagePath != null)
          _AttachmentTile(
              icon: Icons.image_rounded,
              label: File(imagePath!).uri.pathSegments.last,
              onRemove: () => setState(() => imagePath = null)),
        if (link != null)
          _AttachmentTile(
              icon: Icons.link_rounded,
              label: link!,
              onRemove: () => setState(() => link = null)),
        if (audioPath != null)
          _AttachmentTile(
              icon: Icons.mic_rounded,
              label: 'مقطع صوتي • 00:24',
              onRemove: () => setState(() => audioPath = null)),
        const SizedBox(height: 12),
        Row(children: [
          OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image_outlined),
              label: const Text('صورة')),
          const SizedBox(width: 8),
          OutlinedButton.icon(
              onPressed: _addLink,
              icon: const Icon(Icons.link_rounded),
              label: const Text('رابط')),
          const SizedBox(width: 8),
          OutlinedButton.icon(
              onPressed: _pickAudio,
              icon: const Icon(Icons.mic_none_rounded),
              label: const Text('صوت'))
        ]),
        const SizedBox(height: 14),
        FilledButton.icon(
            onPressed: publishing ? null : _publish,
            icon: publishing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded),
            label: Text(publishing ? 'جارٍ النشر...' : 'نشر'),
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)))
      ])));
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile(
      {required this.icon, required this.label, required this.onRemove});
  final IconData icon;
  final String label;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white)),
      trailing: IconButton(
          onPressed: onRemove,
          icon: const Icon(Icons.close_rounded),
          tooltip: 'إزالة'));
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.post});
  final CommunityPost post;
  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final controller = TextEditingController();
  List<CommunityComment> comments = [];
  bool loading = true;
  bool sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    comments =
        await context.read<CommunityFeedProvider>().comments(widget.post.id);
    if (mounted) setState(() => loading = false);
  }

  Future<void> _send() async {
    if (controller.text.trim().isEmpty) return;
    setState(() => sending = true);
    try {
      final item = await context
          .read<CommunityFeedProvider>()
          .addComment(widget.post.id, controller.text);
      if (mounted) {
        setState(() {
          comments.add(item);
          controller.clear();
        });
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .72,
      child: Padding(
        padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('التعليقات',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : comments.isEmpty
                      ? const Center(
                          child: Text('لا توجد تعليقات بعد.',
                              style: TextStyle(
                                  color: AppTheme.textSecondaryColor)))
                      : ListView.builder(
                          itemCount: comments.length,
                          itemBuilder: (_, index) {
                            final comment = comments[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CommunityAvatar(
                                  author: comment.author, radius: 18),
                              title: Text(comment.author.displayName,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700)),
                              subtitle: Text(comment.text,
                                  style: const TextStyle(
                                      color: AppTheme.textSecondaryColor,
                                      height: 1.4)),
                            );
                          },
                        ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                    child: TextField(
                        controller: controller,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                            hintText: 'اكتب تعليقًا...'))),
                const SizedBox(width: 8),
                IconButton.filled(
                    onPressed: sending ? null : _send,
                    icon: const Icon(Icons.send_rounded)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
