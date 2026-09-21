import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/news_model.dart';
import '../providers/app_state_provider.dart';
import '../providers/news_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/app_search_bar.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (_) => NewsProvider(context.read<AppStateProvider>())..load(),
        child: const _NewsBody(),
      );
}

class _NewsBody extends StatefulWidget {
  const _NewsBody();
  @override State<_NewsBody> createState() => _NewsBodyState();
}

class _NewsBodyState extends State<_NewsBody> {
  final search = TextEditingController();
  final scroll = ScrollController();
  Timer? debounce;
  @override void initState() { super.initState(); scroll.addListener(_onScroll); }
  @override void dispose() { debounce?.cancel(); search.dispose(); scroll.dispose(); super.dispose(); }
  void _onScroll() { if (scroll.position.pixels > scroll.position.maxScrollExtent - 500) context.read<NewsProvider>().load(); }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NewsProvider>();
    final news = provider.visibleItems;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: RefreshIndicator(
        onRefresh: () => provider.load(refresh: true),
        child: CustomScrollView(controller: scroll, slivers: [
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('أخبار AniTV', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('آخر أخبار الأنمي والمانجا والأفلام والترفيه', style: TextStyle(color: AppTheme.textSecondaryColor)),
            const SizedBox(height: 14),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ExpandableSearchBar(
                controller: search,
                hintText: 'ابحث داخل الأخبار فقط',
                onChanged: (value) {
                  debounce?.cancel();
                  debounce = Timer(const Duration(milliseconds: 250), () => context.read<NewsProvider>().setQuery(value));
                },
                onClear: () {
                  search.clear();
                  context.read<NewsProvider>().setQuery('');
                  setState(() {});
                },
              ),
            ),
            const SizedBox(height: 12),
          ]))),
          SliverToBoxAdapter(child: SizedBox(height: 43, child: ListView.separated(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: newsCategories.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (_, index) { final value = newsCategories[index]; final selected = provider.category == value; return ChoiceChip(label: Text(value), selected: selected, onSelected: (_) => provider.setCategory(value), selectedColor: AppTheme.primaryColor, labelStyle: TextStyle(color: selected ? Colors.white : AppTheme.textSecondaryColor, fontWeight: FontWeight.w700)); }))),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          if (provider.loading && news.isEmpty) const SliverToBoxAdapter(child: _NewsSkeleton()),
          if (provider.error != null && news.isEmpty) SliverFillRemaining(hasScrollBody: false, child: _StateMessage(text: provider.error!, icon: Icons.cloud_off_rounded, action: TextButton(onPressed: () => provider.load(refresh: true), child: const Text('إعادة المحاولة')))),
          if (!provider.loading && provider.error == null && news.isEmpty) const SliverFillRemaining(hasScrollBody: false, child: _StateMessage(text: 'لا توجد أخبار مطابقة.', icon: Icons.newspaper_outlined)),
          if (provider.offline && news.isNotEmpty) const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Text('لا يوجد اتصال بالإنترنت — عرض آخر الأخبار المخزنة', style: TextStyle(color: Colors.orangeAccent, fontSize: 12)))),
          SliverPadding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) { if (index >= news.length) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())); return _NewsCard(item: news[index]); }, childCount: news.length + (provider.loadingMore ? 1 : 0)))),
        ]),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item});
  final NewsItem item;
  @override Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 14), clipBehavior: Clip.antiAlias, child: InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NewsDetailScreen(item: item))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (item.imageUrl.isNotEmpty) SizedBox(height: 190, width: double.infinity, child: CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.cover, placeholder: (_, __) => const ColoredBox(color: Color(0xff25252b)), errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xff25252b), child: Icon(Icons.image_not_supported_outlined, color: Colors.white54, size: 42)))),
    Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(.18), borderRadius: BorderRadius.circular(20)), child: Text(item.category, style: TextStyle(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold))), const Spacer(), Text(item.source, style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11))]),
      const SizedBox(height: 8), Text(item.titleArabic, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 7), Text(item.summaryArabic, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppTheme.textSecondaryColor, height: 1.45)),
      const SizedBox(height: 12), Row(children: [Icon(Icons.favorite_rounded, size: 17, color: item.likedByMe ? Color(0xFF1976D2) : AppTheme.textSecondaryColor), const SizedBox(width: 4), Text('${item.likeCount}', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12)), const SizedBox(width: 16), Icon(Icons.comment_rounded, size: 17, color: AppTheme.textSecondaryColor), const SizedBox(width: 4), Text('${item.commentCount}', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12)), const Spacer(), Text(_date(item.publishedAt), style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11))]),
    ])),
  ])));
}

class NewsDetailScreen extends StatefulWidget { const NewsDetailScreen({super.key, required this.item}); final NewsItem item; @override State<NewsDetailScreen> createState() => _NewsDetailScreenState(); }
class _NewsDetailScreenState extends State<NewsDetailScreen> {
  final comment = TextEditingController();
  List<Map<String, dynamic>> comments = []; bool loading = true; bool sending = false;
  @override void initState() { super.initState(); _loadComments(); }
  @override void dispose() { comment.dispose(); super.dispose(); }
  Future<void> _loadComments() async { try { comments = await context.read<NewsProvider>().loadComments(widget.item.id); } catch (_) {} if (mounted) setState(() => loading = false); }
  Future<void> _send() async { if (comment.text.trim().isEmpty) return; setState(() => sending = true); try { await context.read<NewsProvider>().addComment(widget.item, comment.text); comment.clear(); await _loadComments(); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); } finally { if (mounted) setState(() => sending = false); } }
  @override Widget build(BuildContext context) { final item = widget.item; return Scaffold(backgroundColor: AppTheme.backgroundColor, appBar: AppBar(title: const Text('تفاصيل الخبر')), body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 28), children: [
    if (item.imageUrl.isNotEmpty) ClipRRect(borderRadius: BorderRadius.circular(18), child: CachedNetworkImage(imageUrl: item.imageUrl, height: 220, fit: BoxFit.cover)),
    const SizedBox(height: 16), Row(children: [Chip(label: Text(item.category)), const Spacer(), Text(item.source, style: TextStyle(color: AppTheme.textSecondaryColor))]),
    Text(item.titleArabic, style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900, height: 1.25)),
    if (item.titleOriginal.isNotEmpty && item.titleOriginal != item.titleArabic) Padding(padding: const EdgeInsets.only(top: 8), child: Text(item.titleOriginal, style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13))),
    const SizedBox(height: 14), Text(item.summaryArabic, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.65)),
    const SizedBox(height: 8), Text('${item.source} • ${_date(item.publishedAt)}', style: TextStyle(color: AppTheme.textSecondaryColor)),
    const SizedBox(height: 14), Row(children: [Consumer<NewsProvider>(builder: (_, provider, __) => OutlinedButton.icon(onPressed: () async { try { await provider.toggleLike(item); } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); } }, icon: Icon(item.likedByMe ? Icons.favorite : Icons.favorite_border, color: Color(0xFF1976D2)), label: Text('${item.likeCount} إعجاب'))), const SizedBox(width: 10), if (item.sourceUrl.isNotEmpty) Expanded(child: FilledButton.icon(onPressed: () => launchUrl(Uri.parse(item.sourceUrl), mode: LaunchMode.externalApplication), icon: const Icon(Icons.open_in_new_rounded), label: const Text('قراءة الخبر الأصلي')))]),
    const SizedBox(height: 24), const Text('التعليقات', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 10),
    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: TextField(controller: comment, maxLines: 3, minLines: 1, decoration: const InputDecoration(hintText: 'اكتب تعليقك'))), const SizedBox(width: 8), IconButton.filled(onPressed: sending ? null : _send, icon: const Icon(Icons.send_rounded))]),
    const SizedBox(height: 12), if (loading) const Center(child: CircularProgressIndicator()), ...comments.map((value) => _CommentTile(value: value)),
  ])); }
}

class _CommentTile extends StatelessWidget { const _CommentTile({required this.value}); final Map<String, dynamic> value; @override Widget build(BuildContext context) { final name = value['displayName']?.toString().trim().isNotEmpty == true ? value['displayName'].toString() : value['username']?.toString() ?? 'مستخدم'; return ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(child: Text(name.isEmpty ? '?' : name.substring(0, 1))), title: Row(children: [Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), if (value['verified'] == true) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.verified, size: 15, color: Colors.lightBlueAccent))]), subtitle: Text(value['text']?.toString() ?? '', style: TextStyle(color: AppTheme.textSecondaryColor, height: 1.4))); } }
class _StateMessage extends StatelessWidget { const _StateMessage({required this.text, required this.icon, this.action}); final String text; final IconData icon; final Widget? action; @override Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: AppTheme.textSecondaryColor, size: 44), const SizedBox(height: 10), Text(text, textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondaryColor)), if (action != null) action!])); }
class _NewsSkeleton extends StatelessWidget { const _NewsSkeleton(); @override Widget build(BuildContext context) => const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())); }
String _date(DateTime? value) { if (value == null) return 'حديثًا'; final difference = DateTime.now().difference(value); if (difference.inMinutes < 60) return 'منذ ${difference.inMinutes} دقيقة'; if (difference.inHours < 24) return 'منذ ${difference.inHours} ساعة'; if (difference.inDays < 7) return 'منذ ${difference.inDays} يوم'; return '${value.day}/${value.month}/${value.year}'; }
