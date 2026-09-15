import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../l10n/community_strings.dart';
import '../providers/community_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/app_scaffold_header.dart';
import '../widgets/ui/state_views.dart';
import '../widgets/ui/primary_button.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (_) => CommunityProvider(context.read<AppStateProvider>())..load(),
        child: const _CommunityBody(),
      );
}

class _CommunityBody extends StatefulWidget {
  const _CommunityBody();
  @override State<_CommunityBody> createState() => _CommunityBodyState();
}

class _CommunityBodyState extends State<_CommunityBody> {
  final search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final visible = provider.visiblePosts;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.communityStrings.community, style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                    SizedBox(height: 3),
                    Text(context.communityStrings.subtitle, style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12)),
                  ]),
                ),
                IconButton.filledTonal(
                  tooltip: context.communityStrings.createPost,
                  onPressed: () => _openCreate(context),
                  icon: const Icon(Icons.add_rounded),
                  style: IconButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                ),
              ]),
              const SizedBox(height: 14),
              TextField(
                controller: search,
                onChanged: (value) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 280), () {
                    if (mounted) context.read<CommunityProvider>().setSearchQuery(value);
                  });
                },
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: context.communityStrings.searchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: context.communityStrings.clearSearch,
                          onPressed: () { search.clear(); context.read<CommunityProvider>().setSearchQuery(''); setState(() {}); },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ]),
          ),
          Expanded(
            child: provider.loading && provider.posts.isEmpty
                ? const _CommunitySkeletonList()
                : provider.error != null && provider.posts.isEmpty
                    ? ErrorState(message: '${context.communityStrings.loadError} ${context.communityStrings.retryHint}', onRetry: provider.load)
                    : visible.isEmpty
                        ? _empty(context, provider.searchQuery.isNotEmpty)
                        : RefreshIndicator(
                            color: AppTheme.primaryColor,
                            onRefresh: () => provider.load(refresh: true),
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(14, 4, 14, 30),
                              itemCount: visible.length + 1,
                              itemBuilder: (_, i) {
                                if (i == visible.length) {
                                  if (provider.loadingMore) return const Padding(padding: EdgeInsets.all(18), child: Center(child: CircularProgressIndicator()));
                                  if (provider.hasMore && provider.searchQuery.isEmpty) { provider.load(); return const SizedBox(height: 20); }
                                  return const SizedBox(height: 8);
                                }
                                return _PostCard(key: ValueKey(visible[i]['id']), post: visible[i]);
                              },
                            ),
                          ),
          ),
        ]),
      ),
    );
  }

  Widget _empty(BuildContext context, bool searching) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(searching ? Icons.search_off_rounded : Icons.forum_outlined, color: AppTheme.primaryColor, size: 54),
            const SizedBox(height: 14),
            Text(searching ? context.communityStrings.noSearchResults : context.communityStrings.noPosts, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(searching ? context.communityStrings.searchEmptyHint : context.communityStrings.firstPost, style: const TextStyle(color: AppTheme.textSecondaryColor), textAlign: TextAlign.center),
          ]),
        ),
      );

  void _openCreate(BuildContext context) {
    if (!context.read<AppStateProvider>().isLoggedIn) { _message(context, context.communityStrings.signInPost); return; }
    showModalBottomSheet(isScrollControlled: true, backgroundColor: AppTheme.surfaceColor, context: context, builder: (_) => const _CreatePostSheet());
  }

  static void _message(BuildContext c, String text) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(text)));
}

class _CommunitySkeletonList extends StatelessWidget {
  const _CommunitySkeletonList();
  @override Widget build(BuildContext context) => ListView.builder(padding: const EdgeInsets.all(14), itemCount: 4, itemBuilder: (_, __) => Container(height: 190, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTheme.borderColor))));
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  const _PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CommunityProvider>();
    final mine = post['userId'] == provider.account.userId;
    final name = (post['displayName']?.toString().trim().isNotEmpty == true ? post['displayName'] : post['username'])?.toString() ?? 'AniTV user';
    final text = (post['text'] ?? '').toString().trim();
    final created = _time(post['createdAt']?.toString());
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openDetails(context),
        child: Padding(padding: const EdgeInsets.fromLTRB(14, 13, 14, 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _Avatar(name: name),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))), const SizedBox(width: 4), const Icon(Icons.verified_rounded, size: 15, color: AppTheme.primaryColor)]),
              Text('@${post['username'] ?? 'user'} · $created', style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11)),
            ])),
            PopupMenuButton<String>(onSelected: (value) => _menu(context, value, mine), itemBuilder: (_) => [
              PopupMenuItem(value: 'copy', child: Text(context.communityStrings.copyText)),
              if (mine) PopupMenuItem(value: 'delete', child: Text(context.communityStrings.deletePost)),
              if (!mine) PopupMenuItem(value: 'report', child: Text(context.communityStrings.reportPost)),
            ]),
          ]),
          if (text.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(text, maxLines: 8, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, height: 1.45, fontSize: 14))),
          if ((post['imageUrl'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: GestureDetector(onTap: () => _openImage(context, post['imageUrl'].toString()), child: ClipRRect(borderRadius: BorderRadius.circular(13), child: Image.network(post['imageUrl'].toString(), width: double.infinity, height: 210, fit: BoxFit.cover, loadingBuilder: (_, child, progress) => progress == null ? child : const SizedBox(height: 210, child: Center(child: CircularProgressIndicator())), errorBuilder: (_, __, ___) => const SizedBox(height: 110, child: Center(child: Icon(Icons.broken_image_outlined, color: AppTheme.textMutedColor, size: 38))))))),
          const SizedBox(height: 6),
          Row(children: [
            _ActionButton(icon: post['likedByMe'] == true ? Icons.favorite_rounded : Icons.favorite_border_rounded, label: '${post['likeCount'] ?? 0}', active: post['likedByMe'] == true, onPressed: () => _like(context)),
            _ActionButton(icon: Icons.mode_comment_outlined, label: '${post['commentCount'] ?? 0}', onPressed: () => _openDetails(context)),
            const Spacer(),
            IconButton(tooltip: context.communityStrings.copyText, onPressed: text.isEmpty ? null : () { Clipboard.setData(ClipboardData(text: text)); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.communityStrings.copied))); }, icon: const Icon(Icons.ios_share_rounded, size: 19)),
          ]),
        ])),
      ),
    );
  }

  Future<void> _like(BuildContext context) async { try { await context.read<CommunityProvider>().toggleLike(post); } catch (_) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.communityStrings.likeFailed))); } }
  void _openDetails(BuildContext context) => showModalBottomSheet(isScrollControlled: true, backgroundColor: AppTheme.surfaceColor, context: context, builder: (_) => _CommentsSheet(postId: post['id'].toString(), post: post));
  void _openImage(BuildContext context, String url) => showDialog(context: context, barrierColor: Colors.black87, builder: (_) => GestureDetector(onTap: () => Navigator.pop(context), child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain))));
  void _menu(BuildContext context, String value, bool mine) { if (value == 'copy') { Clipboard.setData(ClipboardData(text: post['text']?.toString() ?? '')); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.communityStrings.copied))); } else if (value == 'delete' && mine) _delete(context); else if (value == 'report') _report(context); }
  Future<void> _delete(BuildContext context) async { final yes = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: Text(context.communityStrings.deleteQuestion), content: Text(context.communityStrings.cannotUndo), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.communityStrings.cancel)), TextButton(onPressed: () => Navigator.pop(context, true), child: Text(context.communityStrings.delete, style: TextStyle(color: Colors.red)))])) ?? false; if (yes) { try { await context.read<CommunityProvider>().deletePost(post['id'].toString()); } catch (_) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.communityStrings.deleteFailed))); } } }
  void _report(BuildContext context) => showModalBottomSheet(backgroundColor: AppTheme.surfaceColor, isScrollControlled: true, context: context, builder: (_) => _ReportSheet(postId: post['id'].toString()));

  static String _time(String? value) { if (value == null || value.isEmpty) return 'now'; final date = DateTime.tryParse(value)?.toLocal(); if (date == null) return 'now'; final diff = DateTime.now().difference(date); if (diff.inMinutes < 1) return 'now'; if (diff.inHours < 1) return '${diff.inMinutes}m'; if (diff.inDays < 1) return '${diff.inHours}h'; return '${diff.inDays}d'; }
}

class _Avatar extends StatelessWidget { final String name; const _Avatar({required this.name}); @override Widget build(BuildContext context) => CircleAvatar(radius: 21, backgroundColor: AppTheme.primaryColor.withOpacity(.16), child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(), style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w800))); }
class _ActionButton extends StatelessWidget { final IconData icon; final String label; final bool active; final VoidCallback onPressed; const _ActionButton({required this.icon, required this.label, required this.onPressed, this.active = false}); @override Widget build(BuildContext context) => TextButton.icon(onPressed: onPressed, icon: Icon(icon, size: 19, color: active ? AppTheme.primaryColor : AppTheme.textSecondaryColor), label: Text(label, style: TextStyle(color: active ? AppTheme.primaryColor : AppTheme.textSecondaryColor, fontSize: 12))); }

class _CreatePostSheet extends StatefulWidget {
  const _CreatePostSheet();
  @override State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final text = TextEditingController();
  String? path;
  bool sending = false;

  @override
  void dispose() { text.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final account = context.read<AppStateProvider>();
    return Padding(
      padding: EdgeInsets.only(left: 18, right: 18, top: 8, bottom: MediaQuery.of(context).viewInsets.bottom + 18),
      child: Wrap(children: [
        Row(children: [
          Expanded(child: Text(context.communityStrings.createPost, style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold))),
          IconButton(onPressed: sending ? null : () => Navigator.pop(context), icon: const Icon(Icons.close)),
        ]),
        Row(children: [
          _Avatar(name: account.displayName.isEmpty ? account.username : account.displayName),
          const SizedBox(width: 10),
          Text('@${account.username}', style: const TextStyle(color: AppTheme.textSecondaryColor)),
        ]),
        const SizedBox(height: 14),
        TextField(controller: text, maxLines: 5, maxLength: 1000, autofocus: true, decoration: InputDecoration(hintText: context.communityStrings.writeSomething, alignLabelWithHint: true)),
        if (path != null) Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Stack(children: [
            ClipRRect(borderRadius: BorderRadius.circular(13), child: Image.file(File(path!), height: 170, width: double.infinity, fit: BoxFit.cover)),
            Positioned(top: 4, right: 4, child: IconButton(onPressed: () => setState(() => path = null), icon: const Icon(Icons.cancel, color: Colors.white, size: 28))),
          ]),
        ),
        const SizedBox(height: 8),
        Row(children: [
          OutlinedButton.icon(onPressed: sending ? null : _pick, icon: const Icon(Icons.add_photo_alternate_outlined), label: Text(context.communityStrings.addImage)),
          const Spacer(),
          SizedBox(width: 120, child: PrimaryButton(label: sending ? context.communityStrings.publishing : context.communityStrings.publish, onPressed: sending ? () {} : _submit)),
        ]),
      ]),
    );
  }

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
    final selected = result?.files.single.path;
    if (selected != null && mounted) setState(() => path = selected);
  }

  Future<void> _submit() async {
    if (text.text.trim().isEmpty && path == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.communityStrings.writeOrImage)));
      return;
    }
    setState(() => sending = true);
    try {
      await context.read<CommunityProvider>().createPost(text: text.text, imagePath: path);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.communityStrings.postPublished)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => sending = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.communityStrings.publishFailed)));
      }
    }
  }
}

class _CommentsSheet extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> post;
  const _CommentsSheet({required this.postId, required this.post});
  @override State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final input = TextEditingController();
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  bool sending = false;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { input.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      items = await context.read<CommunityProvider>().comments(widget.postId);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.communityStrings.commentsLoadFailed)));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .78,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(children: [
              Expanded(child: Text(context.communityStrings.postAndComments, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
              Text('${items.length}', style: const TextStyle(color: AppTheme.textSecondaryColor)),
            ]),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      _PostPreview(post: widget.post),
                      if (items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(context.communityStrings.noComments, textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondaryColor)),
                        )
                      else
                        ...items.map((x) => _commentTile(context, x)),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: input,
                  minLines: 1,
                  maxLines: 3,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(hintText: context.communityStrings.writeComment),
                ),
              ),
              IconButton(
                onPressed: sending || input.text.trim().isEmpty ? null : _add,
                icon: sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _commentTile(BuildContext context, Map<String, dynamic> x) {
    final account = context.read<CommunityProvider>().account;
    final name = x['displayName']?.toString().isNotEmpty == true ? x['displayName'].toString() : x['username']?.toString() ?? 'U';
    final mine = x['userId']?.toString() == account.userId;
    return ListTile(
      leading: _Avatar(name: name),
      title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(x['text']?.toString() ?? '', style: const TextStyle(color: AppTheme.textSecondaryColor)),
      trailing: mine ? PopupMenuButton<String>(onSelected: (_) => _deleteComment(x['id'].toString()), itemBuilder: (_) => [PopupMenuItem(value: 'delete', child: Text(context.communityStrings.deleteComment))]) : null,
    );
  }

  Future<void> _add() async {
    setState(() => sending = true);
    try {
      await context.read<CommunityProvider>().addComment(widget.postId, input.text);
      input.clear();
      await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.communityStrings.commentFailed)));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _deleteComment(String id) async {
    try {
      await context.read<CommunityProvider>().deleteComment(id);
      items.removeWhere((item) => item['id'].toString() == id);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.communityStrings.commentDeleteFailed)));
    }
  }
}

class _PostPreview extends StatelessWidget {
  final Map<String, dynamic> post;
  const _PostPreview({required this.post});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        child: Text(post['text']?.toString() ?? '', style: const TextStyle(color: Colors.white, height: 1.4)),
      );
}

class _ReportSheet extends StatefulWidget {
  final String postId;
  const _ReportSheet({required this.postId});
  @override State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String reason = 'Spam';
  final details = TextEditingController();
  bool sending = false;

  @override
  void dispose() { details.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final strings = context.communityStrings;
    final reasons = ['Spam', 'Harassment', 'Inappropriate content', 'Fake / misleading', 'Other'];
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 12, 18, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.communityStrings.reportPost, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...reasons.map((value) => RadioListTile<String>(dense: true, value: value, groupValue: reason, onChanged: sending ? null : (selected) { if (selected != null) setState(() => reason = selected); }, title: Text(communityReasonLabel(strings, value), style: const TextStyle(color: Colors.white)))),
        if (reason == 'Other') TextField(controller: details, maxLines: 3, decoration: InputDecoration(hintText: context.communityStrings.tellMore)),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: sending ? null : _send, child: Text(sending ? context.communityStrings.sending : context.communityStrings.submitReport))),
      ]),
    );
  }

  Future<void> _send() async {
    setState(() => sending = true);
    try {
      await context.read<CommunityProvider>().report(widget.postId, reason, details.text);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.communityStrings.reportSubmitted)));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.communityStrings.reportFailed)));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }
}
