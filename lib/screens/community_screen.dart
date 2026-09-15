import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../providers/community_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/app_scaffold_header.dart';
import '../widgets/ui/state_views.dart';
import '../widgets/ui/primary_button.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});
  @override Widget build(BuildContext context) => ChangeNotifierProvider(create: (_) => CommunityProvider(context.read<AppStateProvider>())..load(), child: const _CommunityBody());
}

class _CommunityBody extends StatelessWidget {
  const _CommunityBody();
  @override Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    return Scaffold(backgroundColor: AppTheme.backgroundColor, body: SafeArea(child: Column(children: [
      AppScaffoldHeader(title: 'Community', actions: [IconButton(tooltip: 'إنشاء منشور', onPressed: () => _openCreate(context), icon: const Icon(Icons.add_circle_outline_rounded))]),
      Expanded(child: provider.loading && provider.posts.isEmpty ? const LoadingView(message: 'جارٍ تحميل المجتمع...', size: 58) : provider.error != null && provider.posts.isEmpty ? ErrorState(message: provider.error!, onRetry: provider.load) : provider.posts.isEmpty ? const EmptyState(icon: Icons.forum_outlined, title: 'لا توجد منشورات بعد', message: 'كن أول من يشارك شيئًا مع مجتمع AniTV.') : RefreshIndicator(color: AppTheme.primaryColor, onRefresh: () => provider.load(refresh: true), child: ListView.builder(padding: const EdgeInsets.fromLTRB(14, 0, 14, 24), itemCount: provider.posts.length + 1, itemBuilder: (_, i) { if (i == provider.posts.length) { if (provider.loadingMore) return const Padding(padding: EdgeInsets.all(18), child: Center(child: CircularProgressIndicator())); if (provider.hasMore) { provider.load(); return const SizedBox(height: 20); } return const SizedBox(height: 8); } return _PostCard(post: provider.posts[i]); }))),
    ])));
  }
  void _openCreate(BuildContext context) { if (!context.read<AppStateProvider>().isLoggedIn) { _message(context, 'سجّل الدخول لإنشاء منشور.'); return; } showModalBottomSheet(isScrollControlled: true, backgroundColor: AppTheme.surfaceColor, context: context, builder: (_) => const _CreatePostSheet()); }
  static void _message(BuildContext c, String text) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(text)));
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  const _PostCard({required this.post});
  @override Widget build(BuildContext context) {
    final provider = context.read<CommunityProvider>(); final mine = post['userId'] == provider.account.userId; final title = (post['displayName']?.toString().trim().isNotEmpty == true ? post['displayName'] : post['username'])?.toString() ?? 'مستخدم';
    return Card(color: AppTheme.cardColor, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppTheme.borderColor)), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [CircleAvatar(radius: 20, backgroundColor: AppTheme.primaryColor.withOpacity(.16), child: Text(title.isEmpty ? '?' : title.characters.first.toUpperCase(), style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold))), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)), if ((post['username'] ?? '').toString().isNotEmpty) Text('@${post['username']}', style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12))])), PopupMenuButton<String>(onSelected: (v) => v == 'delete' ? _delete(context) : _report(context), itemBuilder: (_) => [if (mine) const PopupMenuItem(value: 'delete', child: Text('حذف المنشور')), if (!mine) const PopupMenuItem(value: 'report', child: Text('إبلاغ'))])]),
      if ((post['text'] ?? '').toString().trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(post['text'].toString(), style: const TextStyle(color: Colors.white, height: 1.45))),
      if ((post['imageUrl'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(post['imageUrl'].toString(), width: double.infinity, height: 220, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(height: 100, child: Icon(Icons.broken_image_outlined))))),
      const SizedBox(height: 8), Row(children: [IconButton(onPressed: () => _like(context), icon: Icon(post['likedByMe'] == true ? Icons.favorite : Icons.favorite_border, color: post['likedByMe'] == true ? AppTheme.primaryColor : AppTheme.textSecondaryColor)), Text('${post['likeCount'] ?? 0}', style: const TextStyle(color: AppTheme.textSecondaryColor)), const SizedBox(width: 12), TextButton.icon(onPressed: () => _comments(context), icon: const Icon(Icons.mode_comment_outlined, size: 19), label: Text('${post['commentCount'] ?? 0}'))])
    ])));
  }
  Future<void> _like(BuildContext c) async { try { await c.read<CommunityProvider>().toggleLike(post); } catch (_) { ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('تعذر تحديث الإعجاب.'))); } }
  Future<void> _delete(BuildContext c) async { final yes = await showDialog<bool>(context: c, builder: (_) => AlertDialog(title: const Text('حذف المنشور؟'), content: const Text('لا يمكن التراجع عن هذا الإجراء.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف', style: TextStyle(color: Colors.red)))])) ?? false; if (yes) { try { await c.read<CommunityProvider>().deletePost(post['id'].toString()); } catch (_) { ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('تعذر حذف المنشور.'))); } } }
  void _report(BuildContext c) { showDialog(context: c, builder: (_) { String reason = 'Spam'; final details = TextEditingController(); return AlertDialog(title: const Text('إبلاغ عن المنشور'), content: Column(mainAxisSize: MainAxisSize.min, children: [DropdownButtonFormField<String>(value: reason, items: ['Spam', 'Harassment', 'Inappropriate content', 'Misinformation', 'Other'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => reason = v ?? reason), TextField(controller: details, decoration: const InputDecoration(labelText: 'تفاصيل اختيارية'))]), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')), TextButton(onPressed: () async { try { await c.read<CommunityProvider>().report(post['id'].toString(), reason, details.text); if (c.mounted) Navigator.pop(c); } catch (_) { if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('تعذر إرسال البلاغ أو سبق إرساله.'))); } }, child: const Text('إرسال'))]); }); }
  void _comments(BuildContext c) { showModalBottomSheet(isScrollControlled: true, backgroundColor: AppTheme.surfaceColor, context: c, builder: (_) => _CommentsSheet(postId: post['id'].toString())); }
}

class _CreatePostSheet extends StatefulWidget { const _CreatePostSheet(); @override State<_CreatePostSheet> createState() => _CreatePostSheetState(); }
class _CreatePostSheetState extends State<_CreatePostSheet> {
  final text = TextEditingController(); String? path; bool sending = false;
  @override void dispose() { text.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Padding(padding: EdgeInsets.only(left: 18, right: 18, top: 18, bottom: MediaQuery.of(context).viewInsets.bottom + 18), child: Wrap(children: [Row(children: [const Expanded(child: Text('إنشاء منشور', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))), IconButton(onPressed: sending ? null : () => Navigator.pop(context), icon: const Icon(Icons.close))]), TextField(controller: text, maxLines: 5, maxLength: 1000, decoration: const InputDecoration(hintText: 'ماذا تريد أن تشارك؟')), if (path != null) Padding(padding: const EdgeInsets.only(top: 10), child: Stack(children: [ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(path!), height: 150, width: double.infinity, fit: BoxFit.cover)), Positioned(top: 4, right: 4, child: IconButton(onPressed: () => setState(() => path = null), icon: const Icon(Icons.cancel, color: Colors.white))])), Row(children: [TextButton.icon(onPressed: sending ? null : _pick, icon: const Icon(Icons.image_outlined), label: const Text('إضافة صورة')), const Spacer(), SizedBox(width: 120, child: PrimaryButton(label: sending ? 'جارٍ...' : 'نشر', onPressed: sending ? () {} : _submit))]) ]));
  Future<void> _pick() async { final result = await FilePicker.platform.pickFiles(type: FileType.image); final p = result?.files.single.path; if (p != null) setState(() => path = p); }
  Future<void> _submit() async { if (text.text.trim().isEmpty && path == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب نصًا أو أضف صورة أولًا.'))); return; } setState(() => sending = true); try { await context.read<CommunityProvider>().createPost(text: text.text, imagePath: path); if (mounted) Navigator.pop(context); } catch (e) { if (mounted) { setState(() => sending = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); } } }
}

class _CommentsSheet extends StatefulWidget { final String postId; const _CommentsSheet({required this.postId}); @override State<_CommentsSheet> createState() => _CommentsSheetState(); }
class _CommentsSheetState extends State<_CommentsSheet> { final input = TextEditingController(); List<Map<String, dynamic>> items = []; bool loading = true; @override void initState() { super.initState(); _load(); } @override void dispose() { input.dispose(); super.dispose(); } Future<void> _load() async { try { items = await context.read<CommunityProvider>().comments(widget.postId); } finally { if (mounted) setState(() => loading = false); } } @override Widget build(BuildContext context) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), child: SizedBox(height: MediaQuery.of(context).size.height * .72, child: Column(children: [const Padding(padding: EdgeInsets.all(16), child: Text('التعليقات', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))), Expanded(child: loading ? const LoadingView(size: 40) : items.isEmpty ? const EmptyState(icon: Icons.forum_outlined, title: 'لا توجد تعليقات') : ListView.builder(itemCount: items.length, itemBuilder: (_, i) { final x = items[i]; return ListTile(title: Text(x['displayName']?.toString().isNotEmpty == true ? x['displayName'].toString() : '@${x['username']}', style: const TextStyle(color: Colors.white)), subtitle: Text(x['text']?.toString() ?? '', style: const TextStyle(color: AppTheme.textSecondaryColor))); })), Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 12), child: Row(children: [Expanded(child: TextField(controller: input, decoration: const InputDecoration(hintText: 'اكتب تعليقًا...'))), IconButton(onPressed: () async { if (input.text.trim().isEmpty) return; await context.read<CommunityProvider>().addComment(widget.postId, input.text); input.clear(); await _load(); }, icon: const Icon(Icons.send_rounded))]))])));
}
