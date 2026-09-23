import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';
import '../services/content_link_service.dart';
import '../theme/app_theme.dart';
import '../providers/app_state_provider.dart';
import 'video_player_screen.dart';
import '../utils/toast_utils.dart';
import '../widgets/custom_loading_widget.dart';
import '../widgets/ui/episode_tile.dart';
import '../widgets/ui/favorite_button.dart';
import '../widgets/ui/poster_image.dart';
import '../widgets/ui/primary_button.dart';
import '../widgets/ui/source_badge.dart';
import '../widgets/ui/state_views.dart';
import '../widgets/ui/detail_ui.dart';
import '../widgets/ui/universal_content_details.dart';
import '../sources/source_registry.dart';

class AnimeDetailsScreen extends StatefulWidget {
  final String url;
  const AnimeDetailsScreen({super.key, required this.url});

  @override
  State<AnimeDetailsScreen> createState() => _AnimeDetailsScreenState();
}

class _AnimeDetailsScreenState extends State<AnimeDetailsScreen> {
  late Future<dynamic> _animeDetailsFuture;
  bool _isEpisodeSearching = false;
  final TextEditingController _episodeSearchController = TextEditingController();
  String _episodeSearchQuery = '';
  bool _relatedLoaded = false;
  List<Map<String, dynamic>> _relatedItems = [];

  @override
  void initState() {
    super.initState();
    _animeDetailsFuture = ApiService.fetchAnimeDetails(widget.url);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Provider.of<AppStateProvider>(context, listen: false).initialize();
    });
  }

  @override
  void dispose() {
    _episodeSearchController.dispose();
    super.dispose();
  }

  Future<dynamic> _loadDetails() => ApiService.fetchAnimeDetails(widget.url);

  bool _isMovie(Map<String, dynamic> anime) {
    final type = anime['type']?.toString().toLowerCase() ?? '';
    final category = anime['category']?.toString().toLowerCase() ?? '';
    return type.contains('movie') || type.contains('film') || category.contains('movie') || anime['is_movie'] == true;
  }

  Future<void> _loadRelated(Map<String, dynamic> anime) async {
    try {
      final source = SourceRegistry.sourceFor(widget.url);
      final title = anime['title']?.toString().trim() ?? '';
      if (source == null || title.isEmpty) return;
      final items = await source.search(title);
      if (!mounted) return;
      setState(() => _relatedItems = items.where((item) => item['url']?.toString() != widget.url).take(12).toList());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: FutureBuilder(
        future: _animeDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(message: 'جارٍ تحميل التفاصيل...', size: 64);
          } else if (snapshot.hasError) {
            return ErrorState(onRetry: () => setState(() => _animeDetailsFuture = _loadDetails()));
          } else if (!snapshot.hasData) {
            return const EmptyState(icon: Icons.movie_outlined, title: 'لا توجد بيانات');
          }

          final anime = snapshot.data!;
          if (!_relatedLoaded) {
            _relatedLoaded = true;
            _loadRelated(anime);
          }
          final episodes = anime['episodes'] as List<dynamic>? ?? const [];
          final isMovie = _isMovie(anime);
          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, anime),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfo(context, anime),
                        const SizedBox(height: 10),
                        _buildActionButtons(context, anime),
                        if (!isMovie) const SizedBox(height: 14),
                        if (!isMovie)
                          Text('${episodes.length} حلقة متاحة — افتح قائمة الحلقات للاختيار والتنزيل', style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12)),
                        if (_relatedItems.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          RelatedContentRail(items: _relatedItems, onTap: (item) => Navigator.push(context, MaterialPageRoute(builder: (_) => AnimeDetailsScreen(url: item['url'].toString())))),
                        ],
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Map<String, dynamic> anime) {
    return UniversalDetailsHero(
      title: anime['title']?.toString() ?? 'بدون عنوان',
      alternativeTitle: (anime['alternative_title'] ?? anime['alt_title'] ?? anime['title_en'] ?? anime['japanese'])?.toString(),
      imageUrl: anime['image_url']?.toString(),
      backdropUrl: (anime['backdrop_url'] ?? anime['backdrop'] ?? anime['cover_url'])?.toString(),
      typeLabel: _isMovie(anime) ? 'فيلم' : 'أنمي',
      status: anime['status']?.toString(),
      posterAction: _FavoriteIconAction(anime: anime, url: widget.url),
      actions: [
        IconButton(onPressed: () => _shareAnime(anime['title']?.toString() ?? 'أنمي'), icon: const Icon(Icons.share_outlined), style: IconButton.styleFrom(backgroundColor: Colors.black.withOpacity(.48), foregroundColor: Colors.white)),
        IconButton(onPressed: _copyAnimeLink, tooltip: 'نسخ الرابط', icon: const Icon(Icons.link_rounded), style: IconButton.styleFrom(backgroundColor: Colors.black.withOpacity(.48), foregroundColor: Colors.white)),
      ],
      onBack: () => Navigator.pop(context),
    );
  }

  Widget _buildInfo(BuildContext context, Map<String, dynamic> anime) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UniversalMetadata(items: [
          UniversalMetaItem(value: '${anime['rating'] ?? ''}', label: 'التقييم', icon: Icons.star_rounded, color: Colors.amber),
          UniversalMetaItem(value: '${anime['total_episodes'] ?? (anime['episodes'] as List?)?.length ?? ''}', label: _isMovie(anime) ? 'الفيلم' : 'الحلقات', icon: Icons.play_circle_outline_rounded, color: const Color(0xFF67C96B)),
          UniversalMetaItem(value: '${anime['year'] ?? anime['release_year'] ?? anime['aired_from'] ?? ''}', label: 'السنة', icon: Icons.calendar_month_rounded, color: const Color(0xFF36B9E8)),
          UniversalMetaItem(value: anime['status']?.toString() ?? '', label: 'الحالة', icon: Icons.info_outline_rounded, color: Colors.greenAccent),
        ]),
        if (anime['genres'] is List && (anime['genres'] as List).isNotEmpty) ...[
          const UniversalSectionHeader('التصنيفات'),
          UniversalGenreChips(genres: anime['genres'] as List),
          const SizedBox(height: 16),
        ],
        UniversalDescription(text: (anime['synopsis'] ?? anime['description'] ?? anime['story'] ?? anime['summary'])?.toString() ?? ''),
        _ExpandableDetails(anime: anime),
      ],
    );
  }

  Future<void> _shareAnime(String title) async {
    await ContentLinkService.share(type: 'anime', title: title, sourceUrl: widget.url);
  }

  Future<void> _copyAnimeLink() async {
    await Clipboard.setData(ClipboardData(text: widget.url));
    if (mounted) ToastUtils.show('تم نسخ رابط الأنمي', backgroundColor: AppTheme.accentColor);
  }

  Future<void> _downloadAnimeEpisode(Map<String, dynamic> link, Map<String, dynamic> episode) async {
    await _downloadAnimeEpisodeInternal(link, episode);
  }

  Future<bool> _downloadAnimeEpisodeInternal(Map<String, dynamic> link, Map<String, dynamic> episode) async {
    if (!context.read<AppStateProvider>().isLoggedIn) {
      ToastUtils.show('سجّل الدخول لاستخدام التنزيلات', backgroundColor: Colors.orange);
      return false;
    }
    final url = link['url']?.toString() ?? '';
    if (url.isEmpty) return false;
    try {
      final headers = <String, String>{};
      (link['headers'] as Map?)?.forEach((key, value) => headers[key.toString()] = value.toString());
      final anime = await _animeDetailsFuture;
      await DownloadService.saveAnimeEpisode(
        animeTitle: anime['title']?.toString() ?? 'أنمي',
        episodeTitle: episode['title']?.toString() ?? 'حلقة',
        url: url,
        coverUrl: anime['image_url']?.toString() ?? '',
        sourceId: anime['source_id']?.toString() ?? '',
        headers: headers,
      );
      if (mounted) ToastUtils.show('تم حفظ الحلقة في التنزيلات', backgroundColor: AppTheme.accentColor);
      return true;
    } catch (error) {
      if (mounted) ToastUtils.show('تعذر تنزيل الحلقة: $error', backgroundColor: Color(0xFF1976D2));
      return false;
    }
  }

  Future<bool> _downloadEpisodeFromButton(BuildContext context, Map<String, dynamic> episode) async {
    await _showDownloadBottomSheet(context, episode);
    return true;
  }

  Widget _buildActionButtons(BuildContext context, Map<String, dynamic> anime) {
    final isMovie = _isMovie(anime);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                label: isMovie ? 'مشاهدة الفيلم' : 'قائمة الحلقات',
                icon: isMovie ? Icons.play_arrow_rounded : Icons.format_list_bulleted_rounded,
                onPressed: () {
                  final episodes = anime['episodes'] as List<dynamic>? ?? const [];
                  if (episodes.isEmpty) {
                    final directUrl = (anime['stream_url'] ?? anime['video_url'] ?? '').toString().trim();
                    if (directUrl.isEmpty) {
                      ToastUtils.show('لا توجد وصلة تشغيل متاحة لهذا الفيلم', backgroundColor: Colors.orange);
                    } else {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerScreen(url: directUrl, title: anime['title']?.toString() ?? 'فيلم', episodeId: widget.url)));
                    }
                  } else if (isMovie) {
                    _showStreamBottomSheet(context, Map<String, dynamic>.from(episodes.first as Map), anime);
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => EpisodeListScreen(anime: anime, onPlay: (episode) => _showStreamBottomSheet(context, episode, anime), onDownload: (episode) => _showDownloadBottomSheet(context, episode))));
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEpisodesList(BuildContext context, Map<String, dynamic> anime) {
    final episodes = anime['episodes'] as List<dynamic>? ?? [];

    // Filter episodes
    final filteredEpisodes = episodes.where((ep) {
      if (_episodeSearchQuery.isEmpty) return true;
      final title = ep['title']?.toString().toLowerCase() ?? '';
      final query = _episodeSearchQuery.toLowerCase();
      // Check title or episode number/index
      final index = episodes.indexOf(ep);
      final epNum = '${index + 1}';
      return title.contains(query) || epNum.contains(query);
    }).toList();

    return Column(
      children: [
        if (_isEpisodeSearching)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _episodeSearchController,
                  autofocus: true,
                  style: TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن حلقة...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _episodeSearchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isEpisodeSearching = false;
                    _episodeSearchQuery = '';
                    _episodeSearchController.clear();
                  });
                },
                child: Text('إلغاء', style: TextStyle(color: AppTheme.primaryColor)),
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
                      'الحلقات',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isEpisodeSearching = true;
                        });
                      },
                      child: Icon(Icons.search, color: Colors.grey[400], size: 20),
                    ),
                 ],
               ),
              // Dummy dropdown for season
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.elevatedColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Text(
                  '${filteredEpisodes.length} حلقة',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              )
            ],
          ),
        const SizedBox(height: 16),
        if (filteredEpisodes.isEmpty)
            const Padding(
             padding: EdgeInsets.all(16.0),
             child: Text('لا توجد حلقات', style: TextStyle(color: AppTheme.textSecondaryColor)),
           )
        else
        ListView.separated(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: filteredEpisodes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final episode = filteredEpisodes[index];

            return EpisodeTile(
              title: episode['title']?.toString() ?? 'حلقة',
              subtitle: episode['duration']?.toString() ?? anime['duration']?.toString(),
              description: anime['synopsis']?.toString(),
              imageUrl: (episode['image'] ?? episode['thumbnail'] ?? anime['image_url'])?.toString(),
              onTap: () => _showStreamBottomSheet(context, episode, anime),
              onDownload: () => _downloadEpisodeFromButton(context, episode),
            );
          },
        ),
      ],
    );
  }

  Future<void> _showStreamBottomSheet(BuildContext context, Map<String, dynamic> episode, Map<String, dynamic> anime) async {
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

      final streams = await ApiService.fetchEpisodeStreams(episode['url']);
      if (context.mounted) Navigator.pop(context); // Close loading

      if (streams == null) {
        ToastUtils.show('لا توجد مصادر تشغيل', backgroundColor: Colors.orange);
        return;
      }

      final List<dynamic> directStreams = streams['direct_stream_urls'] ?? [];
      final String streamUrl = streams['stream_url'] ?? '';

      if (context.mounted) {
        showModalBottomSheet(
          context: context,
          backgroundColor: AppTheme.surfaceColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (sheetContext) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.6),
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
                             onTap: () => _playVideo(context, streamUrl, 'Auto', streams, anime),
                           ),

                         // Direct Streams
                          ...directStreams.map((stream) {
                             final quality = stream['quality'] ?? 'Unknown';
                             return ListTile(
                               leading: const Icon(Icons.hd, color: AppTheme.primaryColor),
                               title: Text(quality, style: const TextStyle(color: Colors.white)),
                               onTap: () => _playVideo(context, stream['url'], quality, streams, anime),
                             );
                          }).toList(),
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
      if (context.mounted) Navigator.pop(context); // Close loading
      ToastUtils.show('تعذر تحميل مصادر التشغيل', backgroundColor: Color(0xFF1976D2));
    }
  }

  void _playVideo(BuildContext context, String url, String quality, Map<String, dynamic> episodeData, Map<String, dynamic> anime, {bool popSheet = true}) {
     if (popSheet && context.mounted && Navigator.of(context).canPop()) {
       Navigator.pop(context);
     }

     // Add to History
     try {
       final historyItem = {
          'title': anime['title'] ?? 'No Title',
          'image_url': anime['image_url'] ?? '',
          'url': widget.url,
          'episode_url': episodeData['url'], // Specific episode URL for direct playback
          'episode': episodeData['title'] ?? 'Episode',
          'rating': anime['rating'],
          // For search screen compatibility
          'chapter': episodeData['title'] ?? 'Unknown',
          'date': DateTime.now().toString(),
       };
       Provider.of<AppStateProvider>(context, listen: false).addToHistory(historyItem, true);
     } catch (e) {
       print('Error adding to history: $e');
     }
     (() {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(
              url: url,
              title: episodeData['title'] ?? 'Episode',
              episodeId: episodeData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
              directStreamUrls: (episodeData['direct_stream_urls'] as List?)
                  ?.map((e) => Map<String, String>.from(e))
                  .toList() ?? [],
              headers: (episodeData['headers'] as Map?)
                  ?.map((key, value) => MapEntry(key.toString(), value.toString())) ?? {},
              allowedHosts: (episodeData['allowed_hosts'] as List?)
                  ?.map((host) => host.toString().toLowerCase().replaceFirst('www.', ''))
                  .toList() ?? [],
            ),
          ),
        );
     })();
  }

  Future<void> _showDownloadBottomSheet(BuildContext context, Map<String, dynamic> episode) async {
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
          child: CustomLoadingWidget(message: 'جارٍ تحميل روابط التنزيل...', size: 80),
        ),
      ),
    );

    try {
      final streams = await ApiService.fetchEpisodeStreams(episode['url']);
      Navigator.pop(context); // Close loading

      if (streams == null) {
        ToastUtils.show('لا توجد روابط تنزيل', backgroundColor: Colors.orange);
        return;
      }

      final legacyLinks = streams['download_links'];
      final directLinks = streams['direct_stream_urls'];
      final downloadLinks = legacyLinks is Map<String, dynamic>
          ? legacyLinks
          : <String, dynamic>{'مباشر': directLinks is List ? directLinks : <dynamic>[]};

      if (downloadLinks.isEmpty) {
        ToastUtils.show('لا توجد روابط تنزيل', backgroundColor: Colors.orange);
        return;
      }

      if (context.mounted) {
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
                     'روابط التنزيل',
                     style: TextStyle(
                       color: Colors.white,
                       fontSize: 18,
                       fontWeight: FontWeight.w800,
                     ),
                   ),
                   const SizedBox(height: 16),
                   Flexible(
                     child: ListView.builder(
                       shrinkWrap: true,
                       itemCount: downloadLinks.length,
                       itemBuilder: (context, index) {
                         final quality = downloadLinks.keys.elementAt(index);
                         final links = downloadLinks[quality] as List<dynamic>? ?? [];

                         return Theme(
                           data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                           child: ExpansionTile(
                             collapsedIconColor: Colors.white,
                             iconColor: AppTheme.primaryColor,
                             title: Text(
                                'الجودة: $quality',
                               style: const TextStyle(color: Colors.white),
                             ),
                             children: links.map<Widget>((link) {
                               return ListTile(
                                 leading: const Icon(Icons.download, color: AppTheme.primaryColor),
                                 title: Text(
                                   link['host'] ?? link['name'] ?? link['quality'] ?? 'رابط مباشر',
                                   style: TextStyle(color: Colors.grey[300]),
                                 ),
                                 onTap: () {
                                   final selected = Map<String, dynamic>.from(link as Map);
                                   selected['headers'] = streams['headers'] ?? selected['headers'] ?? const {};
                                   _downloadAnimeEpisode(selected, episode);
                                 },
                                 trailing: IconButton(
                                   icon: const Icon(Icons.save_alt, color: Colors.white70),
                                   tooltip: 'تنزيل داخل التطبيق',
                                   onPressed: () {
                                     final selected = Map<String, dynamic>.from(link as Map);
                                     selected['headers'] = streams['headers'] ?? selected['headers'] ?? const {};
                                     _downloadAnimeEpisodeInternal(selected, episode);
                                   },
                                 ),
                               );
                             }).toList(),
                           ),
                         );
                       },
                     ),
                   ),
                ],
              ),
            );
          },
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context); // Close loading
      ToastUtils.show('تعذر تحميل روابط التنزيل', backgroundColor: Color(0xFF1976D2));
    }
  }

}

class EpisodeListScreen extends StatefulWidget {
  final Map<String, dynamic> anime;
  final ValueChanged<Map<String, dynamic>> onPlay;
  final ValueChanged<Map<String, dynamic>> onDownload;

  const EpisodeListScreen({super.key, required this.anime, required this.onPlay, required this.onDownload});

  @override
  State<EpisodeListScreen> createState() => _EpisodeListScreenState();
}

class _EpisodeListScreenState extends State<EpisodeListScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final episodes = (widget.anime['episodes'] as List<dynamic>? ?? const []).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).where((episode) => episode['title']?.toString().toLowerCase().contains(_query.toLowerCase()) ?? true).toList();
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 190,
            backgroundColor: AppTheme.surfaceColor,
            title: const Text('الحلقات', style: TextStyle(fontWeight: FontWeight.w800)),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(fit: StackFit.expand, children: [
                Image.network((widget.anime['backdrop_url'] ?? widget.anime['image_url'] ?? '').toString(), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: AppTheme.surfaceColor)),
                DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, AppTheme.backgroundColor.withOpacity(.96)]))),
                PositionedDirectional(start: 18, end: 18, bottom: 16, child: Text(widget.anime['title']?.toString() ?? 'الأنمي', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900))),
              ]),
            ),
          ),
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Column(children: [
            TextField(controller: _search, onChanged: (value) => setState(() => _query = value), style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'ابحث عن حلقة أو رقم...', prefixIcon: const Icon(Icons.search_rounded), filled: true, fillColor: AppTheme.surfaceColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
            const SizedBox(height: 12),
            Row(children: [const Icon(Icons.video_library_rounded, color: AppTheme.primaryColor, size: 20), const SizedBox(width: 8), Text('${episodes.length} حلقة', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), const Spacer(), if (_query.isNotEmpty) TextButton(onPressed: () { _search.clear(); setState(() => _query = ''); }, child: const Text('مسح البحث'))]),
          ]))),
          if (episodes.isEmpty)
            const SliverFillRemaining(hasScrollBody: false, child: EmptyState(icon: Icons.video_library_outlined, title: 'لا توجد حلقات'))
          else
            SliverPadding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) {
              final episode = episodes[index];
              return TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: 1), duration: Duration(milliseconds: 260 + ((index.clamp(0, 8) as num).toInt() * 35)), curve: Curves.easeOutCubic, builder: (_, value, child) => Transform.translate(offset: Offset(0, 18 * (1 - value)), child: Opacity(opacity: value, child: child)), child: Padding(padding: const EdgeInsets.only(bottom: 10), child: EpisodeTile(title: episode['title']?.toString() ?? 'حلقة ${index + 1}', subtitle: episode['duration']?.toString(), imageUrl: (episode['image'] ?? episode['thumbnail'] ?? widget.anime['image_url'])?.toString(), onTap: () => widget.onPlay(episode), onDownload: () async { widget.onDownload(episode); return true; }))),
              }, childCount: episodes.length))),
        ],
      ),
    );
  }
}

class _FavoriteIconAction extends StatefulWidget {
  final Map<String, dynamic> anime;
  final String url;
  const _FavoriteIconAction({required this.anime, required this.url});

  @override
  State<_FavoriteIconAction> createState() => _FavoriteIconActionState();
}

class _FavoriteIconActionState extends State<_FavoriteIconAction> {
  @override
  Widget build(BuildContext context) {
    final appStateProvider = Provider.of<AppStateProvider>(context);
    final isFavorited = appStateProvider.favoriteAnime.any((item) => item['url'] == widget.url);

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
               final item = provider.favoriteAnime.firstWhere((x) => x['url'] == widget.url);
               await provider.removeFromFavorites(item['id'], true);
               ToastUtils.show('تمت الإزالة من المفضلة', backgroundColor: AppTheme.primaryColor);
            } else {
               await provider.addToFavorites({
                  'title': widget.anime['title'] ?? 'No Title',
                  'image_url': widget.anime['image_url'] ?? '',
                  'url': widget.url,
                  'rating': widget.anime['rating'],
                  'source': widget.anime['source'] ?? widget.anime['source_id'] ?? '',
                  'source_id': widget.anime['source_id'] ?? '',
               }, true);
               ToastUtils.show('تمت الإضافة إلى المفضلة', backgroundColor: AppTheme.primaryColor);
            }
            setState((){});
         } catch (e) {
            ToastUtils.show('تعذر تحديث المفضلة', backgroundColor: Color(0xFF1976D2));
         }
      },
    );
  }
}

class _ExpandableDetails extends StatefulWidget {
  final Map<String, dynamic> anime;
  const _ExpandableDetails({required this.anime});

  @override
  State<_ExpandableDetails> createState() => _ExpandableDetailsState();
}

class _ExpandableDetailsState extends State<_ExpandableDetails> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedCrossFade(
          firstChild: Text(
            widget.anime['synopsis'] ?? '',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey[300], fontSize: 13, height: 1.4),
          ),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.anime['synopsis'] ?? '',
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
        if (widget.anime['genres'] != null) ...[
          const Text('التصنيفات:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: (widget.anime['genres'] as List).map((genre) {
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
        _buildInfoRow('الاستوديو', widget.anime['studio'] ?? widget.anime['studios']),
        _buildInfoRow('المنتج', widget.anime['producer'] ?? widget.anime['producers']),
        _buildInfoRow('المؤلف', widget.anime['author'] ?? widget.anime['authors'] ?? widget.anime['writer']),
        _buildInfoRow('الشخصيات', widget.anime['characters']),
        _buildInfoRow('مؤدو الأصوات', widget.anime['voice_actors'] ?? widget.anime['voiceActors'] ?? widget.anime['cast']),
        _buildInfoRow('الحالة', widget.anime['status']),
        _buildInfoRow('النوع', widget.anime['type']),
        _buildInfoRow('المدة', widget.anime['duration']),
        _buildInfoRow('اليابانية', widget.anime['japanese']),
      ],
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    if (value == null || value.toString().isEmpty) return const SizedBox.shrink();
    final display = value is List ? value.map((item) => item is Map ? (item['name'] ?? item['title'] ?? item['character'] ?? item['actor'] ?? item).toString() : item.toString()).join('، ') : value is Map ? value.values.join('، ') : value.toString();
    if (display.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, height: 1.4),
          children: [
            TextSpan(text: '$label: ', style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold)),
            TextSpan(text: display, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
