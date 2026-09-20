import 'package:flutter/material.dart';
import '../sources/source_registry.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/app_fixed_header.dart';
import '../widgets/ui/content_card.dart';
import '../widgets/ui/content_grid.dart';
import '../widgets/ui/state_views.dart';
import 'video_player_screen.dart';

class FaselExploreScreen extends StatefulWidget {
  final bool embedded;
  const FaselExploreScreen({super.key, this.embedded = false});
  @override State<FaselExploreScreen> createState() => _FaselExploreScreenState();
}
class _FaselExploreScreenState extends State<FaselExploreScreen> {
  final _scroll = ScrollController(); final _search = TextEditingController(); final _items = <Map<String, dynamic>>[];
  int _page = 1; bool _loading = true, _loadingMore = false, _more = true; String _query = '';
  @override void initState() { super.initState(); _scroll.addListener(_onScroll); _load(reset: true); }
  @override void dispose() { _scroll.dispose(); _search.dispose(); super.dispose(); }
  void _onScroll() { if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 500 && !_loading && !_loadingMore && _more) _load(); }
  Future<void> _load({bool reset = false}) async {
    if (_loadingMore || (!reset && !_more)) return;
    if (reset) { _page = 1; setState(() { _loading = true; _loadingMore = false; _more = true; }); } else { setState(() => _loadingMore = true); }
    try {
      final rows = _query.isEmpty ? await SourceRegistry.latestMovies(page: _page) : await SourceRegistry.searchMovies(_query);
      if (!mounted) return;
      setState(() { if (reset) _items.clear(); final keys = _items.map((x) => x['url']).toSet(); _items.addAll(rows.whereType<Map>().map((x) => Map<String, dynamic>.from(x)).where((x) => keys.add(x['url']))); _page++; _loading = false; _loadingMore = false; _more = _query.isEmpty && rows.isNotEmpty; });
    } catch (_) { if (mounted) setState(() { _loading = false; _loadingMore = false; _more = false; }); }
  }
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: AppTheme.backgroundColor, body: SafeArea(child: Column(children: [
    if (!widget.embedded) const AppFixedHeader(title: 'الأفلام والمسلسلات', showBack: true),
    Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: TextField(controller: _search, onSubmitted: (v) { _query = v.trim(); _load(reset: true); }, textInputAction: TextInputAction.search, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'ابحث عن فيلم أو مسلسل...', prefixIcon: const Icon(Icons.search_rounded), suffixIcon: IconButton(onPressed: () { _search.clear(); _query = ''; _load(reset: true); }, icon: const Icon(Icons.clear_rounded)), filled: true, fillColor: AppTheme.elevatedColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)))),
    Expanded(child: _loading && _items.isEmpty ? const LoadingView(message: 'جارٍ تحميل الأفلام والمسلسلات...', size: 58) : _items.isEmpty ? EmptyState(icon: Icons.movie_outlined, title: 'لا توجد نتائج', message: 'جرّب كلمة بحث أخرى.', actionLabel: 'إعادة المحاولة', onAction: () => _load(reset: true)) : ContentGrid(controller: _scroll, itemCount: _items.length + (_more ? 1 : 0), padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), itemBuilder: (_, i) { if (i >= _items.length) return const Center(child: CircularProgressIndicator()); final item = _items[i]; return ContentCard(title: item['title']?.toString() ?? 'بدون عنوان', imageUrl: item['image_url']?.toString() ?? '', badge: item['type']?.toString() ?? 'فيلم', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FaselDetailsScreen(url: item['url'].toString())))); }))
  ])));
}

class FaselDetailsScreen extends StatefulWidget {
  final String url;
  const FaselDetailsScreen({super.key, required this.url});
  @override State<FaselDetailsScreen> createState() => _FaselDetailsScreenState();
}
class _FaselDetailsScreenState extends State<FaselDetailsScreen> {
  late Future<Map<String, dynamic>> _future;
  @override void initState() { super.initState(); _future = _loadDetails(); }
  Future<Map<String, dynamic>> _loadDetails() async => (await SourceRegistry.details(widget.url)) ?? (throw Exception('تعذر تحميل تفاصيل FaselHD'));
  Future<void> _play(String url, String title) async {
    try {
      final data = await SourceRegistry.streams(url); if (!mounted) return;
      if (data == null) throw Exception('لا توجد مصادر تشغيل');
      final servers = (data['direct_stream_urls'] as List? ?? const []).whereType<Map>().map((x) => {'url': x['url']?.toString() ?? '', 'label': x['label']?.toString() ?? x['name']?.toString() ?? 'سيرفر', 'referer': x['referer']?.toString() ?? ''}).where((x) => x['url']!.isNotEmpty).toList();
      if (servers.isEmpty) throw Exception('لا توجد سيرفرات');
      if (servers.length == 1) { _openPlayer(servers.first, title); return; }
      if (!mounted) return;
      showModalBottomSheet(context: context, backgroundColor: AppTheme.surfaceColor, builder: (_) => SafeArea(child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [const Text('اختر مصدر التشغيل', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)), const SizedBox(height: 12), ...servers.asMap().entries.map((entry) => Card(child: ListTile(leading: CircleAvatar(backgroundColor: AppTheme.primaryColor.withOpacity(.18), child: Text('${entry.key + 1}', style: const TextStyle(color: AppTheme.primaryColor))), title: Text(entry.value['label']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)), onTap: () { Navigator.pop(context); _openPlayer(entry.value, title); })))])));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحميل السيرفرات: $e'))); }
  }
  void _openPlayer(Map<String, String> server, String title) => Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerScreen(url: server['url']!, title: title, episodeId: widget.url, directStreamUrls: [server], headers: server['referer']!.isEmpty ? const {} : {'Referer': server['referer']!})));
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: AppTheme.backgroundColor, appBar: AppBar(title: const Text('تفاصيل المحتوى')), body: FutureBuilder<Map<String, dynamic>>(future: _future, builder: (context, snapshot) { if (!snapshot.hasData) return snapshot.hasError ? ErrorState(onRetry: () => setState(() => _future = _loadDetails())) : const LoadingView(message: 'جارٍ تحميل التفاصيل...', size: 58); final data = snapshot.data!; final title = data['title']?.toString() ?? 'بدون عنوان'; final episodes = (data['episodes'] as List? ?? const []).whereType<Map>().toList(); final image = data['image_url']?.toString() ?? ''; return ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 30), children: [Row(crossAxisAlignment: CrossAxisAlignment.start, children: [ClipRRect(borderRadius: BorderRadius.circular(16), child: image.isEmpty ? Container(width: 112, height: 160, color: AppTheme.elevatedColor, child: const Icon(Icons.movie_outlined, size: 42)) : Image.network(image, width: 112, height: 160, fit: BoxFit.cover)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)), const SizedBox(height: 10), Text(data['type']?.toString() ?? 'فيلم', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700))]))]), if ((data['description']?.toString() ?? '').isNotEmpty) ...[const SizedBox(height: 18), Text(data['description'].toString(), textDirection: TextDirection.rtl, style: const TextStyle(color: AppTheme.textSecondaryColor, height: 1.7))], const SizedBox(height: 22), if (episodes.isEmpty) ElevatedButton.icon(onPressed: () => _play(widget.url, title), icon: const Icon(Icons.play_arrow_rounded), label: const Text('تشغيل')) else ...[const Text('الحلقات', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)), const SizedBox(height: 10), ...episodes.map((ep) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(title: Text(ep['title']?.toString() ?? 'حلقة', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)), trailing: const Icon(Icons.play_circle_outline_rounded), onTap: () => _play(ep['url']?.toString() ?? widget.url, '${title} - ${ep['title'] ?? 'حلقة'}'))))]]); }));
}
