import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';
import '../services/content_link_service.dart';
import '../theme/app_theme.dart';
import '../providers/app_state_provider.dart';
import 'manga_reader_screen.dart';
import '../utils/toast_utils.dart';
import '../widgets/ui/episode_tile.dart';
import '../widgets/ui/favorite_button.dart';
import '../widgets/ui/poster_image.dart';
import '../widgets/ui/primary_button.dart';
import '../widgets/ui/source_badge.dart';
import '../widgets/ui/state_views.dart';

class ComicDetailsScreen extends StatefulWidget {
  final String url;
  final String? type; // Add type parameter to receive data from list screens

  const ComicDetailsScreen({required this.url, this.type});

  @override
  State<ComicDetailsScreen> createState() => _ComicDetailsScreenState();
}

class _ComicDetailsScreenState extends State<ComicDetailsScreen> {
  String _searchQuery = '';
  Map<String, dynamic>? _comicData;
  bool _isLoading = true;
  String? _error;
  
  bool _isChapterSearching = false;
  bool _chaptersAscending = false;
  bool _isDownloadingAll = false;
  final TextEditingController _chapterSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadComicData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Provider.of<AppStateProvider>(context, listen: false).initialize();
    });
  }
  
  @override
  void dispose() {
    _chapterSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadComicData() async {
    if (mounted && !_isLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final data = await ApiService.fetchComicDetails(widget.url);
      
      // Inject passed type if available and API type is generic or missing
      if (widget.type != null) {
         String apiType = (data['type'] ?? '').toString().toLowerCase();
         if (apiType.isEmpty || apiType == 'comic') {
            data['type'] = widget.type;
         }
      }
      
      // Smart Detection: fallback to checking Genres if type is still generic
      String currentType = (data['type'] ?? '').toString().toLowerCase().trim();
      
      // If type is generic or empty, try to detect from genres or existing type string
      if (currentType.isEmpty || currentType == 'comic') {
         final genres = data['genres'] as List<dynamic>? ?? [];
         bool found = false;
         
         for (var g in genres) {
            final genre = g.toString().toLowerCase();
            if (genre.contains('manhwa') || genre.contains('korea')) {
               data['type'] = 'Manhwa';
               found = true;
               break;
            } else if (genre.contains('manhua') || genre.contains('china')) {
               data['type'] = 'Manhua';
               found = true;
               break;
            } else if (genre.contains('manga') || genre.contains('japan')) {
               data['type'] = 'Manga';
               found = true;
               break;
            }
         }
         
         // If still not found, check if "Webtoon" is in genres
         if (!found) {
             for (var g in genres) {
                if (g.toString().toLowerCase().contains('webtoon')) {
                   data['type'] = 'Manhwa';
                   found = true;
                   break;
                }
             }
         }
         
         // If still not found, check URL (Strong indicator)
         if (!found) {
            final url = widget.url.toLowerCase();
            if (url.contains('manhwa')) {
               data['type'] = 'Manhwa';
               found = true;
            } else if (url.contains('manhua')) {
               data['type'] = 'Manhua';
               found = true;
            } else if (url.contains('manga')) {
               data['type'] = 'Manga';
               found = true;
            }
         }
         
         // If still not found, check Title
         if (!found && data['title'] != null) {
            final title = data['title'].toString().toLowerCase();
            if (title.contains('manhwa')) {
               data['type'] = 'Manhwa';
               found = true;
            } else if (title.contains('manhua')) {
               data['type'] = 'Manhua';
               found = true;
            } else if (title.contains('manga')) {
               data['type'] = 'Manga';
               found = true;
            }
         }
      } else {
         // If type is present but maybe lowercase or unformatted, capitalize properly
         if (currentType.contains('manhwa')) data['type'] = 'Manhwa';
         else if (currentType.contains('manhua')) data['type'] = 'Manhua';
         else if (currentType.contains('manga')) data['type'] = 'Manga';
      }

      setState(() {
        _comicData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<bool> _downloadChapter(Map<String, dynamic> chapter) async {
    if (!context.read<AppStateProvider>().isLoggedIn) {
      ToastUtils.show('سجّل الدخول لاستخدام التنزيلات', backgroundColor: Colors.orange);
      return false;
    }
    ToastUtils.show('جارٍ تنزيل الفصل...', backgroundColor: Colors.green);
    try {
      final data = await ApiService.fetchChapterImages(chapter['url'].toString());
      final images = (data['images'] as List?)?.whereType<Map>().toList() ?? [];
      if (images.isEmpty) throw Exception('لا توجد صور للفصل');
      final folder = await DownloadService.saveMangaChapter(
        mangaTitle: _comicData?['title']?.toString() ?? 'مانجا',
        chapterTitle: chapter['title']?.toString() ?? 'فصل',
        imageUrls: images.map((image) => image['url']?.toString() ?? '').where((url) => url.isNotEmpty).toList(),
        coverUrl: _comicData?['image_url']?.toString() ?? '',
        sourceId: _comicData?['source_id']?.toString() ?? '',
      );
      ToastUtils.show('تم حفظ الفصل داخل: $folder', backgroundColor: Colors.green);
      return true;
    } catch (e) {
      ToastUtils.show('تعذر تنزيل الفصل: $e', backgroundColor: Color(0xFF1976D2));
      return false;
    }
  }

  Future<void> _downloadAllChapters() async {
    if (_isDownloadingAll) return;
    if (!context.read<AppStateProvider>().isLoggedIn) {
      ToastUtils.show('سجّل الدخول لاستخدام التنزيلات', backgroundColor: Colors.orange);
      return;
    }
    final chapters = ((_comicData?['chapters'] as List?) ?? const [])
        .whereType<Map>()
        .map((chapter) => Map<String, dynamic>.from(chapter))
        .where((chapter) => (chapter['url']?.toString() ?? '').trim().isNotEmpty)
        .toList();
    if (chapters.isEmpty) {
      ToastUtils.show('لا توجد فصول متاحة للتنزيل', backgroundColor: AppTheme.primaryColor);
      return;
    }
    setState(() => _isDownloadingAll = true);
    var completed = 0;
    var failed = 0;
    final seen = <String>{};
    for (final chapter in chapters) {
      final url = chapter['url'].toString();
      if (!seen.add(url)) continue;
      try {
        final mangaTitle = _comicData?['title']?.toString() ?? 'مانجا';
        final chapterTitle = chapter['title']?.toString() ?? 'فصل';
        if (await DownloadService.hasMangaChapter(mangaTitle: mangaTitle, chapterTitle: chapterTitle)) {
          completed++;
          continue;
        }
        final data = await ApiService.fetchChapterImages(url);
        final images = (data['images'] as List?)
                ?.whereType<Map>()
                .map((image) => image['url']?.toString() ?? '')
                .where((imageUrl) => imageUrl.isNotEmpty)
                .toList() ??
            const <String>[];
        if (images.isEmpty) throw Exception('لا توجد صفحات');
        await DownloadService.saveMangaChapter(
          mangaTitle: mangaTitle,
          chapterTitle: chapterTitle,
          imageUrls: images,
          coverUrl: _comicData?['image_url']?.toString() ?? '',
          sourceId: _comicData?['source_id']?.toString() ?? '',
        );
        completed++;
      } on DownloadCancelledException {
        break;
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    setState(() => _isDownloadingAll = false);
    ToastUtils.show(
      failed == 0 ? 'تم تنزيل $completed فصل' : 'تم تنزيل $completed فصل وتعذر تنزيل $failed فصل',
      backgroundColor: failed == 0 ? AppTheme.accentColor : Colors.orange,
    );
  }

  Future<void> _shareComic() async {
    final title = _comicData?['title'] ?? 'مانجا';
    await ContentLinkService.share(type: 'manga', title: title.toString(), sourceUrl: widget.url);
  }

  Future<void> _copyComicLink() async {
    await Clipboard.setData(ClipboardData(text: widget.url));
    if (mounted) ToastUtils.show('تم نسخ رابط المانجا', backgroundColor: AppTheme.accentColor);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _isLoading
          ? const LoadingView(message: 'جارٍ تحميل التفاصيل...', size: 64)
          : _error != null
              ? ErrorState(onRetry: _loadComicData)
              : _comicData == null
                  ? const EmptyState(icon: Icons.menu_book_outlined, title: 'لا توجد بيانات')
                  : SafeArea(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(context, _comicData!),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildInfo(context, _comicData!),
                                  const SizedBox(height: 12),
                                  _buildActionButtons(context, _comicData!),
                                  const SizedBox(height: 18),
                                  _buildChaptersList(context, _comicData!),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildHeader(BuildContext context, Map<String, dynamic> comic) {
    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
             double aspectRatio = 2.15;
            if (constraints.maxWidth > 800) {
              aspectRatio = 2.6;
            }
            return AspectRatio(
              aspectRatio: aspectRatio,
              child: PosterImage(
                url: comic['image_url']?.toString(),
                fit: BoxFit.cover,
                fallbackIcon: Icons.menu_book_outlined,
                borderRadius: BorderRadius.zero,
              ),
            );
          }
        ),
        // Gradient overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.transparent,
                  Colors.black.withOpacity(0.6),
                  Colors.black,
                ],
                stops: const [0.0, 0.3, 0.8, 1.0],
              ),
            ),
          ),
        ),
        // Back Button
        PositionedDirectional(
          top: 8,
          start: 8,
          child: SafeArea(
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              style: IconButton.styleFrom(backgroundColor: Colors.black.withOpacity(.45)),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfo(BuildContext context, Map<String, dynamic> comic) {
    final chapters = comic['chapters'] as List<dynamic>? ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          comic['title'] ?? 'بدون عنوان',
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.25),
        ),
        const SizedBox(height: 8),
        Row(children: [
          SourceBadge(label: comic['source']?.toString() ?? 'AniTV', compact: false),
          const SizedBox(width: 8),
          if ((comic['type'] ?? '').toString().isNotEmpty)
            SourceBadge(label: comic['type']?.toString()),
        ]),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if ((comic['year'] ?? comic['status'] ?? '').toString().trim().isNotEmpty)
              Text(
                (comic['year'] ?? comic['status']).toString(),
                style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
              ),
            Text(
              '${chapters.length} فصل',
              style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
            ),
            if ((comic['rating'] ?? '').toString().trim().isNotEmpty) ...[
              const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
              Text(
                comic['rating'].toString(),
                style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        _ExpandableDetails(comic: comic),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, Map<String, dynamic> comic) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                label: 'اقرأ',
                icon: Icons.menu_book_rounded,
                onPressed: () {
                   final chapters = comic['chapters'] as List<dynamic>? ?? [];
                   if (chapters.isNotEmpty) {
                      final firstChapter = chapters.last;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MangaReaderScreen(
                            url: firstChapter['url'],
                            comicImageUrl: comic['image_url'],
                            title: firstChapter['title'],
                            chapterId: '1',
                          ),
                        ),
                      );
                   }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SecondaryButton(
                label: 'تنزيل',
                icon: Icons.download_rounded,
                onPressed: () {
                  final chapters = comic['chapters'] as List<dynamic>? ?? [];
                  if (chapters.isNotEmpty) {
                    _downloadChapter(Map<String, dynamic>.from(chapters.last as Map));
                  } else {
                    ToastUtils.show('لا توجد فصول متاحة للتنزيل', backgroundColor: AppTheme.primaryColor);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
              _FavoriteIconAction(comic: comic, url: widget.url),
              IconAction(icon: Icons.share_outlined, label: 'مشاركة', onTap: _shareComic),
              IconAction(icon: Icons.link_rounded, label: 'نسخ الرابط', onTap: _copyComicLink),
          ],
        ),
      ],
    );
  }
  
  Widget _buildChaptersList(BuildContext context, Map<String, dynamic> comic) {
    final chapters = comic['chapters'] as List<dynamic>? ?? [];
    
    // Filter chapters
    final filteredChapters = chapters.where((ch) {
      if (_searchQuery.isEmpty) return true;
      final title = ch['title']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return title.contains(query);
    }).toList();

    return Column(
      children: [
        if (_isChapterSearching)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chapterSearchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن فصل...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isChapterSearching = false;
                    _searchQuery = '';
                    _chapterSearchController.clear();
                  });
                },
                child: const Text('إلغاء', style: TextStyle(color: AppTheme.primaryColor)),
              ),
            ],
          )
               else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                Row(
                 children: [
                    const Text(
                      'الفصول',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isChapterSearching = true;
                        });
                      },
                      child: Icon(Icons.search, color: Colors.grey[400], size: 20),
                    ),
                 ],
               ),
               Row(
                 children: [
                   IconButton(
                     tooltip: _chaptersAscending ? 'ترتيب تنازلي' : 'ترتيب تصاعدي',
                     onPressed: () => setState(() => _chaptersAscending = !_chaptersAscending),
                     icon: Icon(_chaptersAscending ? Icons.south_rounded : Icons.north_rounded, color: AppTheme.textSecondaryColor),
                   ),
                   OutlinedButton.icon(
                     onPressed: _isDownloadingAll ? null : _downloadAllChapters,
                     icon: _isDownloadingAll
                         ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                         : const Icon(Icons.download_for_offline_outlined, size: 18),
                     label: Text(_isDownloadingAll ? 'جارٍ...' : 'الكل'),
                   ),
                 ],
               ),
            ],
          ),
        const SizedBox(height: 12),
        if (filteredChapters.isEmpty)
           Padding(
             padding: const EdgeInsets.all(12.0),
             child: const Text('لا توجد فصول', style: TextStyle(color: AppTheme.textSecondaryColor)),
           )
        else
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredChapters.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final orderedChapters = [...filteredChapters]..sort((a, b) {
              final aNumber = double.tryParse((a['number'] ?? a['chapter_number'] ?? '').toString()) ?? 0;
              final bNumber = double.tryParse((b['number'] ?? b['chapter_number'] ?? '').toString()) ?? 0;
              return _chaptersAscending ? aNumber.compareTo(bNumber) : bNumber.compareTo(aNumber);
            });
            final chapter = orderedChapters[index];
            String title = chapter['title'] ?? 'فصل';
            String displayTitle = title;
            
            return ChapterTile(
              title: displayTitle,
              subtitle: (chapter['update_time'] ?? chapter['date'])?.toString(),
              imageUrl: comic['image_url']?.toString(),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MangaReaderScreen(
                      url: chapter['url'],
                      comicImageUrl: comic['image_url'],
                      title: title,
                      chapterId: '$index',
                    ),
                  ),
                );
              },
              onDownload: () => _downloadChapter(Map<String, dynamic>.from(chapter as Map)),
            );
          },
        ),
      ],
    );
  }
}

class _FavoriteIconAction extends StatefulWidget {
  final Map<String, dynamic> comic;
  final String url;
  const _FavoriteIconAction({required this.comic, required this.url});

  @override
  State<_FavoriteIconAction> createState() => _FavoriteIconActionState();
}

class _FavoriteIconActionState extends State<_FavoriteIconAction> {
  @override
  Widget build(BuildContext context) {
    final appStateProvider = Provider.of<AppStateProvider>(context);
    final isFavorited = appStateProvider.favoriteComics.any((item) => item['url'] == widget.url);
    
    return FavoriteButton(
      isFavorite: isFavorited,
      onPressed: () async {
         try {
                 final provider = Provider.of<AppStateProvider>(context, listen: false);
                 await provider.initialize();
                 if (!provider.isLoggedIn) {
                   ToastUtils.show('سجّل الدخول لاستخدام المفضلة', backgroundColor: Colors.orange);
                   return;
                 }
                 if (isFavorited) {
               final items = provider.favoriteComics.where((x) => x['url'] == widget.url).toList();
               if(items.isNotEmpty) {
                 await provider.removeFromFavorites(items.first['id'], false);
                 ToastUtils.show('تمت الإزالة من المفضلة', backgroundColor: AppTheme.primaryColor);
               }
            } else {
               await provider.addToFavorites({
                  'title': widget.comic['title'] ?? 'No Title',
                  'image_url': widget.comic['image_url'] ?? '',
                  'url': widget.url,
                  'rating': widget.comic['rating'],
                  'type': widget.comic['type'],
                  'genres': widget.comic['genres'],
               }, false);
               ToastUtils.show('تمت الإضافة إلى المفضلة', backgroundColor: AppTheme.primaryColor);
            }
         } catch (e) {
            ToastUtils.show('تعذر تحديث المفضلة', backgroundColor: Color(0xFF1976D2));
         }
      },
    );
  }
}

class _ExpandableDetails extends StatefulWidget {
  final Map<String, dynamic> comic;
  const _ExpandableDetails({required this.comic});

  @override
  State<_ExpandableDetails> createState() => _ExpandableDetailsState();
}

class _ExpandableDetailsState extends State<_ExpandableDetails> {
  bool _isExpanded = false;

  @override
  String _cleanSynopsis(String text) {
    if (text.isEmpty) return '';
    // Replace sequences of whitespace (including newlines and tabs) with a single space
    // BUT we want to preserve paragraph breaks if they are genuine.
    // The user input shows: "Manhwa ... bernama\n                    Legobalbasseo"
    // Ideally we want "Manhwa ... bernama Legobalbasseo" if it's not a real paragraph,
    // OR we just want to strip the indentation after the newline.

    // Strategy 1: Remove all newlines and excess spaces, treating it as one block (if that's desired).
    // Strategy 2 (Better for reading): Normalise spacing.
    // 1. Replace multiple spaces with single space.
    // 2. Remove spaces after newlines.
    
    // Let's go with a robust approach:
    // Replace newline chars with a placeholder if they are double, or just space?
    // Often comic synopsis are scraped and have weird formatting. 
    // Let's try to preserve double newlines as paragraphs, but unwanted single newlines inside sentences might need to be joined?
    // Given the user example "bernama\n                    Legobalbasseo", this looks like a line wrap that should be a space.
    // However, "Vikir.\n\nHadiah" looks like a paragraph break.
    
    // 1. Trim the whole text
    var clean = text.trim();
    
    // 2. Replace multiple spaces/tabs with single space (excluding newlines for now)
    clean = clean.replaceAll(RegExp(r'[ \t]+'), ' ');
    
    // 3. Handle newlines. 
    //    If we have \n\n (or more), it's likely a paragraph break.
    //    If we have \n followed by spaces, it might be just bad formatting or a soft break.
    //    Let's normalize all newline sequences to \n first.
    clean = clean.replaceAll(RegExp(r'\s*\n\s*'), '\n');
    
    //    Now we have condensed newlines. "text\ntext" or "text\n\ntext".
    //    We can check if it looks like a list or specific break. 
    //    For safety in a mobile view, often converting single \n to space is safer for flow, 
    //    unless it's a double \n.
    
    //    Let's try: Replace single \n with space, keep double \n.
    //    BUT, we need to temporarily hide double newlines.
    clean = clean.replaceAll('\n\n', '<PARAGRAPH_BREAK>');
    clean = clean.replaceAll('\n', ' '); // Join single lines
    clean = clean.replaceAll('<PARAGRAPH_BREAK>', '\n\n');
    
    return clean.trim();
  }

  @override
  Widget build(BuildContext context) {
    final synopsis = _cleanSynopsis(widget.comic['synopsis'] ?? '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedCrossFade(
          firstChild: Text(
            synopsis,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey[300], fontSize: 13, height: 1.4),
          ),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                synopsis,
                style: TextStyle(color: Colors.grey[300], fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              _buildDetailGrid(),
            ],
          ),
          crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Row(
            children: [
              Text(
                _isExpanded ? 'عرض أقل' : 'عرض المزيد',
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.grey,
                size: 16,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.comic['alternative_titles'] != null && (widget.comic['alternative_titles'] as List).isNotEmpty) ...[
          const Text('عناوين أخرى:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: (widget.comic['alternative_titles'] as List).map((title) {
               return Padding(
                 padding: const EdgeInsets.only(bottom: 2.0),
                 child: Text(
                   '- $title',
                   style: TextStyle(color: Colors.grey[400], fontSize: 12),
                 ),
               );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        if (widget.comic['genres'] != null) ...[
          const Text('التصنيفات:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: (widget.comic['genres'] as List).map((genre) {
               return Container(
                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                 decoration: BoxDecoration(
                   color: Colors.grey[800],
                   borderRadius: BorderRadius.circular(12),
                 ),
                 child: Text(
                   genre.toString(),
                   style: const TextStyle(color: Colors.white, fontSize: 11),
                 ),
               );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        _buildInfoRow('الكاتب', widget.comic['author']),
        _buildInfoRow('الرسام', widget.comic['illustrator']),
        _buildInfoRow('الجمهور', widget.comic['demographic']),
        _buildInfoRow('النوع', widget.comic['type']),
        _buildInfoRow('الحالة', widget.comic['status']),
        _buildInfoRow('آخر تحديث', widget.comic['last_updated']),
      ],
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    if (value == null || value.toString().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 12, height: 1.4),
          children: [
            TextSpan(text: '$label: ', style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold)),
            TextSpan(text: value.toString(), style: const TextStyle(color: Colors.white)),
          ],
        ),
        softWrap: true,
      ),
    );
  }
}
