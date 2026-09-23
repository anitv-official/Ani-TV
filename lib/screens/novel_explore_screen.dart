import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/novel_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/app_fixed_header.dart';
import '../widgets/ui/app_search_bar.dart';
import '../widgets/ui/content_card.dart';
import '../widgets/ui/content_grid.dart';
import '../widgets/ui/state_views.dart';
import '../widgets/ui/universal_content_details.dart';

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
  bool _loading = true;
  bool _more = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 500) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_more || (!reset && _loading)) return;
    if (reset) {
      _page = 1;
      setState(() => _loading = true);
    } else {
      setState(() => _more = true);
    }
    try {
      final rows = await NovelService.latest(page: _page, query: _query);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        final keys = _items.map((item) => item['url']).toSet();
        _items.addAll(rows.where((item) => keys.add(item['url'])));
        _page++;
        _loading = false;
        _more = rows.isNotEmpty;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _more = false; });
    }
  }

  void _submitSearch(String value) {
    _query = value.trim();
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            if (!widget.embedded) const AppFixedHeader(title: 'الروايات', showBack: true),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: ExpandableSearchBar(
                controller: _search,
                hintText: 'ابحث عن رواية...',
                onSubmitted: _submitSearch,
                onClear: () {
                  _search.clear();
                  _submitSearch('');
                },
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const LoadingView(message: 'جارٍ تحميل الروايات...', size: 58);
    }
    if (_items.isEmpty) {
      return EmptyState(
        icon: Icons.auto_stories_outlined,
        title: 'لا توجد روايات',
        message: 'جرّب كلمة بحث أخرى.',
        actionLabel: 'إعادة المحاولة',
        onAction: () => _load(reset: true),
      );
    }
    return ContentGrid(
      controller: _scroll,
      itemCount: _items.length + (_more ? 1 : 0),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemBuilder: (context, index) {
        if (index >= _items.length) return const Center(child: CircularProgressIndicator());
        final item = _items[index];
        return ContentCard(
          title: item['title']?.toString() ?? 'رواية بدون عنوان',
          imageUrl: item['image_url']?.toString() ?? '',
          badge: 'رواية',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => NovelDetailsScreen(url: item['url'].toString())),
          ),
        );
      },
    );
  }
}

class NovelDetailsScreen extends StatefulWidget {
  final String url;
  const NovelDetailsScreen({super.key, required this.url});

  @override
  State<NovelDetailsScreen> createState() => _NovelDetailsScreenState();
}

class _NovelDetailsScreenState extends State<NovelDetailsScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = NovelService.details(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return snapshot.hasError
                ? ErrorState(onRetry: () => setState(() => _future = NovelService.details(widget.url)))
                : const LoadingView(message: 'جارٍ تحميل الرواية...', size: 58);
          }
          final novel = snapshot.data!;
          final chapters = (novel['chapters'] as List? ?? const [])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          final image = novel['image_url']?.toString() ?? '';
          final title = novel['title']?.toString() ?? 'رواية بدون عنوان';
          return ListView(children: [
            UniversalDetailsHero(
              title: title,
              alternativeTitle: (novel['alternative_title'] ?? novel['alt_title'] ?? novel['author'])?.toString(),
              imageUrl: image,
              backdropUrl: (novel['backdrop_url'] ?? novel['backdrop'] ?? novel['cover_url'])?.toString(),
              typeLabel: 'رواية',
              status: novel['status']?.toString(),
              fallbackIcon: Icons.auto_stories_rounded,
              onBack: () => Navigator.pop(context),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 32), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              UniversalMetadata(items: [
                UniversalMetaItem(value: '${novel['rating'] ?? ''}', label: 'التقييم', icon: Icons.star_rounded, color: Colors.amber),
                UniversalMetaItem(value: '${chapters.length}', label: 'الفصول', icon: Icons.menu_book_rounded, color: const Color(0xFF67C96B)),
                UniversalMetaItem(value: '${novel['year'] ?? novel['release_year'] ?? ''}', label: 'السنة', icon: Icons.calendar_month_rounded, color: const Color(0xFF36B9E8)),
                UniversalMetaItem(value: novel['status']?.toString() ?? '', label: 'الحالة', icon: Icons.info_outline_rounded, color: Colors.greenAccent),
              ]),
              if (novel['genres'] is List) UniversalGenreChips(genres: novel['genres'] as List),
              const SizedBox(height: 14),
              UniversalDescription(text: novel['synopsis']?.toString() ?? '', title: 'القصة'),
              UniversalSectionHeader('الفصول', trailing: '${chapters.length} فصل'),
              const SizedBox(height: 10),
              if (chapters.isEmpty)
                const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('لا توجد فصول متاحة حاليًا.', style: TextStyle(color: AppTheme.textSecondaryColor))))
              else
                ...chapters.asMap().entries.map((entry) => _chapterTile(context, chapters, entry.key, entry.value)),
            ])),
          ]);
        },
      ),
    );
  }

  Widget _chapterTile(BuildContext context, List<Map<String, dynamic>> chapters, int index, Map<String, dynamic> chapter) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor.withOpacity(.18),
          child: Text('${chapter['number'] ?? index + 1}', style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12)),
        ),
        title: Text(chapter['title']?.toString() ?? 'فصل الرواية', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.chevron_left_rounded),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NovelReaderScreen(
              url: chapter['url'].toString(),
              title: chapter['title']?.toString(),
              chapterNumber: index + 1,
              totalChapters: chapters.length,
              previousUrl: index > 0 ? chapters[index - 1]['url']?.toString() : null,
              nextUrl: index + 1 < chapters.length ? chapters[index + 1]['url']?.toString() : null,
            ),
          ),
        ),
      ),
    );
  }
}

class NovelReaderScreen extends StatefulWidget {
  final String url;
  final String? title;
  final String? previousUrl;
  final String? nextUrl;
  final int? chapterNumber;
  final int? totalChapters;

  const NovelReaderScreen({
    super.key,
    required this.url,
    this.title,
    this.previousUrl,
    this.nextUrl,
    this.chapterNumber,
    this.totalChapters,
  });

  @override
  State<NovelReaderScreen> createState() => _NovelReaderScreenState();
}

class _NovelReaderScreenState extends State<NovelReaderScreen> {
  late Future<Map<String, dynamic>> _future;
  late final ScrollController _scrollController;
  Timer? _autoTimer;
  double _fontSize = 19;
  double _lineHeight = 1.95;
  double _textWidth = 720;
  double _autoSpeed = 24;
  bool _autoScroll = false;
  bool _showControls = true;
  bool _resumeShown = false;
  String _theme = 'dark';
  double _savedOffset = 0;

  String get _progressKey => 'novel_progress_${widget.url}';
  Color get _background => _theme == 'sepia' ? const Color(0xFFF3E7CF) : _theme == 'light' ? const Color(0xFFF8F9FA) : const Color(0xFF101315);
  Color get _foreground => _theme == 'sepia' ? const Color(0xFF4A3925) : _theme == 'light' ? const Color(0xFF202124) : const Color(0xFFE8E3D8);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _future = NovelService.chapter(widget.url);
    _loadPreferences();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _fontSize = prefs.getDouble('novel_font_size') ?? 19;
      _lineHeight = prefs.getDouble('novel_line_height') ?? 1.95;
      _textWidth = prefs.getDouble('novel_text_width') ?? 720;
      _theme = prefs.getString('novel_theme') ?? 'dark';
      _savedOffset = prefs.getDouble(_progressKey) ?? 0;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('novel_font_size', _fontSize);
    await prefs.setDouble('novel_line_height', _lineHeight);
    await prefs.setDouble('novel_text_width', _textWidth);
    await prefs.setString('novel_theme', _theme);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    if ((offset - _savedOffset).abs() > 24) {
      _savedOffset = offset;
      SharedPreferences.getInstance().then((prefs) => prefs.setDouble(_progressKey, offset));
    }
  }

  void _toggleAutoScroll() {
    setState(() => _autoScroll = !_autoScroll);
    _autoTimer?.cancel();
    if (!_autoScroll) return;
    _autoTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!_scrollController.hasClients || (_scrollController.position.atEdge && _scrollController.offset > 0)) {
        setState(() => _autoScroll = false);
        _autoTimer?.cancel();
        return;
      }
      _scrollController.jumpTo((_scrollController.offset + _autoSpeed / 12).clamp(0, _scrollController.position.maxScrollExtent).toDouble());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: _showControls
          ? AppBar(
              backgroundColor: _background,
              foregroundColor: _foreground,
              title: Text(widget.title?.trim().isNotEmpty == true ? widget.title! : 'قارئ الرواية', maxLines: 1, overflow: TextOverflow.ellipsis),
              actions: [
                IconButton(onPressed: _toggleAutoScroll, tooltip: _autoScroll ? 'إيقاف التمرير' : 'تمرير تلقائي', icon: Icon(_autoScroll ? Icons.pause_circle_filled : Icons.play_circle_outline)),
                IconButton(onPressed: _showSettings, tooltip: 'إعدادات القراءة', icon: const Icon(Icons.tune_rounded)),
              ],
            )
          : null,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return snapshot.hasError
                ? ErrorState(onRetry: () => setState(() => _future = NovelService.chapter(widget.url)))
                : const LoadingView(message: 'جارٍ تحميل الفصل...', size: 58);
          }
          final chapter = snapshot.data!;
          final title = chapter['title']?.toString() ?? widget.title ?? 'فصل الرواية';
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_resumeShown && _savedOffset > 40 && _scrollController.hasClients) {
              _resumeShown = true;
              _showResumeDialog();
            }
          });
          return GestureDetector(
            onTap: () => setState(() => _showControls = !_showControls),
            child: Column(
              children: [
                if (_showControls)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 10, 8),
                    child: Row(
                      children: [
                        Expanded(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl, style: TextStyle(color: _foreground, fontSize: 17, fontWeight: FontWeight.w800))),
                        if (widget.chapterNumber != null) Text('${widget.chapterNumber}/${widget.totalChapters ?? '?'}', style: TextStyle(color: _foreground.withOpacity(.7), fontSize: 12)),
                      ],
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 60),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: _textWidth),
                        child: SelectableText(chapter['content']?.toString() ?? 'لا يوجد محتوى لهذا الفصل.', textDirection: TextDirection.rtl, textAlign: TextAlign.start, style: TextStyle(color: _foreground, fontSize: _fontSize, height: _lineHeight)),
                      ),
                    ),
                  ),
                ),
                if (_showControls) _buildNavigation(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavigation() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
      child: Row(
        children: [
          Expanded(child: OutlinedButton.icon(onPressed: widget.previousUrl == null ? null : () => _openChapter(widget.previousUrl!), icon: const Icon(Icons.chevron_right), label: const Text('السابق'))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(onPressed: widget.nextUrl == null ? null : () => _openChapter(widget.nextUrl!), icon: const Icon(Icons.chevron_left), label: const Text('التالي'))),
        ],
      ),
    );
  }

  void _openChapter(String url) {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => NovelReaderScreen(url: url, title: widget.title, chapterNumber: widget.chapterNumber, totalChapters: widget.totalChapters)));
  }

  Future<void> _showResumeDialog() async {
    final resume = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('استكمال القراءة؟'),
        content: const Text('تم العثور على موضع قراءة محفوظ لهذا الفصل.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('من البداية')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('استكمال')),
        ],
      ),
    );
    if (!mounted || resume != true || !_scrollController.hasClients) return;
    _scrollController.jumpTo(_savedOffset.clamp(0, _scrollController.position.maxScrollExtent).toDouble());
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _background,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(left: 18, right: 18, top: 18, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('إعدادات القراءة', style: TextStyle(color: _foreground, fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Row(children: [Text('حجم الخط', style: TextStyle(color: _foreground)), Expanded(child: Slider(value: _fontSize, min: 14, max: 30, divisions: 16, onChanged: (value) { setSheetState(() => _fontSize = value); setState(() {}); }))]),
              Row(children: [Text('تباعد الأسطر', style: TextStyle(color: _foreground)), Expanded(child: Slider(value: _lineHeight, min: 1.4, max: 2.6, divisions: 12, onChanged: (value) { setSheetState(() => _lineHeight = value); setState(() {}); }))]),
              Wrap(
                spacing: 8,
                children: ['dark', 'sepia', 'light'].map((value) => ChoiceChip(label: Text(value == 'dark' ? 'داكن' : value == 'sepia' ? 'دافئ' : 'فاتح'), selected: _theme == value, onSelected: (_) { setSheetState(() => _theme = value); setState(() {}); })).toList(),
              ),
              SwitchListTile(value: _autoScroll, onChanged: (_) { _toggleAutoScroll(); setSheetState(() {}); }, title: Text('التمرير التلقائي', style: TextStyle(color: _foreground))),
              const SizedBox(height: 8),
              FilledButton(onPressed: () { _savePreferences(); Navigator.pop(context); }, child: const Text('حفظ')),
            ],
          ),
        ),
      ),
    );
  }
}
