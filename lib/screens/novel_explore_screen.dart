import 'package:flutter/material.dart';
import '../services/novel_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/app_fixed_header.dart';
import '../widgets/ui/content_card.dart';
import '../widgets/ui/content_grid.dart';
import '../widgets/ui/state_views.dart';

class NovelExploreScreen extends StatefulWidget {
  final bool embedded;
  const NovelExploreScreen({super.key, this.embedded = false});
  @override State<NovelExploreScreen> createState() => _NovelExploreScreenState();
}

class _NovelExploreScreenState extends State<NovelExploreScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  final _items = <Map<String, dynamic>>[];
  int _page = 1;
  bool _loading = true, _more = false;
  String _query = '';
  @override void initState() { super.initState(); _scroll.addListener(_onScroll); _load(reset: true); }
  @override void dispose() { _scroll.dispose(); _search.dispose(); super.dispose(); }
  void _onScroll() { if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 500) _load(); }
  Future<void> _load({bool reset = false}) async {
    if (_more || (!reset && _loading)) return;
    if (reset) { _page = 1; setState(() => _loading = true); } else { setState(() => _more = true); }
    try {
      final rows = await NovelService.latest(page: _page, query: _query);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        final keys = _items.map((e) => e['url']).toSet();
        _items.addAll(rows.where((e) => keys.add(e['url'])));
        _page++; _loading = false; _more = rows.isNotEmpty;
      });
    } catch (_) { if (mounted) setState(() { _loading = false; _more = false; }); }
  }
  void _submitSearch(String value) { _query = value.trim(); _load(reset: true); }
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.backgroundColor,
    body: SafeArea(child: Column(children: [
      if (!widget.embedded) const AppFixedHeader(title: 'الروايات', showBack: true),
      Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: TextField(
        controller: _search, onSubmitted: _submitSearch, textInputAction: TextInputAction.search,
        style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'ابحث عن رواية...', prefixIcon: const Icon(Icons.search_rounded), suffixIcon: IconButton(onPressed: () { _search.clear(); _submitSearch(''); }, icon: const Icon(Icons.clear_rounded)), filled: true, fillColor: AppTheme.elevatedColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
      )),
      Expanded(child: _loading && _items.isEmpty ? const LoadingView(message: 'جارٍ تحميل الروايات...', size: 58) : _items.isEmpty ? EmptyState(icon: Icons.auto_stories_outlined, title: 'لا توجد روايات', message: 'جرّب كلمة بحث أخرى.', actionLabel: 'إعادة المحاولة', onAction: () => _load(reset: true)) : ContentGrid(
        controller: _scroll, itemCount: _items.length + (_more ? 1 : 0), padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemBuilder: (context, index) { if (index >= _items.length) return const Center(child: CircularProgressIndicator()); final item = _items[index]; return ContentCard(title: item['title']?.toString() ?? 'رواية بدون عنوان', imageUrl: item['image_url']?.toString() ?? '', badge: 'رواية', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NovelDetailsScreen(url: item['url'].toString())))); },
      )),
    ])),
  );
}

class NovelDetailsScreen extends StatefulWidget {
  final String url;
  const NovelDetailsScreen({super.key, required this.url});
  @override State<NovelDetailsScreen> createState() => _NovelDetailsScreenState();
}
class _NovelDetailsScreenState extends State<NovelDetailsScreen> {
  late Future<Map<String, dynamic>> _future;
  @override void initState() { super.initState(); _future = NovelService.details(widget.url); }
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: AppTheme.backgroundColor, appBar: AppBar(title: const Text('تفاصيل الرواية')), body: FutureBuilder<Map<String, dynamic>>(
    future: _future, builder: (context, snapshot) {
      if (!snapshot.hasData) return snapshot.hasError ? ErrorState(onRetry: () => setState(() => _future = NovelService.details(widget.url))) : const LoadingView(message: 'جارٍ تحميل الرواية...', size: 58);
      final novel = snapshot.data!; final chapters = (novel['chapters'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      final image = novel['image_url']?.toString() ?? ''; final title = novel['title']?.toString() ?? 'رواية بدون عنوان';
      return ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 32), children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(borderRadius: BorderRadius.circular(16), child: image.isEmpty ? Container(width: 112, height: 160, color: AppTheme.elevatedColor, child: const Icon(Icons.auto_stories_rounded, size: 42)) : Image.network(image, width: 112, height: 160, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 112, height: 160, color: AppTheme.elevatedColor, child: const Icon(Icons.broken_image_outlined)))),
          const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, height: 1.25, fontWeight: FontWeight.w800)), const SizedBox(height: 10), Text('${chapters.length} فصل متاح', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700))])),
        ]),
        if ((novel['synopsis']?.toString() ?? '').trim().isNotEmpty) ...[const SizedBox(height: 20), Text(novel['synopsis'].toString(), textDirection: TextDirection.rtl, style: const TextStyle(color: AppTheme.textSecondaryColor, height: 1.7))],
        const SizedBox(height: 24), Row(children: [const Expanded(child: Text('الفصول', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800))), Text('${chapters.length}', style: const TextStyle(color: AppTheme.textSecondaryColor))]), const SizedBox(height: 10),
        if (chapters.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('لا توجد فصول متاحة حاليًا.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondaryColor)))
        else ...chapters.map((chapter) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), leading: CircleAvatar(backgroundColor: AppTheme.primaryColor.withOpacity(.18), child: Text('${chapter['number'] ?? ''}', style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12))), title: Text(chapter['title']?.toString() ?? 'فصل الرواية', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)), trailing: const Icon(Icons.chevron_left_rounded), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NovelReaderScreen(url: chapter['url'].toString(), title: chapter['title']?.toString()))))),
      ]);
    },
  ));
}

class NovelReaderScreen extends StatefulWidget {
  final String url; final String? title;
  const NovelReaderScreen({super.key, required this.url, this.title});
  @override State<NovelReaderScreen> createState() => _NovelReaderScreenState();
}
class _NovelReaderScreenState extends State<NovelReaderScreen> {
  late Future<Map<String, dynamic>> _future; double _fontSize = 19;
  @override void initState() { super.initState(); _future = NovelService.chapter(widget.url); }
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: const Color(0xFF101315), appBar: AppBar(title: Text(widget.title?.trim().isNotEmpty == true ? widget.title! : 'قارئ الرواية')), body: FutureBuilder<Map<String, dynamic>>(
    future: _future, builder: (context, snapshot) {
      if (!snapshot.hasData) return snapshot.hasError ? ErrorState(onRetry: () => setState(() => _future = NovelService.chapter(widget.url))) : const LoadingView(message: 'جارٍ تحميل الفصل...', size: 58);
      final chapter = snapshot.data!; final title = chapter['title']?.toString() ?? widget.title ?? 'فصل الرواية';
      return Column(children: [Padding(padding: const EdgeInsets.fromLTRB(16, 10, 10, 8), child: Row(children: [Expanded(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800))), IconButton(tooltip: 'تصغير الخط', onPressed: () => setState(() => _fontSize = (_fontSize - 1).clamp(14, 30).toDouble()), icon: const Icon(Icons.text_decrease)), IconButton(tooltip: 'تكبير الخط', onPressed: () => setState(() => _fontSize = (_fontSize + 1).clamp(14, 30).toDouble()), icon: const Icon(Icons.text_increase))])), Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(22, 8, 22, 50), child: SelectableText(chapter['content']?.toString() ?? '', textDirection: TextDirection.rtl, textAlign: TextAlign.start, style: TextStyle(color: const Color(0xFFE8E3D8), fontSize: _fontSize, height: 1.95))))]);
    },
  ));
}
