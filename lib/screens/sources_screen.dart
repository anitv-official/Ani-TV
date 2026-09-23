import 'dart:async';
import 'package:flutter/material.dart';
import '../sources/source_base.dart';
import '../sources/source_presentation.dart';
import '../sources/source_registry.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/content_card.dart';
import '../widgets/ui/content_grid.dart';
import '../widgets/ui/state_views.dart';
import '../widgets/ui/app_fixed_header.dart';
import '../widgets/ui/app_search_bar.dart';
import '../widgets/ui/source_icon.dart';
import '../widgets/app_navigation_drawer.dart';
import 'anime_details_screen.dart';
import 'youtube_watch_screen.dart';
import 'comic_details_screen.dart';

Widget sourceContentPage(ContentSource source) => SourceContentScreen(source: source);

class SourcesScreen extends StatelessWidget {
  final bool embedded;
  const SourcesScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final sources = SourceRegistry.visibleSources;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      endDrawer: embedded ? null : const AppNavigationDrawer(),
      body: SafeArea(child: Column(children: [
        if (!embedded) const AppFixedHeader(title: 'مصادر المحتوى'),
        Expanded(child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: sources.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, index) => _SourceTile(source: sources[index]),
        )),
      ])),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final ContentSource source;
  const _SourceTile({required this.source});

  @override
  Widget build(BuildContext context) {
    final state = SourcePresentation.availability(source.id);
    final accent = state == SourceAvailability.available ? Colors.greenAccent : Colors.orangeAccent;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: state.isEnabled ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => sourceContentPage(source))) : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderColor)),
        child: Row(children: [
          SourceIcon(source: source, size: 52),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(source.name, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(SourcePresentation.kindLabel(source.kind), style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Row(children: [Icon(state == SourceAvailability.available ? Icons.check_circle : Icons.info_outline, size: 15, color: accent), const SizedBox(width: 4), Text(state.label, style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w700))]),
            const SizedBox(height: 4),
            Text(source.hosts.join(' • '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ])),
          Icon(state.isEnabled ? Icons.chevron_left : Icons.block, color: state.isEnabled ? Colors.white54 : Colors.white30),
        ]),
      ),
    );
  }
}

class SourceContentScreen extends StatefulWidget {
  final ContentSource source;
  const SourceContentScreen({super.key, required this.source});
  @override State<SourceContentScreen> createState() => _SourceContentScreenState();
}

class _SourceContentScreenState extends State<SourceContentScreen> {
  late Future<List<Map<String, dynamic>>> _content;
  late final ScrollController _scrollController;
  late final TextEditingController _searchController;
  Timer? _searchDebounce;
  int _page = 1;
  bool _loadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_loadMoreWhenNeeded);
    _searchController = TextEditingController();
    _content = SourcePresentation.availability(widget.source.id).isEnabled ? widget.source.latest() : Future.value(const []);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _search({bool immediate = false}) {
    _searchDebounce?.cancel();
    final query = _searchController.text.trim();
    void run() {
      if (!mounted) return;
      setState(() {
        _page = 1;
        _hasMore = true;
        _content = query.isEmpty ? widget.source.latest() : widget.source.search(query);
      });
    }
    if (immediate) run();
    else _searchDebounce = Timer(const Duration(milliseconds: 420), run);
  }

  void _loadMoreWhenNeeded() {
    if (_hasMore && _scrollController.hasClients && _scrollController.position.extentAfter < 400) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !mounted) return;
    setState(() => _loadingMore = true);
    try {
      final next = await widget.source.nextPage(query: _searchController.text.trim(), page: _page + 1);
      if (!mounted) return;
      if (next.isEmpty) {
        setState(() => _hasMore = false);
        return;
      }
      final current = await _content;
      final keys = current.map((e) => e['url'] ?? e['title']).toSet();
      setState(() {
        _page++;
        _content = Future.value([...current, ...next.where((e) => keys.add(e['url'] ?? e['title']))]);
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.source.kind != 'manga';
    final state = SourcePresentation.availability(widget.source.id);
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      endDrawer: const AppNavigationDrawer(),
      body: SafeArea(child: Column(children: [
        AppFixedHeader(title: widget.source.name, showBack: true),
        _SourcePageHeader(source: widget.source, state: state),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: ExpandableSearchBar(
            controller: _searchController,
            hintText: 'ابحث داخل ${widget.source.name}',
            onChanged: (_) => _search(),
            onSubmitted: (_) => _search(immediate: true),
            onClear: () { _searchController.clear(); _search(immediate: true); },
          ),
        ),
        Expanded(child: state == SourceAvailability.unavailable
            ? const EmptyState(icon: Icons.block, title: 'المصدر معطل', message: 'لا يمكن تحميل محتوى هذا المصدر حالياً.')
            : FutureBuilder<List<Map<String, dynamic>>>(
                future: _content,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const LoadingView(message: 'جارٍ تحميل المحتوى...', size: 64);
                  if (snapshot.hasError) return ErrorState(onRetry: () => setState(() => _content = widget.source.latest()));
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return const EmptyState(icon: Icons.inventory_2_outlined, title: 'لا يوجد محتوى حالياً', message: 'حاول البحث أو التحديث لاحقاً.');
                  final items = snapshot.data!;
                  return RefreshIndicator(
                    color: AppTheme.primaryColor,
                    onRefresh: () async => setState(() => _content = _searchController.text.trim().isEmpty ? widget.source.latest() : widget.source.search(_searchController.text.trim())),
                    child: ContentGrid(
                      controller: _scrollController,
                      columns: widget.source.id == 'youtube' ? 1 : null,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      childAspectRatio: widget.source.id == 'youtube' ? 1.35 : .66,
                      itemCount: items.length + (_loadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= items.length) return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2)));
                        final item = items[index];
                        if (widget.source.id == 'youtube') {
                          return YouTubeCard(item: item, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => YouTubeWatchScreen(url: item['url'].toString(), title: item['title']?.toString() ?? 'YouTube', imageUrl: item['image_url']?.toString() ?? ''))));
                        }
                        return ContentCard(
                          title: item['title']?.toString(), imageUrl: item['image_url']?.toString(),
                          badge: SourcePresentation.kindLabel(widget.source.kind),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => isVideo ? AnimeDetailsScreen(url: item['url'].toString()) : ComicDetailsScreen(url: item['url'].toString(), type: item['type']?.toString()))),
                        );
                      },
                    ),
                  );
                },
              )),
      ])),
    );
  }
}

class _SourcePageHeader extends StatelessWidget {
  final ContentSource source;
  final SourceAvailability state;
  const _SourcePageHeader({required this.source, required this.state});

  @override
  Widget build(BuildContext context) {
    final color = state == SourceAvailability.available ? Colors.greenAccent : Colors.orangeAccent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(children: [
        SourceIcon(source: source, size: 44),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(SourcePresentation.kindLabel(source.kind), style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12)),
          const SizedBox(height: 3),
          Text(SourcePresentation.statusMessage(source.id, source.kind), style: TextStyle(color: AppTheme.textMutedColor, fontSize: 11)),
        ])),
        Row(children: [Icon(state == SourceAvailability.available ? Icons.check_circle : Icons.info_outline, size: 15, color: color), const SizedBox(width: 4), Text(state.label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700))]),
      ]),
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
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('مصادر المحتوى', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), TextButton(onPressed: onPressed, child: const Text('عرض الكل'))]),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sources.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final source = sources[index];
              return InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => sourceContentPage(source))),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 172,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.borderColor)),
                  child: Row(children: [
                    SourceIcon(source: source, size: 36),
                    const SizedBox(width: 9),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(source.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(SourcePresentation.kindLabel(source.kind), style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11)),
                    ])),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
