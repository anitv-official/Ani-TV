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
  @override
  State<NovelExploreScreen> createState() => _NovelExploreScreenState();
}

class _NovelExploreScreenState extends State<NovelExploreScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  final _items = <Map<String, dynamic>>[];
  int _page = 1;
  bool _loading = true, _more = false;
  String _query = '';

  @override
  void initState() { super.initState(); _scroll.addListener(_onScroll); _load(reset: true); }
  @override
  void dispose() { _scroll.dispose(); _search.dispose(); super.dispose(); }
  void _onScroll() { if (_scroll.hasClients && _scroll.position.extentAfter < 500) _load(); }
  Future<void> _load({bool reset = false}) async {
    if (_more || (!reset && _loading)) return;
    if (reset) { _page = 1; setState(() => _loading = true); } else { setState(() => _more = true); }
    try {
      final rows = await NovelService.latest(page: _page, query: _query);
      if (!mounted) return;
      final keys = _items.map((e) => e['url']).toSet();
      setState(() {
        if (reset) _items.clear();
        _items.addAll(rows.where((e) => keys.add(e['url'])));
        _page++;
        _loading = false; _more = false;
      });
    } catch (_) { if (mounted) setState(() { _loading = false; _more = false; }); }
  }
  void _submitSearch(String value) { _query = value.trim(); _load(reset: true); }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.backgroundColor,
    body: SafeArea(child: Column(children: [
      if (!widget.embedded) const AppFixedHeader(title: 'الروايات', showBack: true),
      Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: TextField(
        controller: _search, onSubmitted: _submitSearch, textInputAction: TextInputAction.search,
        style: const TextStyle(color: Colors.white), decoration: InputDecoration(
          hintText: 'ابحث عن رواية...', prefixIcon: const Icon(Icons.search_rounded), suffixIcon: IconButton(onPressed: () { _search.clear(); _submitSearch(''); }, icon: const Icon(Icons.clear_rounded)),
          filled: true, fillColor: AppTheme.elevatedColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ),
      )),
      Expanded(child: _loading && _items.isEmpty ? const LoadingView(message: 'جارٍ تحميل الروايات...', size: 58) : _items.isEmpty ? EmptyState(icon: Icons.auto_stories_outlined, title: 'لا توجد روايات', message: 'جرّب كلمة بحث أخرى.', actionLabel: 'إعادة المحاولة', onAction: () => _load(reset: true)) : ContentGrid(
        controller: _scroll, itemCount: _items.length + (_more ? 1 : 0), padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemBuilder: (context, index) { if (index >= _items.length) return const Center(child: CircularProgressIndicator()); final item = _items[index]; return ContentCard(title: item['title']?.toString(), imageUrl: item['image_url']?.toString(), badge: 'رواية', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NovelDetailsScreen(url: item['url'].toString())))); },
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
    future: _future, builder: (context, snapshot) { if (!snapshot.hasData) return snapshot.hasError ? ErrorState(onRetry: () => setState(() => _future = NovelService.details(widget.url))) : const LoadingView(message: 'جارٍ تحميل الرواية...', size: 58); final novel = snapshot.data!; final chapters = (novel['chapters'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(); return ListView(padding: const EdgeInsets.all(16), children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [if ((novel['image_url'] ?? '').toString().isNotEmpty) ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(novel['image_url'], width: 112, height: 160, fit: BoxFit.cover)), const SizedBox(width: 14), Expanded(child: Text(novel['title']?.toString() ?? 'رواية', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800))) ]),
      const SizedBox(height: 18), Text(novel['synopsis']?.toString() ?? '', style: const TextStyle(color: AppTheme.textSecondaryColor, height: 1.6)), const SizedBox(height: 20),
      Text('${chapters.length} فصل', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 8),
      ...chapters.map((chapter) => Card(color: AppTheme.elevatedColor, child: ListTile(title: Text(chapter['title']?.toString() ?? 'فصل', style: const TextStyle(color: Colors.white)), trailing: const Icon(Icons.chevron_left_rounded), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NovelReaderScreen(url: chapter['url'].toString())))))),
    ]); },
  ));
}

class NovelReaderScreen extends StatefulWidget {
  final String url;
  const NovelReaderScreen({super.key, required this.url});
  @override State<NovelReaderScreen> createState() => _NovelReaderScreenState();
}
class _NovelReaderScreenState extends State<NovelReaderScreen> {
  late Future<Map<String, dynamic>> _future;
  double _fontSize = 19;
  @override void initState() { super.initState(); _future = NovelService.chapter(widget.url); }
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: const Color(0xFF101315), appBar: AppBar(title: const Text('قارئ الرواية')), body: FutureBuilder<Map<String, dynamic>>(
    future: _future, builder: (context, snapshot) { if (!snapshot.hasData) return snapshot.hasError ? ErrorState(onRetry: () => setState(() => _future = NovelService.chapter(widget.url))) : const LoadingView(message: 'جارٍ تحميل الفصل...', size: 58); final chapter = snapshot.data!; return Column(children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), child: Row(children: [Expanded(child: Text(chapter['title']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))), IconButton(onPressed: () => setState(() => _fontSize = (_fontSize - 1).clamp(14, 30).toDouble()), icon: const Icon(Icons.text_decrease)), IconButton(onPressed: () => setState(() => _fontSize = (_fontSize + 1).clamp(14, 30).toDouble()), icon: const Icon(Icons.text_increase))])),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(22, 8, 22, 40), child: SelectableText(chapter['content']?.toString() ?? '', textDirection: TextDirection.rtl, style: TextStyle(color: const Color(0xFFE8E3D8), fontSize: _fontSize, height: 1.9, fontFamily: 'sans')))),
    ]); },
  ));
}
