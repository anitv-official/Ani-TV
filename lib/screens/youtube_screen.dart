import 'dart:async';

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
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _items = <Map<String, dynamic>>[];
  Timer? _searchDebounce;
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _searchOpen = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreWhenNeeded);
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _loadMoreWhenNeeded() {
    if (_hasMore && _searchController.text.trim().isEmpty && _scrollController.hasClients && _scrollController.position.extentAfter < 520) _load();
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
      final query = _searchController.text.trim();
      final rows = query.isEmpty ? await SourceRegistry.latestFromSource('youtube', page: _page) : await SourceRegistry.searchFromSource('youtube', query, page: _page);
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
      setState(() { _loading = false; _loadingMore = false; _hasMore = false; _error = 'تعذر تحميل فيديوهات YouTube حالياً.'; });
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () => _load(reset: true));
  }

  void _toggleSearch() {
    setState(() => _searchOpen = !_searchOpen);
    if (_searchOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _searchFocusNode.requestFocus());
    } else {
      _searchController.clear();
      _load(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.embedded) const AppFixedHeader(title: 'لائحة YouTube', showBack: true),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(children: [
            Expanded(child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              height: _searchOpen ? 48 : 0,
              child: _searchOpen ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                textInputAction: TextInputAction.search,
                onChanged: _onSearchChanged,
                onSubmitted: (_) => _load(reset: true),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(hintText: 'ابحث في YouTube...', prefixIcon: const Icon(Icons.search_rounded), suffixIcon: IconButton(onPressed: _toggleSearch, icon: const Icon(Icons.close_rounded)), filled: true, fillColor: AppTheme.surfaceColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
              ) : const SizedBox.shrink(),
            )),
            if (_searchOpen) const SizedBox(width: 8),
            IconButton(onPressed: _toggleSearch, tooltip: 'بحث', icon: Icon(_searchOpen ? Icons.search_rounded : Icons.search_rounded)),
            IconButton(tooltip: 'تحديث', onPressed: _loading ? null : () => _load(reset: true), icon: const Icon(Icons.refresh_rounded)),
          ]),
        ),
        if (!_searchOpen) const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text('شاهد أحدث الفيديوهات واكتشف محتوى جديدًا', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13))),
        Expanded(child: _buildBody()),
      ],
    );
    if (widget.embedded) return content;
    return Scaffold(backgroundColor: AppTheme.backgroundColor, body: SafeArea(child: content));
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) return const LoadingView(message: 'جارٍ تحميل فيديوهات YouTube...', size: 64);
    if (_error != null && _items.isEmpty) return ErrorState(message: _error!, onRetry: () => _load(reset: true));
    if (_items.isEmpty) return const EmptyState(icon: Icons.ondemand_video_rounded, title: 'لا توجد نتائج', message: 'جرّب كلمة بحث أخرى أو حدّث القائمة.');
    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () => _load(reset: true),
      child: ContentGrid(
        key: const PageStorageKey<String>('youtube-content-grid'),
        controller: _scrollController,
        columns: 1,
        childAspectRatio: 1.55,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2)));
          final item = _items[index];
          return YouTubeCard(item: item, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => YouTubeWatchScreen(url: item['url']?.toString() ?? '', title: item['title']?.toString() ?? 'YouTube', imageUrl: item['image_url']?.toString() ?? ''))));
        },
      ),
    );
  }
}
