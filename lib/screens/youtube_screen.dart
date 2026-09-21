import 'package:flutter/material.dart';

import '../sources/source_registry.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/app_fixed_header.dart';
import '../widgets/ui/content_grid.dart';
import '../widgets/ui/content_card.dart';
import '../widgets/ui/state_views.dart';
import 'youtube_watch_screen.dart';

class YoutubeScreen extends StatefulWidget {
  final bool embedded;

  const YoutubeScreen({super.key, this.embedded = false});

  @override
  State<YoutubeScreen> createState() => _YoutubeScreenState();
}

class _YoutubeScreenState extends State<YoutubeScreen> {
  final _scrollController = ScrollController();
  final _items = <Map<String, dynamic>>[];
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreWhenNeeded);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMoreWhenNeeded() {
    if (_hasMore && _scrollController.hasClients && _scrollController.position.extentAfter < 480) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loadingMore || (!reset && _loading)) return;
    if (reset) {
      _page = 1;
      _error = null;
      if (mounted) setState(() => _loading = true);
    } else if (mounted) {
      setState(() => _loadingMore = true);
    }

    try {
      final rows = await SourceRegistry.latestFromSource('youtube', page: _page);
      if (!mounted) return;
      final known = _items.map((item) => item['url']).toSet();
      final fresh = rows.where((item) => known.add(item['url'])).toList();
      setState(() {
        if (reset) _items.clear();
        _items.addAll(fresh);
        _page++;
        _hasMore = fresh.isNotEmpty && rows.isNotEmpty;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _hasMore = false;
        _error = 'تعذر تحميل فيديوهات YouTube حالياً.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.embedded) const AppFixedHeader(title: 'لائحة YouTube', showBack: true),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text('لائحة YouTube', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              ),
              IconButton(
                tooltip: 'تحديث',
                onPressed: _loading ? null : () => _load(reset: true),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );

    if (widget.embedded) return content;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(child: content),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const LoadingView(message: 'جارٍ تحميل فيديوهات YouTube...', size: 64);
    }
    if (_error != null && _items.isEmpty) {
      return ErrorState(message: _error!, onRetry: () => _load(reset: true));
    }
    if (_items.isEmpty) {
      return const EmptyState(
        icon: Icons.ondemand_video_rounded,
        title: 'لا توجد فيديوهات حالياً',
        message: 'حاول التحديث لاحقاً.',
      );
    }
    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () => _load(reset: true),
      child: ContentGrid(
        key: const PageStorageKey<String>('youtube-content-grid'),
        controller: _scrollController,
        columns: 1,
        childAspectRatio: 1.35,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2)));
          }
          final item = _items[index];
          return YouTubeCard(
            item: item,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => YouTubeWatchScreen(
                  url: item['url']?.toString() ?? '',
                  title: item['title']?.toString() ?? 'YouTube',
                  imageUrl: item['image_url']?.toString() ?? '',
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
