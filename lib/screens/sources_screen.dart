import 'package:flutter/material.dart';
import '../sources/source_base.dart';
import '../sources/source_registry.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/content_card.dart';
import '../widgets/ui/content_grid.dart';
import '../widgets/ui/state_views.dart';
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
          border: Border.all(color: AppTheme.borderColor),
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
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _content,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(message: 'جارٍ تحميل المحتوى...', size: 64);
          }
          if (snapshot.hasError) {
            return ErrorState(onRetry: () => setState(() => _content = widget.source.latest()));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'لا يوجد محتوى حالياً',
              message: 'حاول التحديث لاحقاً.',
            );
          }
          final items = snapshot.data!;
          return RefreshIndicator(
            color: AppTheme.primaryColor,
            onRefresh: () async => setState(() => _content = widget.source.latest()),
            child: ContentGrid(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ContentCard(
                  title: item['title']?.toString(),
                  imageUrl: item['image_url']?.toString(),
                  badge: isAnime ? 'أنمي' : item['type']?.toString(),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => isAnime
                        ? AnimeDetailsScreen(url: item['url'].toString())
                        : ComicDetailsScreen(url: item['url'].toString(), type: item['type']?.toString()),
                  )),
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
          const Text('مصادر المحتوى', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          TextButton(onPressed: onPressed, child: const Text('عرض الكل')),
        ]),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sources.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) => InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 156,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.primaryColor.withOpacity(.16),
                    child: Icon(sources[index].kind == 'anime' ? Icons.movie_outlined : Icons.menu_book_outlined, color: AppTheme.primaryColor, size: 18),
                  ),
                  const SizedBox(width: 9),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(sources[index].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(sources[index].kind == 'anime' ? 'أنمي' : 'مانجا', style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11)),
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
