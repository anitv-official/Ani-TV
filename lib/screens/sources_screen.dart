import 'package:flutter/material.dart';
import '../sources/source_base.dart';
import '../sources/source_registry.dart';
import '../models/remote_plugin.dart';
import '../services/remote_repository_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/content_card.dart';
import '../widgets/ui/content_grid.dart';
import '../widgets/ui/state_views.dart';
import '../widgets/ui/app_fixed_header.dart';
import '../widgets/app_navigation_drawer.dart';
import 'anime_details_screen.dart';
import 'comic_details_screen.dart';
import 'fasel_explore_screen.dart';
import 'video_player_screen.dart';
import 'explore_screen.dart';

Widget sourceContentPage(ContentSource source) {
  if (source.id == 'fasel_hd') return const FaselExploreScreen();
  if (source.id == 'drama_slayer') return const ExploreScreen(initialIsAnime: true, sourceId: 'drama_slayer', title: 'لائحة الدراما');
  return SourceContentScreen(source: source);
}

class SourcesScreen extends StatelessWidget {
  final bool embedded;
  const SourcesScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final sources = SourceRegistry.visibleSources;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      endDrawer: embedded ? null : const AppNavigationDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            if (!embedded) const AppFixedHeader(title: 'مصادر المحتوى'),
            FutureBuilder<List<RemotePlugin>>(
              future: remoteRepositoryService.installedPlugins(),
              builder: (context, snapshot) {
                final installed = snapshot.data ?? const <RemotePlugin>[];
                if (installed.isEmpty) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.borderColor)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('مصادر إضافية مثبتة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    ...installed.map((plugin) {
                      final source = SourceRegistry.sourceForPlugin(plugin);
                      return ListTile(contentPadding: EdgeInsets.zero, dense: true, leading: const Icon(Icons.extension_outlined, color: AppTheme.primaryColor), title: Text(displayPluginName(plugin), style: const TextStyle(color: Colors.white)), subtitle: Text(source == null ? 'مثبت — لا يوجد محول أصلي بعد' : 'اضغط لعرض أعمال المصدر', style: const TextStyle(color: Colors.white54, fontSize: 11)), onTap: source == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => sourceContentPage(source))));
                    }),
                  ]),
                );
              },
            ),
            Expanded(child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: sources.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final source = sources[index];
          return _SourceTile(source: source);
        },
            )),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final ContentSource source;
  const _SourceTile({required this.source});

  @override
  Widget build(BuildContext context) {
    final isVideo = source.kind != 'manga';
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => sourceContentPage(source)),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: source.id == 'youtube' ? const Color(0xFF2A1114) : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: source.id == 'youtube' ? const Color(0xFFE62117) : AppTheme.borderColor),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: source.id == 'youtube' ? const Color(0xFFE62117).withOpacity(.2) : AppTheme.primaryColor.withOpacity(.18),
              child: Icon(source.id == 'youtube' ? Icons.play_arrow_rounded : (isVideo ? Icons.movie_outlined : Icons.menu_book_outlined), color: source.id == 'youtube' ? const Color(0xFFFF3B30) : AppTheme.primaryColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(source.name, style: TextStyle(color: source.id == 'youtube' ? const Color(0xFFFF3B30) : Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(source.kind == 'drama' ? 'أفلام ومسلسلات' : (isVideo ? 'أنمي' : 'مانجا'), style: const TextStyle(color: Colors.white70)),
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
  late final TextEditingController _searchController;
  int _page = 1;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_loadMoreWhenNeeded);
    _searchController = TextEditingController();
    _content = widget.source.latest();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    final query = _searchController.text.trim();
    setState(() {
      _page = 1;
      _content = query.isEmpty ? widget.source.latest() : widget.source.search(query);
    });
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
    final isVideo = widget.source.kind != 'manga';
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      endDrawer: const AppNavigationDrawer(),
      body: SafeArea(
        child: Column(children: [
        AppFixedHeader(title: widget.source.name, showBack: true),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchController,
            textDirection: TextDirection.rtl,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'ابحث داخل ${widget.source.name}',
              prefixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _search),
              filled: true,
              fillColor: AppTheme.surfaceColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
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
                  badge: widget.source.id == 'youtube' ? 'YouTube' : (widget.source.kind == 'drama' ? 'دراما' : (isVideo ? 'أنمي' : item['type']?.toString())),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => widget.source.id == 'youtube'
                        ? VideoPlayerScreen(url: item['url'].toString(), title: item['title']?.toString() ?? 'YouTube', episodeId: item['url'].toString())
                        : isVideo
                            ? AnimeDetailsScreen(url: item['url'].toString())
                            : ComicDetailsScreen(url: item['url'].toString(), type: item['type']?.toString()),
                  )),
                );
              },
            ),
          );
        },
      )),
        ]),
      ),
    );
  }
}

class SourceSummary extends StatelessWidget {
  final VoidCallback onPressed;
  const SourceSummary({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final sources = SourceRegistry.visibleSources;
    if (sources.isEmpty) return const SizedBox.shrink();
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
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => sourceContentPage(sources[index]))),
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
                    child: Icon(sources[index].kind == 'manga' ? Icons.menu_book_outlined : Icons.movie_outlined, color: AppTheme.primaryColor, size: 18),
                  ),
                  const SizedBox(width: 9),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(sources[index].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(sources[index].id == 'youtube' ? 'فيديوهات YouTube' : (sources[index].kind == 'drama' ? 'أفلام ومسلسلات' : (sources[index].kind == 'anime' ? 'أنمي' : 'مانجا')), style: TextStyle(color: sources[index].id == 'youtube' ? const Color(0xFFFF3B30) : AppTheme.textSecondaryColor, fontSize: 11)),
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
