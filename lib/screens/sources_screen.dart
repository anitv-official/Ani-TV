import 'package:flutter/material.dart';
import '../sources/source_base.dart';
import '../sources/source_registry.dart';
import '../theme/app_theme.dart';
import 'anime_details_screen.dart';
import 'comic_details_screen.dart';

class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sources = SourceRegistry.all;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('مصادر المحتوى'),
        backgroundColor: AppTheme.backgroundColor,
        foregroundColor: Colors.white,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: sources.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final source = sources[index];
          return _SourceTile(source: source);
        },
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final ContentSource source;
  const _SourceTile({required this.source});

  @override
  Widget build(BuildContext context) {
    final isAnime = source.kind == 'anime';
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SourceContentScreen(source: source)),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(.08)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primaryColor.withOpacity(.18),
              child: Icon(isAnime ? Icons.movie_outlined : Icons.menu_book_outlined,
                  color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(source.name,
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(isAnime ? 'أنمي' : 'مانجا', style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text(source.hosts.join(' • '), maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_left, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

class SourceContentScreen extends StatefulWidget {
  final ContentSource source;
  const SourceContentScreen({super.key, required this.source});

  @override
  State<SourceContentScreen> createState() => _SourceContentScreenState();
}

class _SourceContentScreenState extends State<SourceContentScreen> {
  late Future<List<Map<String, dynamic>>> _content;
  late final ScrollController _scrollController;
  int _page = 1;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_loadMoreWhenNeeded);
    _content = widget.source.latest();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMoreWhenNeeded() {
    if (_scrollController.hasClients && _scrollController.position.extentAfter < 400) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !mounted) return;
    _loadingMore = true;
    try {
      final next = await widget.source.latest(page: _page + 1);
      if (!mounted || next.isEmpty) return;
      final current = await _content;
      final keys = current.map((e) => e['url'] ?? e['title']).toSet();
      setState(() {
        _page++;
        _content = Future.value([...current, ...next.where((e) => keys.add(e['url'] ?? e['title']))]);
      });
    } finally {
      _loadingMore = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAnime = widget.source.kind == 'anime';
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.source.name),
        backgroundColor: AppTheme.backgroundColor,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _content,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text('لا يوجد محتوى متاح من هذا المصدر حاليًا',
                  style: const TextStyle(color: Colors.white70)),
            );
          }
          final items = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => setState(() => _content = widget.source.latest()),
            child: GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 16, childAspectRatio: .58,
              ),
              itemBuilder: (context, index) {
                final item = items[index];
                return InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => isAnime
                        ? AnimeDetailsScreen(url: item['url'].toString())
                        : ComicDetailsScreen(url: item['url'].toString(), type: item['type']?.toString()),
                  )),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(item['image_url']?.toString() ?? '', fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => Container(color: AppTheme.surfaceColor,
                              child: const Center(child: Icon(Icons.image_not_supported_outlined, color: Colors.white38))),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(item['title']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ]),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class SourceSummary extends StatelessWidget {
  final VoidCallback onPressed;
  const SourceSummary({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final sources = SourceRegistry.all;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('مصادر المحتوى', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          TextButton(onPressed: onPressed, child: const Text('عرض الكل')),
        ]),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sources.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) => InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 150,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppTheme.surfaceColor, AppTheme.surfaceColor.withOpacity(.72)]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(.18)),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: AppTheme.primaryColor.withOpacity(.16),
                    child: Icon(sources[index].kind == 'anime' ? Icons.movie_filter_outlined : Icons.menu_book_outlined, color: AppTheme.primaryColor, size: 20),
                  ),
                  const SizedBox(width: 9),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(sources[index].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(sources[index].kind == 'anime' ? 'أنمي' : 'مانجا', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                  ])),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
