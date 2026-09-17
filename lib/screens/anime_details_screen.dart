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
            return ErrorState(onRetry: () => setState(() => _animeDetailsFuture = ApiService.fetchAnimeDetails(widget.url)));
          } else if (!snapshot.hasData) {
            return const EmptyState(icon: Icons.movie_outlined, title: 'لا توجد بيانات');
          }

          final anime = snapshot.data!;
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
                        const SizedBox(height: 16),
                        _buildEpisodesList(context, anime),
                        const SizedBox(height: 22),
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
    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // On wide screens, restrict the height so it doesn't take up the whole view
            // If width > 800, use a fixed shorter height or wider aspect ratio
            double aspectRatio = 16 / 9;
            if (constraints.maxWidth > 800) {
              aspectRatio = 21 / 9; // Ultra-wide for desktop
            }
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: PosterImage(
                  url: anime['image_url']?.toString(),
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.zero,
                ),
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
                  AppTheme.backgroundColor.withOpacity(0.18),
                  Colors.transparent,
                  AppTheme.backgroundColor.withOpacity(0.78),
                  AppTheme.backgroundColor,
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
        Positioned.fill(
          child: Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.45),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfo(BuildContext context, Map<String, dynamic> anime) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          anime['title'] ?? 'بدون عنوان',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(height: 1.2),
        ),
        const SizedBox(height: 8),
        Row(children: [
          SourceBadge(label: anime['source']?.toString() ?? 'AniTV', compact: false),
          const SizedBox(width: 8),
          if ((anime['status'] ?? '').toString().isNotEmpty)
            SourceBadge(label: anime['status']?.toString()),
        ]),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if ((anime['release_date'] ?? '').toString().trim().isNotEmpty)
              Text(
                anime['release_date'].toString().split(',').last.trim(),
                style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
              ),
            Text(
              '${anime['total_episodes'] ?? (anime['episodes'] as List?)?.length ?? 0} حلقة',
              style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
            ),
            if ((anime['rating'] ?? '').toString().trim().isNotEmpty) ...[
              const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
              Text(
                anime['rating'].toString(),
                style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        // Genres as text or simple list? Reference image uses text description.
        // Let's use the synopsis as the main text block.
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
    if (!context.read<AppStateProvider>().isLoggedIn) {
      ToastUtils.show('سجّل الدخول لاستخدام التنزيلات', backgroundColor: Colors.orange);
      return;
    }
    final url = link['url']?.toString() ?? '';
    if (url.isEmpty) return;
    try {
      final anime = await _animeDetailsFuture;
      final sent = await DownloadService.sendToAdm(url, title: '${anime['title'] ?? 'أنمي'} - ${episode['title'] ?? 'حلقة'}');
      if (mounted) ToastUtils.show(sent ? 'تم إرسال الرابط إلى ADM' : 'لم يتم العثور على تطبيق ADM. ثبّته أولًا ثم أعد المحاولة.', backgroundColor: sent ? AppTheme.accentColor : Color(0xFF1976D2));
    } catch (error) {
      if (mounted) ToastUtils.show('تعذر تنزيل الحلقة: $error', backgroundColor: Color(0xFF1976D2));
    }
  }

  Future<bool> _downloadAnimeEpisodeInternal(Map<String, dynamic> link, Map<String, dynamic> episode) async {
    if (!context.read<AppStateProvider>().isLoggedIn) {
      ToastUtils.show('سجّل الدخول لاستخدام التنزيلات', backgroundColor: Colors.orange);
      return false;
    }
    final url = link['url']?.toString() ?? '';
    if (url.isEmpty) return false;
    try {
      final anime = await _animeDetailsFuture;
      await DownloadService.saveAnimeEpisode(
        animeTitle: anime['title']?.toString() ?? 'أنمي',
        episodeTitle: episode['title']?.toString() ?? 'حلقة',
        url: url,
        coverUrl: anime['image_url']?.toString() ?? '',
        sourceId: anime['source_id']?.toString() ?? '',
      );
      if (mounted) ToastUtils.show('تم حفظ الحلقة في التنزيلات', backgroundColor: AppTheme.accentColor);
      return true;
    } catch (error) {
      if (mounted) ToastUtils.show('تعذر تنزيل الحلقة: $error', backgroundColor: Color(0xFF1976D2));
      return false;
    }
  }

  Future<bool> _downloadEpisodeFromButton(BuildContext context, Map<String, dynamic> episode) async {
    if (context.mounted) ToastUtils.show('تنزيل الأفلام والأنمي والدراما قريبًا', backgroundColor: AppTheme.primaryColor);
    return false;
  }

  Widget _buildActionButtons(BuildContext context, Map<String, dynamic> anime) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                label: 'تشغيل',
                icon: Icons.play_arrow_rounded,
                onPressed: () {
                   if (anime['episodes'] != null && (anime['episodes'] as List).isNotEmpty) {
                      _showStreamBottomSheet(context, anime['episodes'][0], anime);
                   }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SecondaryButton(
                label: 'التنزيل قريبًا',
                icon: Icons.download_rounded,
                onPressed: () => ToastUtils.show('تنزيل الأفلام والأنمي والدراما قريبًا', backgroundColor: AppTheme.primaryColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [

              _FavoriteIconAction(anime: anime, url: widget.url),
              IconAction(icon: Icons.share_outlined, label: 'مشاركة', onTap: () => _shareAnime(anime['title']?.toString() ?? 'أنمي')),
              IconAction(icon: Icons.link_rounded, label: 'نسخ الرابط', onTap: _copyAnimeLink),
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
      final sourceId = streams['source_id']?.toString() ?? '';
      if (_isInAppSource(sourceId) && streamUrl.isNotEmpty && context.mounted) {
        _playVideo(
          context,
          streamUrl,
          'مشغل',
          {
            ...streams,
            'title': episode['title'] ?? streams['title'] ?? 'حلقة',
            'url': episode['url'],
            'id': episode['url'] ?? episode['id'],
          },
          anime,
          popSheet: false,
        );
        return;
      }

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

      if (streams == null || streams['download_links'] == null) {
        ToastUtils.show('لا توجد روابط تنزيل', backgroundColor: Colors.orange);
        return;
      }

      final downloadLinks = streams['download_links'] as Map<String, dynamic>;

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
                                   link['host'] ?? 'Unknown Host',
                                   style: TextStyle(color: Colors.grey[300]),
                                 ),
                                 onTap: () => _downloadAnimeEpisode(Map<String, dynamic>.from(link as Map), episode),
                                 trailing: IconButton(
                                   icon: const Icon(Icons.save_alt, color: Colors.white70),
                                   tooltip: 'تنزيل داخل التطبيق',
                                   onPressed: () => _downloadAnimeEpisodeInternal(Map<String, dynamic>.from(link as Map), episode),
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

  bool _isInAppSource(String sourceId) {
    return sourceId == 'risto' || sourceId == 'anime3rb' || sourceId == 'anime4up' || sourceId == 'anyplay';
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
        _buildInfoRow('الاستوديو', widget.anime['studio']),
        _buildInfoRow('المنتج', widget.anime['producer']),
        _buildInfoRow('الحالة', widget.anime['status']),
        _buildInfoRow('النوع', widget.anime['type']),
        _buildInfoRow('المدة', widget.anime['duration']),
        _buildInfoRow('اليابانية', widget.anime['japanese']),
      ],
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    if (value == null || value.toString().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, height: 1.4),
          children: [
            TextSpan(text: '$label: ', style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold)),
            TextSpan(text: value.toString(), style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
