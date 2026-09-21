import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../sources/source_registry.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/app_fixed_header.dart';
import '../widgets/ui/state_views.dart';

class YoutubeScreen extends StatefulWidget {
  final bool embedded;
  const YoutubeScreen({super.key, this.embedded = false});

  @override
  State<YoutubeScreen> createState() => _YoutubeScreenState();
}

class _YoutubeScreenState extends State<YoutubeScreen> {
  late Future<List<Map<String, dynamic>>> _content;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  final ScrollController _scrollController = ScrollController();
  int _page = 1;
  bool _loadingMore = false;
  bool _searchExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _content = SourceRegistry.youtube.latest();
    _scrollController.addListener(_loadMoreWhenNeeded);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMoreWhenNeeded)
      ..dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _search() {
    final query = _searchController.text.trim();
    setState(() {
      _page = 1;
      _content = query.isEmpty ? SourceRegistry.youtube.latest() : SourceRegistry.youtube.search(query);
    });
    _searchFocusNode.unfocus();
  }

  void _toggleSearch() {
    setState(() => _searchExpanded = !_searchExpanded);
    if (_searchExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _searchFocusNode.requestFocus());
    } else {
      _searchFocusNode.unfocus();
    }
  }

  void _loadMoreWhenNeeded() {
    if (_scrollController.hasClients && _scrollController.position.extentAfter < 500) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !mounted) return;
    _loadingMore = true;
    try {
      final next = await SourceRegistry.youtube.nextPage(query: _searchController.text.trim(), page: _page + 1);
      if (!mounted || next.isEmpty) return;
      final current = await _content;
      final keys = current.map((item) => item['video_id'] ?? item['url']).toSet();
      setState(() {
        _page++;
        _content = Future.value([...current, ...next.where((item) => keys.add(item['video_id'] ?? item['url']))]);
      });
    } catch (_) {
      // Infinite scroll is best-effort; the visible list remains usable.
    } finally {
      _loadingMore = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      body: SafeArea(
        child: Column(
          children: [
            if (!widget.embedded) const AppFixedHeader(title: 'YouTube', showBack: true),
            _buildYoutubeToolbar(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildYoutubeToolbar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF321217), Color(0xFF171114)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE62117).withOpacity(.35)),
      ),
      child: Row(
        children: [
          const CircleAvatar(backgroundColor: Color(0xFFE62117), child: Icon(Icons.play_arrow_rounded, color: Colors.white)),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _searchExpanded
                  ? TextField(
                      key: const ValueKey('youtube-search-field'),
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      textDirection: TextDirection.rtl,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(hintText: 'ابحث في YouTube...', border: InputBorder.none, isDense: true),
                    )
                  : const Text('YouTube داخل AniTV', key: ValueKey('youtube-title'), style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            width: _searchExpanded ? 44 : 48,
            child: IconButton(
              tooltip: _searchExpanded ? 'تنفيذ البحث' : 'بحث',
              onPressed: _searchExpanded ? _search : _toggleSearch,
              icon: Icon(_searchExpanded ? Icons.arrow_forward_rounded : Icons.search_rounded, color: Colors.white),
            ),
          ),
          if (_searchExpanded)
            IconButton(tooltip: 'إغلاق البحث', onPressed: _toggleSearch, icon: const Icon(Icons.close_rounded, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _content,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const LoadingView(message: 'جارٍ تحميل YouTube...', size: 64);
        if (snapshot.hasError) return ErrorState(onRetry: () => setState(() => _content = SourceRegistry.youtube.latest()));
        final items = snapshot.data ?? const <Map<String, dynamic>>[];
        if (items.isEmpty) return const EmptyState(icon: Icons.ondemand_video_outlined, title: 'لا توجد فيديوهات', message: 'جرّب كلمة بحث أخرى.');
        return RefreshIndicator(
          color: const Color(0xFFE62117),
          onRefresh: () async => setState(() => _content = _searchController.text.trim().isEmpty ? SourceRegistry.youtube.latest() : SourceRegistry.youtube.search(_searchController.text.trim())),
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
            itemCount: items.length + (_loadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= items.length) return const Padding(padding: EdgeInsets.all(22), child: Center(child: CircularProgressIndicator(color: Color(0xFFE62117))));
              return _YoutubeCard(item: items[index], onTap: () => _openVideo(items[index]));
            },
          ),
        );
      },
    );
  }

  void _openVideo(Map<String, dynamic> item) {
    final url = item['url']?.toString() ?? '';
    if (url.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => YoutubePlayerScreen(url: url, title: item['title']?.toString() ?? 'YouTube')));
  }
}

class _YoutubeCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const _YoutubeCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final channel = item['description']?.toString() ?? '';
    final duration = item['rating']?.toString() ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF171719),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(fit: StackFit.expand, children: [
              Image.network(item['image_url']?.toString() ?? '', fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.black26, child: const Icon(Icons.ondemand_video_outlined, color: Colors.white54, size: 46))),
              const Align(alignment: Alignment.center, child: CircleAvatar(backgroundColor: Color(0xDDE62117), child: Icon(Icons.play_arrow_rounded, color: Colors.white))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CircleAvatar(radius: 18, backgroundColor: Color(0xFFE62117), child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item['title']?.toString() ?? 'فيديو YouTube', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                if (channel.isNotEmpty || duration.isNotEmpty) ...[const SizedBox(height: 6), Text([channel, duration].where((value) => value.isNotEmpty).join(' • '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 12))],
              ])),
            ]),
          ),
        ]),
      ),
    );
  }
}

class YoutubePlayerScreen extends StatefulWidget {
  final String url;
  final String title;
  const YoutubePlayerScreen({super.key, required this.url, required this.title});

  @override
  State<YoutubePlayerScreen> createState() => _YoutubePlayerScreenState();
}

class _YoutubePlayerScreenState extends State<YoutubePlayerScreen> {
  late final WebViewController _controller;
  bool _landscape = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(onNavigationRequest: (_) => NavigationDecision.navigate))
      ..loadRequest(Uri.parse(_mobileWatchUrl(widget.url)));
  }

  @override
  void dispose() {
    _restorePortrait();
    super.dispose();
  }

  Future<void> _toggleOrientation() async {
    setState(() => _landscape = !_landscape);
    if (_landscape) {
      await SystemChrome.setPreferredOrientations(const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await _restorePortrait();
    }
  }

  Future<void> _restorePortrait() async {
    await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15)),
        actions: [IconButton(tooltip: _landscape ? 'الوضع الطولي' : 'ملء الشاشة', onPressed: _toggleOrientation, icon: Icon(_landscape ? Icons.screen_lock_portrait_rounded : Icons.fullscreen_rounded))],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }

  String _mobileWatchUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return value;
    final id = uri.host.contains('youtu.be') ? (uri.pathSegments.isEmpty ? '' : uri.pathSegments.first) : (uri.queryParameters['v'] ?? '');
    if (id.isEmpty) return value;
    return Uri.https('m.youtube.com', '/watch', {'v': id, 'app': 'm', 'persist_app': '1'}).toString();
  }
}
