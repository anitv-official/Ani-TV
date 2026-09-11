import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';
import '../theme/app_theme.dart';
import '../providers/app_state_provider.dart';
import 'manga_reader_screen.dart';
import '../utils/toast_utils.dart';
import '../widgets/custom_loading_widget.dart';

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

  Future<void> _downloadChapter(Map<String, dynamic> chapter) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('جارٍ تنزيل الفصل...')));
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
      messenger.showSnackBar(SnackBar(content: Text('تم حفظ الفصل داخل: $folder')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('تعذر تنزيل الفصل: $e')));
    }
  }

  Future<void> _shareComic() async {
    final title = _comicData?['title'] ?? 'مانجا';
    await Share.share('$title\n${widget.url}', subject: title.toString());
  }

  Future<void> _copyComicLink() async {
    await Clipboard.setData(ClipboardData(text: widget.url));
    if (mounted) ToastUtils.show('تم نسخ رابط المانجا', backgroundColor: AppTheme.accentColor);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(child: CustomLoadingWidget(message: 'جارٍ تحميل تفاصيل المانجا...', size: 100))
          : _error != null
              ? const Center(child: Text('تعذر تحميل التفاصيل. حاول مرة أخرى.', style: TextStyle(color: Colors.white)))
              : _comicData == null
                  ? const Center(child: Text('لا توجد بيانات', style: TextStyle(color: Colors.white)))
                  : SafeArea(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(context, _comicData!),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildInfo(context, _comicData!),
                                  const SizedBox(height: 16),
                                  _buildActionButtons(context, _comicData!),
                                  const SizedBox(height: 24),
                                  _buildChaptersList(context, _comicData!),
                                  const SizedBox(height: 32),
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
             double aspectRatio = 16 / 9;
            if (constraints.maxWidth > 800) {
              aspectRatio = 21 / 9; 
            }
            return AspectRatio(
              aspectRatio: aspectRatio,
              child: Image.network(
                comic['image_url'] ?? '',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.grey[900]),
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
          top: 16,
          start: 16,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.language, size: 15, color: AppTheme.primaryColor),
          const SizedBox(width: 5),
          Text('المصدر: ${comic['source'] ?? 'AniTV'}', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        ]),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              comic['year'] ?? '2022', // Assuming year data or placeholder
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '16+', // Hardcoded rating
                style: TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${chapters.length} فصل',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
             const SizedBox(width: 8),
             const Icon(Icons.star, size: 14, color: Colors.amber),
             const SizedBox(width: 4),
             Text(
               comic['rating']?.toString() ?? 'N/A',
               style: TextStyle(color: Colors.grey[400], fontSize: 13),
             ),
          ],
        ),
        const SizedBox(height: 12),
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
              child: ElevatedButton.icon(
                onPressed: () {
                   // Read first chapter (which is typically the last in the list for manga sites, or first if reversed)
                   // The API usually returns latest first. So we might want the last index.
                   // But logic depends on source. Let's assume we want the "First Chapter" which might appear last in list.
                   final chapters = comic['chapters'] as List<dynamic>? ?? [];
                   if (chapters.isNotEmpty) {
                      final firstChapter = chapters.last; // Assuming list is descending
                 (() {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MangaReaderScreen(
                              url: firstChapter['url'],
                              comicImageUrl: comic['image_url'],
                              title: firstChapter['title'],
                              chapterId: '1', // Simplified
                            ),
                          ),
                        );
                      });
                   }
                },
                icon: const Icon(Icons.menu_book, color: Colors.white),
                label: const Text('اقرأ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF393053),
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF6F4FA4)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  final chapters = comic['chapters'] as List<dynamic>? ?? [];
                  if (chapters.isNotEmpty) {
                    _downloadChapter(Map<String, dynamic>.from(chapters.last as Map));
                  } else {
                    ToastUtils.show('لا توجد فصول متاحة للتنزيل', backgroundColor: AppTheme.primaryColor);
                  }
                },
                icon: const Icon(Icons.download, color: Colors.white),
                label: const Text('تنزيل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                   padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
             _FavoriteIconAction(comic: comic, url: widget.url),
             _buildIconAction(Icons.share, 'مشاركة', _shareComic),
             _buildIconAction(Icons.link, 'نسخ الرابط', _copyComicLink),
          ],
        ),
      ],
    );
  }
  
  Widget _buildIconAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 10)),
        ],
      ),
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
                    hintText: 'Search chapter...',
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
                      'Chapters',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
            ],
          ),
        const SizedBox(height: 16),
        if (filteredChapters.isEmpty)
           Padding(
             padding: const EdgeInsets.all(16.0),
             child: Text('No chapters found', style: TextStyle(color: Colors.grey[500])),
           )
        else
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredChapters.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final chapter = filteredChapters[index];
            final originalIndex = chapters.indexOf(chapter);
            
            // Try to extract chapter number from title
            String title = chapter['title'] ?? 'Chapter ?';
            String displayTitle = title;
            
            return GestureDetector(
              onTap: () {
                 (() {
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
                 })();
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail (using comic image as fallback)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      comic['image_url'] ?? '',
                      width: 120,
                      height: 68,
                      fit: BoxFit.cover,
                      errorBuilder: (_,__,___) => Container(width: 120, height: 68, color: Colors.grey[800]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          displayTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // You could add release date here if available
                        Text(
                           chapter['update_time'] ?? chapter['date'] ?? '',
                           style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'تنزيل الفصل',
                    icon: Icon(Icons.download_for_offline_outlined, color: Colors.grey[400], size: 20),
                    onPressed: () => _downloadChapter(Map<String, dynamic>.from(chapter as Map)),
                  ),
                ],
              ),
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
    
    return GestureDetector(
      onTap: () async {
         try {
                 final provider = Provider.of<AppStateProvider>(context, listen: false);
                 await provider.initialize();
                 if (isFavorited) {
               final items = provider.favoriteComics.where((x) => x['url'] == widget.url).toList();
               if(items.isNotEmpty) {
                 await provider.removeFromFavorites(items.first['id'], false);
                 ToastUtils.show('Removed from My List', backgroundColor: Colors.red);
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
               ToastUtils.show('Added to My List', backgroundColor: Colors.green);
            }
            // Force rebuild is handled by Provider listener usually, but here we depend on parent rebuild or local state
            // Ideally rely on consumer/provider updates. The parent build method fetches `isFavorited` from provider.
         } catch (e) {
            ToastUtils.show('Error: $e', backgroundColor: Colors.red);
         }
      },
      child: Column(
        children: [
          Icon(isFavorited ? Icons.favorite : Icons.favorite_border, color: isFavorited ? Colors.redAccent : Colors.white, size: 24),
          const SizedBox(height: 4),
          Text('المفضلة', style: TextStyle(color: Colors.grey[400], fontSize: 10)),
        ],
      ),
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
                _isExpanded ? 'Show Less' : 'Show More',
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
          const Text('Alternative Titles:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
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
          const Text('Genres:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
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
        _buildInfoRow('Author', widget.comic['author']),
        _buildInfoRow('Illustrator', widget.comic['illustrator']),
        _buildInfoRow('Demographic', widget.comic['demographic']),
        _buildInfoRow('Type', widget.comic['type']),
        _buildInfoRow('Status', widget.comic['status']),
        _buildInfoRow('Last Updated', widget.comic['last_updated']),
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
