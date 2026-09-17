import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_error_dialog.dart';
import '../providers/app_state_provider.dart';
import 'anime_details_screen.dart';
import 'comic_details_screen.dart';
import 'manga_reader_screen.dart';
import 'video_player_screen.dart';
import '../utils/toast_utils.dart';
import '../widgets/custom_loading_widget.dart';
import '../widgets/ui/app_search_bar.dart';
import '../widgets/ui/content_card.dart';
import '../widgets/ui/content_grid.dart';
import '../widgets/ui/poster_image.dart';
import '../widgets/ui/segmented_toggle.dart';
import '../widgets/ui/state_views.dart';

class SearchScreen extends StatefulWidget {
  final bool autoFocus;
  const SearchScreen({Key? key, this.autoFocus = false}) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  List<dynamic> _genres = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  bool _isLoadingGenres = false;

  // Search Filters
  String _selectedFilter = 'All';
  int _selectedYear = DateTime.now().year;
  String _selectedGenre = 'All';
  String _selectedChip = ''; // For generic chips in search

  // Redesign States
  bool _isSearching = false;
  bool _showAnimeHistory = true; // Toggle between anime and manga history
  Timer? _debounce;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // Initialize search state
    _isSearching = widget.autoFocus;

    // Initialize AppStateProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppStateProvider>(context, listen: false).initialize();

      // Auto-focus if requested
      if (widget.autoFocus) {
        FocusScope.of(context).requestFocus(_searchFocusNode);
      }
    });

    _loadGenres();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        setState(() {
          _searchResults = [];
          _hasSearched = false;
        });
      }
    });
  }

  void _loadGenres() async {
    setState(() {
      _isLoadingGenres = true;
    });

    try {
      final genres = await ApiService.fetchGenres();
      if (mounted) {
        setState(() {
          _genres = genres;
          _isLoadingGenres = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingGenres = false);
        print('Error loading genres: $e');
      }
    }
  }

  void _performGenreSearch(Map<String, dynamic> genre) async {
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _isSearching = true; // Switch to search view
    });

    try {
      List<dynamic> allResults = [];

      if (genre['url'] != null) {
        final genreContent = await ApiService.fetchGenreContent(genre['url']);
        if (genreContent['content'] != null) {
          allResults = genreContent['content'].map((item) {
            String category = 'anime';
            if (item['type'] != null) {
              final originalType = item['type'].toString().toLowerCase();
              if (originalType == 'comic' || originalType == 'manga' || originalType == 'manhwa' || originalType == 'manhua') {
                category = 'comic';
              }
            }
            return {...item, 'category': category, 'type': item['type'] ?? category};
          }).toList();
        }
      }

      if (mounted) {
        setState(() {
          List<dynamic> filteredResults = allResults;

          if (_selectedFilter == 'أنمي') {
            filteredResults = filteredResults
                .where((item) => item['category'] == 'anime' || item['type'] == 'anime')
                .toList();
          } else if (_selectedFilter == 'Manga') {
            filteredResults = filteredResults
                .where((item) => item['category'] == 'comic' || item['type'] == 'comic' || item['type'] == 'manga')
                .toList();
          }

          _searchResults = filteredResults;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorDialog('Search Error', 'Failed to perform search: $e');
      }
    }
  }

  void _performSearch(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final animeResults = await ApiService.searchAnime(query);
      final comicResults = await ApiService.searchComics(query);

      final allResults = [...animeResults, ...comicResults];

      if (mounted) {
        setState(() {
          List<dynamic> filteredResults = allResults;

          if (_selectedFilter == 'أنمي') {
            filteredResults = filteredResults
                .where((item) => item['category'] == 'anime' || item['type'] == 'anime')
                .toList();
          } else if (_selectedFilter == 'Manga') {
            filteredResults = filteredResults
                .where((item) => item['category'] == 'comic' || item['type'] == 'comic')
                .toList();
          }

          _searchResults = filteredResults;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorDialog('Search Error', 'Failed to perform search: $e');
      }
    }
  }

  void _showInfoDialog(String title, String message) {
    showDialog<void>(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppTheme.cardColor,
      title: Text(title, style: const TextStyle(color: Colors.white)),
      content: Text(message, style: const TextStyle(color: Colors.white70)),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسنًا'))],
    ));
  }

  void _showErrorDialog(String title, String message) {
    CustomErrorDialog.show(
      context,
      title: title,
      message: message,
      onRetry: () {
        if (_searchController.text.isNotEmpty) {
          _performSearch(_searchController.text);
        }
      },
    );
  }

  void _toggleSearchMode() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchResults = [];
        _hasSearched = false;
        _selectedChip = '';
        FocusScope.of(context).unfocus();
      } else {
        // Automatically focus search field when opened
        Future.delayed(Duration(milliseconds: 100), () {
            FocusScope.of(context).requestFocus(_searchFocusNode);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: _buildAppBar(),
      body: _isSearching
          ? Column(
              children: [
                _buildSearchSuggestions(),
                Expanded(
                  child: _isLoading
                      ? _buildLoadingView()
                      : _hasSearched && _searchResults.isEmpty
                          ? _buildNoResultsView()
                          : _hasSearched
                              ? _buildSearchResultsGrid()
                              : _buildInitialSearchView(), // Or simple "Type to search..."
                ),
              ],
            )
          : _buildHistoryView(),
    );
  }

  AppBar _buildAppBar() {
    if (_isSearching) {
      return AppBar(
        backgroundColor: AppTheme.backgroundColor,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsetsDirectional.only(end: 12),
          child: _buildSearchField(),
        ),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _toggleSearchMode,
        ),
      );
    }

    return AppBar(
      backgroundColor: AppTheme.backgroundColor,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('السجل', style: TextStyle(fontWeight: FontWeight.w800)),
          Text('تابع ما بدأت به', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'بحث',
          icon: const Icon(Icons.search_rounded, color: Colors.white),
          onPressed: () {
            if (!_isSearching) {
              setState(() => _isSearching = true);
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) FocusScope.of(context).requestFocus(_searchFocusNode);
              });
            }
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildHistoryView() {
    final appState = Provider.of<AppStateProvider>(context);
    final historyList = _showAnimeHistory ? appState.animeHistory : appState.comicHistory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _buildHistoryToggle(),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            _showAnimeHistory ? 'آخر ما تمت مشاهدته' : 'آخر ما تمت قراءته',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: historyList.isEmpty
              ? _buildEmptyHistoryView()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: historyList.length,
                  itemBuilder: (context, index) {
                    final item = historyList[index];
                    return _buildHistoryCard(item);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHistoryToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SegmentedToggle(
        labels: const ['أنمي', 'مانجا'],
        index: _showAnimeHistory ? 0 : 1,
        onChanged: (i) => setState(() => _showAnimeHistory = i == 0),
      ),
    );
  }

  Widget _buildHistoryCard(dynamic item) {
    // Determine target screen and type label
    Widget? targetScreen;
    String typeLabel = 'Unknown';
    if (item['type'] == 'anime') {
      typeLabel = 'أنمي';
      if (item['episode'] != null) {
        // For episodes, we redirect to AnimeDetailsScreen for now
        targetScreen = AnimeDetailsScreen(url: item['url']);
        final ep = item['episode'].toString();
        final match = RegExp(r'episode\s*(\d+)', caseSensitive: false).firstMatch(ep);
        if (match != null) {
           typeLabel = 'Episode ${match.group(1)}';
        } else {
           typeLabel = ep.toLowerCase().contains('episode') ? ep : 'Episode $ep';
        }
      } else {
        targetScreen = AnimeDetailsScreen(url: item['url']);
      }
    } else if (item['type'] == 'comic' || item['type'] == 'manga') {
      typeLabel = 'Manga';
      // Check if it's a specific chapter history (has 'chapter' key) or just a comic link
      if (item['chapter'] != null) {
        targetScreen = MangaReaderScreen(
          url: item['url'],
          title: item['title'],
          chapterId: item['chapter'].toString(),
          comicImageUrl: item['image_url'] ?? item['image'],
        );
        final ch = item['chapter'].toString();
        // Normalize: Remove existing 'chapter' text (case-insensitive) and force 'Chapter X' format
        final cleanCh = ch.replaceAll(RegExp(r'chapter\s*', caseSensitive: false), '').trim();
        typeLabel = 'Chapter $cleanCh';
      } else {
        targetScreen = ComicDetailsScreen(url: item['url'], type: item['type']);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      height: 84,
      decoration: BoxDecoration(
        gradient: AppTheme.glassGradient,
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: InkWell(
        onTap: () {
          if (item['type'] == 'anime') {
             if (item['episode_url'] != null) {
                // Feature: Direct play if URL exists (New history items)
                _showStreamBottomSheet(item);
             } else if (item['episode'] != null) {
                // Feature: Fallback for legacy items (Try to find episode by name)
                _fetchAndDirectPlay(item);
             } else if (targetScreen != null) {
                 Navigator.push(
                   context,
                   MaterialPageRoute(builder: (context) => targetScreen!),
                 );
             }
          } else if (targetScreen != null) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => targetScreen!),
              );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            // Image
            PosterImage(
              url: (item['image_url'] ?? item['image'])?.toString(),
              width: 62,
              height: 84,
              borderRadius: BorderRadius.circular(12),
            ),

            SizedBox(width: 12),

            // Title & Subtitle Logic
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9.0),
                child: (() {
                  // Calculate Cleaned Title (Series Name)
                  final originalTitle = (item['title'] ?? 'Unknown Title').toString();
                  // Remove "Chapter X" or "Episode X" from start or end
                  // Example: "Chapter 1 Job Change Log" -> "Job Change Log"
                  // Example: "Job Change Log Chapter 1" -> "Job Change Log"
                  String cleanedTitle = originalTitle.replaceAll(RegExp(r'^(Episode|Chapter)\s*\d+\s*[-:]*\s*', caseSensitive: false), '');
                  cleanedTitle = cleanedTitle.replaceAll(RegExp(r'\s*[-:]*\s*(Episode|Chapter)\s*\d+.*$', caseSensitive: false), '').trim();

                  final seriesTitle = cleanedTitle.isNotEmpty ? cleanedTitle : originalTitle;

                  // Determined Display Strings
                  String mainText = seriesTitle;
                  String subText = typeLabel;

                  // Swap for Comics: Chapter on Top, Series on Bottom
                  if (item['type'] == 'comic' || item['type'] == 'manga') {
                    mainText = typeLabel;
                    subText = seriesTitle;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        mainText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        subText,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  );
                })(),
              ),
            ),

            // Play Button Icon
            Container(
              margin: const EdgeInsetsDirectional.only(end: 12),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(.16),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryColor.withOpacity(.45)),
              ),
              child: Icon(
                item['type'] == 'anime' || item['type'] == 'drama' ? Icons.play_arrow_rounded : Icons.menu_book_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHistoryView() {
    return EmptyState(
      icon: Icons.history_rounded,
      title: 'لا يوجد سجل بعد',
      message: _showAnimeHistory ? 'ستظهر هنا الأنميات التي شاهدتها.' : 'ستظهر هنا المانجا التي قرأتها.',
    );
  }

  // --- EXISTING SEARCH WIDGETS (Slightly modified) ---

  Widget _buildSearchField() {
    return AppSearchBar(
      controller: _searchController,
      focusNode: _searchFocusNode,
      hintText: 'ابحث عن أنمي أو مانجا...',
      onSubmitted: (query) {
        setState(() => _selectedChip = '');
        _performSearch(query);
      },
      onChanged: _onSearchChanged,
      onClear: () {
        _searchController.clear();
        setState(() {
          _searchResults = [];
          _hasSearched = false;
        });
      },
    );
  }

  Widget _buildSearchSuggestions() {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      margin: const EdgeInsets.only(bottom: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ..._genres.take(6).map((genre) => Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ActionChip(
                  label: Text(genre['name']?.toString() ?? ''),
                  backgroundColor: AppTheme.elevatedColor,
                  labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  side: const BorderSide(color: AppTheme.borderColor),
                  onPressed: () {
                    setState(() => _selectedChip = genre['name']?.toString() ?? '');
                    _performGenreSearch(genre);
                  },
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return const LoadingView(message: 'جارٍ البحث...', size: 72);
  }

  Widget _buildNoResultsView() {
    return const EmptyState(
      icon: Icons.search_off_rounded,
      title: 'لم يتم العثور على نتائج',
      message: 'جرّب كلمات بحث مختلفة أو تصنيفاً آخر.',
    );
  }

  Widget _buildInitialSearchView() {
    return Column(
      children: [
        const SizedBox(height: 36),
        const Icon(Icons.search_rounded, size: 48, color: AppTheme.textMutedColor),
        const SizedBox(height: 12),
        const Text('اكتب للبحث عن أنمي أو مانجا', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPopularSearches() {
      // Reuse logic from previous implementation but simplified
      if (_isLoadingGenres) return SizedBox();

      return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: _genres.take(6).map((genre) {
                 return ActionChip(
                   label: Text(genre['name']),
                   backgroundColor: AppTheme.elevatedColor,
                   labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                   onPressed: () {
                        setState(() {
                            _selectedChip = genre['name'];
                        });
                        _performGenreSearch(genre);
                   },
                 );
            }).toList(),
          ),
      );
  }

  Widget _buildSearchResultsGrid() {
    return ContentGrid(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        return _buildResultCard(item);
      },
    );
  }

  Widget _buildResultCard(dynamic item) {
    // Basic Grid Card for search results
     Widget? targetScreen;
    String category = item['category'] ?? 'anime'; // Default to anime if unknown

    // Fallback logic if category is missing but type exists
    if (item['category'] == null) {
       String t = (item['type'] ?? '').toString().toLowerCase();
       if (t == 'comic' || t == 'manga' || t == 'manhwa' || t == 'manhua') category = 'comic';
    }

    if (category == 'anime' || category == 'drama') {
      targetScreen = AnimeDetailsScreen(url: item['url']);
    } else if (category == 'comic') {
      targetScreen = ComicDetailsScreen(url: item['url'], type: item['type']);
    }

    return ContentCard(
      title: item['title']?.toString(),
      imageUrl: (item['image_url'] ?? item['image'])?.toString(),
      badge: item['type']?.toString() ?? category,
      onTap: () {
        if (targetScreen != null) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => targetScreen!));
        }
      },
    );
  }
  /* Direct Play Logic copied/adapted from AnimeDetailsScreen */
  Future<void> _showStreamBottomSheet(Map<String, dynamic> historyItem) async {
     // Show loading
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const Center(
        heightFactor: 1,
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CustomLoadingWidget(message: 'جارٍ تحميل المصادر...', size: 80),
        ),
      ),
    );

    try {

      final episodeUrl = historyItem['episode_url'];
      final streams = await ApiService.fetchEpisodeStreams(episodeUrl);
      if (mounted) Navigator.pop(context); // Close loading

      if (streams == null) {
        ToastUtils.show('لا توجد مصادر تشغيل', backgroundColor: Colors.orange);
        return;
      }

      final List<dynamic> directStreams = streams['direct_stream_urls'] ?? [];
      final String streamUrl = streams['stream_url'] ?? '';

      if (mounted) {
        showModalBottomSheet(
          context: context,
          backgroundColor: AppTheme.surfaceColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   const Text(
                     'اختر الجودة',
                     style: TextStyle(
                       color: Colors.white,
                       fontSize: 18,
                       fontWeight: FontWeight.w800,
                     ),
                   ),
                   const SizedBox(height: 16),
                   Flexible(
                     child: ListView(
                       shrinkWrap: true,
                       children: [
                         // Auto Option
                         if (streamUrl.isNotEmpty)
                           ListTile(
                             leading: const Icon(Icons.auto_awesome, color: AppTheme.primaryColor),
                              title: const Text('تلقائي (موصى به)', style: TextStyle(color: Colors.white)),
                              subtitle: const Text('جودة متكيفة', style: TextStyle(color: Colors.grey)),
                             onTap: () => _playVideo(context, streamUrl, 'Auto', streams, historyItem),
                           ),

                          ...directStreams.map((stream) {
                             final quality = stream['quality'] ?? 'Unknown';
                             return ListTile(
                               leading: const Icon(Icons.hd, color: AppTheme.primaryColor),
                               title: Text(quality, style: const TextStyle(color: Colors.white)),
                               onTap: () => _playVideo(context, stream['url'], quality, streams, historyItem),
                             );
                          }),
                        ],
                      ),
                    ),
                 ],
               ),
             );
          },
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading
      ToastUtils.show('تعذر تحميل مصادر التشغيل', backgroundColor: Color(0xFF1976D2));
    }
  }

  void _playVideo(BuildContext context, String url, String quality, Map<String, dynamic> episodeData, Map<String, dynamic> historyItem, {bool popSheet = true}) {
     if (popSheet && context.mounted && Navigator.of(context).canPop()) {
       Navigator.pop(context);
     }
     (() {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(
              url: url,
              title: historyItem['episode'] ?? 'Episode',
              episodeId: DateTime.now().millisecondsSinceEpoch.toString(), // Dummy ID for history
              directStreamUrls: (episodeData['direct_stream_urls'] as List?)
                  ?.map((e) => Map<String, String>.from(e))
                  .toList() ?? [],
              headers: (episodeData['headers'] as Map?)
                  ?.map((key, value) => MapEntry(key.toString(), value.toString())) ?? {},
            ),
          ),
        );
     })();
  }

  Future<void> _fetchAndDirectPlay(Map<String, dynamic> item) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
          child: CustomLoadingWidget(message: 'جارٍ البحث عن الحلقة...', size: 100),
      ),
    );

    try {
      final animeDetails = await ApiService.fetchAnimeDetails(item['url']);
      Navigator.pop(context); // Close loading

      if (animeDetails != null && animeDetails['episodes'] != null) {
         final episodes = animeDetails['episodes'] as List<dynamic>;
         final targetEpisode = item['episode'].toString(); // "Episode 1"

         // Try to find matching episode with flexible matching
         final episode = episodes.firstWhere(
            (e) => _isSameEpisode(e['title'], targetEpisode),
            orElse: () => null,
         );

         if (episode != null) {
            // Found it! Construct updated history item and show sheet
            final updatedItem = Map<String, dynamic>.from(item);
            updatedItem['episode_url'] = episode['url'];
            _showStreamBottomSheet(updatedItem);
         } else {
            // Not found, try matching by index as fallback if targetEpisode contains a number
            // ... (Simple navigation for now to avoid wrong episode)
            if (mounted) {
               Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AnimeDetailsScreen(url: item['url'])),
               );
            }
         }
      }
    } catch (e) {
      Navigator.pop(context); // Ensure loading is closed
      ToastUtils.show('تعذر تحميل تفاصيل الحلقة', backgroundColor: Color(0xFF1976D2));
      // Fallback
      if (mounted) {
         Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AnimeDetailsScreen(url: item['url'])),
         );
      }
    }
  }

  bool _isSameEpisode(dynamic apiTitle, dynamic searchTitle) {
      if (apiTitle == null || searchTitle == null) return false;
      final t1 = apiTitle.toString().toLowerCase().trim();
      final t2 = searchTitle.toString().toLowerCase().trim();

      // Exact match
      if (t1 == t2) return true;

      // Check if one contains the other
      if (t1.contains(t2) || t2.contains(t1)) return true;

      // Check numeric match (e.g. "Episode 1" vs "1")
      final n1 = RegExp(r'(\d+)').firstMatch(t1)?.group(1);
      final n2 = RegExp(r'(\d+)').firstMatch(t2)?.group(1);

      if (n1 != null && n2 != null && n1 == n2) return true;

      return false;
  }
}
