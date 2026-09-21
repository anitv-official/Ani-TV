import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/youtube_service.dart';
import '../theme/app_theme.dart';
import 'video_player_screen.dart';

class YoutubeScreen extends StatefulWidget {
  final bool embedded;

  const YoutubeScreen({super.key, this.embedded = false});

  @override
  State<YoutubeScreen> createState() => _YoutubeScreenState();
}

class _YoutubeScreenState extends State<YoutubeScreen> {
  final YoutubeService _service = const YoutubeService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<YoutubeVideo> _results = const [];
  bool _searchExpanded = false;
  bool _loading = false;
  String? _error;
  String _lastQuery = '';
  int _requestId = 0;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _expandSearch() {
    if (_searchExpanded) return;
    setState(() => _searchExpanded = true);
    Future<void>.delayed(const Duration(milliseconds: 220), () {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _collapseSearch() {
    _searchFocus.unfocus();
    setState(() {
      _searchExpanded = false;
      if (_searchController.text.trim().isEmpty) _error = null;
    });
  }

  Future<void> _search([String? rawQuery]) async {
    final query = (rawQuery ?? _searchController.text).trim();
    if (query.isEmpty) {
      _expandSearch();
      return;
    }

    final requestId = ++_requestId;
    _searchFocus.unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _lastQuery = query;
    });

    try {
      final results = await _service.search(query);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  void _openVideo(YoutubeVideo video) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => YoutubePlaybackScreen(video: video),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        _YoutubeHeader(
          expanded: _searchExpanded,
          controller: _searchController,
          focusNode: _searchFocus,
          loading: _loading,
          onExpand: _expandSearch,
          onCollapse: _collapseSearch,
          onSearch: _search,
        ),
        Expanded(child: _buildBody()),
      ],
    );

    if (widget.embedded) return body;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(child: body),
    );
  }

  Widget _buildBody() {
    if (_loading && _results.isEmpty) {
      return const _YoutubeLoadingList();
    }
    if (_error != null && _results.isEmpty) {
      return _YoutubeMessage(
        icon: Icons.cloud_off_rounded,
        title: 'تعذر تحميل نتائج يوتيوب',
        message: _error!,
        actionLabel: 'إعادة المحاولة',
        onAction: _search,
      );
    }
    if (_results.isEmpty && _lastQuery.isNotEmpty) {
      return const _YoutubeMessage(
        icon: Icons.search_off_rounded,
        title: 'لا توجد نتائج',
        message: 'جرّب كلمات بحث أخرى للوصول إلى الفيديو المطلوب.',
      );
    }
    if (_results.isEmpty) {
      return _YoutubeMessage(
        icon: Icons.play_circle_outline_rounded,
        title: 'ابحث في يوتيوب',
        message: 'اضغط أيقونة البحث للعثور على فيديوهات يوتيوب العامة.',
        actionLabel: 'بدء البحث',
        onAction: _expandSearch,
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () => _search(_lastQuery),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
        itemCount: _results.length + (_loading || _error != null ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 18),
        itemBuilder: (context, index) {
          if (index == _results.length) {
            if (_loading) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return _InlineError(message: _error!, onRetry: _search);
          }
          return YoutubeVideoCard(
            video: _results[index],
            onTap: () => _openVideo(_results[index]),
          );
        },
      ),
    );
  }
}

class _YoutubeHeader extends StatelessWidget {
  final bool expanded;
  final bool loading;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onExpand;
  final VoidCallback onCollapse;
  final ValueChanged<String> onSearch;

  const _YoutubeHeader({
    required this.expanded,
    required this.loading,
    required this.controller,
    required this.focusNode,
    required this.onExpand,
    required this.onCollapse,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: AnimatedOpacity(
              opacity: expanded ? 0 : 1,
              duration: const Duration(milliseconds: 160),
              child: const Text(
                'لائحة يوتيوب',
                style: TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            width: expanded ? MediaQuery.sizeOf(context).width - 80 : 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(expanded ? 16 : 24),
              border: Border.all(
                color: expanded
                    ? AppTheme.primaryColor.withOpacity(.45)
                    : AppTheme.borderColor,
              ),
              boxShadow: expanded ? AppTheme.subtleShadow : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(expanded ? 16 : 24),
              child: expanded
                  ? Row(
                      children: [
                        IconButton(
                          tooltip: 'بحث',
                          onPressed: loading
                              ? null
                              : () => onSearch(controller.text),
                          icon: loading
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                  ),
                                )
                              : const Icon(Icons.search_rounded),
                        ),
                        Expanded(
                          child: TextField(
                            controller: controller,
                            focusNode: focusNode,
                            textInputAction: TextInputAction.search,
                            onSubmitted: onSearch,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              color: AppTheme.textPrimaryColor,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'ابحث في يوتيوب',
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'إغلاق البحث',
                          onPressed: onCollapse,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    )
                  : IconButton(
                      tooltip: 'البحث في يوتيوب',
                      onPressed: onExpand,
                      icon: const Icon(Icons.search_rounded),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class YoutubeVideoCard extends StatelessWidget {
  final YoutubeVideo video;
  final VoidCallback onTap;
  final bool compact;

  const YoutubeVideoCard({
    super.key,
    required this.video,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final metadata = <String>[
      if (video.uploader.isNotEmpty) video.uploader,
      if (video.viewCount >= 0) '${_compactNumber(video.viewCount)} مشاهدة',
      if (video.uploaded.isNotEmpty) video.uploaded,
    ].join(' • ');

    if (compact) {
      return Semantics(
        button: true,
        label: video.title,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 154,
                  child: _YoutubeThumbnail(video: video, radius: 10),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontSize: 14,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (metadata.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          metadata,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: video.title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _YoutubeThumbnail(video: video, radius: 14),
            const SizedBox(height: 11),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: AppTheme.elevatedColor,
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppTheme.textSecondaryColor,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontSize: 16,
                          height: 1.35,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (metadata.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          metadata,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.more_vert_rounded,
                    color: AppTheme.textSecondaryColor,
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _YoutubeThumbnail extends StatelessWidget {
  final YoutubeVideo video;
  final double radius;

  const _YoutubeThumbnail({required this.video, required this.radius});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: AppTheme.elevatedColor,
              child: video.thumbnailUrl.isEmpty
                  ? const Icon(
                      Icons.ondemand_video_rounded,
                      color: AppTheme.textMutedColor,
                      size: 42,
                    )
                  : CachedNetworkImage(
                      imageUrl: video.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const ColoredBox(
                        color: AppTheme.elevatedColor,
                      ),
                      errorWidget: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: AppTheme.textMutedColor,
                      ),
                    ),
            ),
            if (video.durationSeconds > 0)
              PositionedDirectional(
                end: 7,
                bottom: 7,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.82),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    _duration(video.durationSeconds),
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class YoutubePlaybackScreen extends StatefulWidget {
  final YoutubeVideo video;

  const YoutubePlaybackScreen({super.key, required this.video});

  @override
  State<YoutubePlaybackScreen> createState() => _YoutubePlaybackScreenState();
}

class _YoutubePlaybackScreenState extends State<YoutubePlaybackScreen> {
  final YoutubeService _service = const YoutubeService();
  late Future<YoutubePlayback> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.streams(widget.video.url);
  }

  void _retry() => setState(() => _future = _service.streams(widget.video.url));

  void _openRelated(YoutubeVideo video) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => YoutubePlaybackScreen(video: video),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<YoutubePlayback>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            appBar: AppBar(title: const Text('يوتيوب')),
            body: _YoutubeMessage(
              icon: Icons.play_disabled_rounded,
              title: 'تعذر تشغيل الفيديو',
              message: snapshot.error.toString(),
              actionLabel: 'إعادة المحاولة',
              onAction: _retry,
            ),
          );
        }
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            appBar: AppBar(title: const Text('يوتيوب')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final playback = snapshot.data!;
        final streams = playback.streams
            .map((stream) => stream.toPlayerMap())
            .toList(growable: false);
        final video = playback.video;
        return VideoPlayerScreen(
          key: ValueKey(video.url),
          url: streams.first['url']!,
          title: video.title,
          episodeId: video.url,
          directStreamUrls: streams,
          headers: const {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
          },
          allowWebView: false,
          portraitLayout: true,
          belowPlayer: _YoutubeWatchDetails(
            video: video,
            related: playback.related,
            onVideoTap: _openRelated,
          ),
        );
      },
    );
  }
}

class _YoutubeWatchDetails extends StatelessWidget {
  final YoutubeVideo video;
  final List<YoutubeVideo> related;
  final ValueChanged<YoutubeVideo> onVideoTap;

  const _YoutubeWatchDetails({
    required this.video,
    required this.related,
    required this.onVideoTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 30),
      children: [
        Text(
          video.title,
          style: const TextStyle(
            color: AppTheme.textPrimaryColor,
            fontSize: 19,
            height: 1.35,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          [
            if (video.viewCount >= 0) '${_compactNumber(video.viewCount)} مشاهدة',
            if (video.uploaded.isNotEmpty) video.uploaded,
          ].join(' • '),
          style: const TextStyle(
            color: AppTheme.textSecondaryColor,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primaryColor.withOpacity(.16),
                child: const Icon(
                  Icons.person_rounded,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  video.uploader.isEmpty ? 'قناة يوتيوب' : video.uploader,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimaryColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (video.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              video.description,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                height: 1.55,
              ),
            ),
          ),
        ],
        const SizedBox(height: 22),
        const Text(
          'فيديوهات ذات صلة',
          style: TextStyle(
            color: AppTheme.textPrimaryColor,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        if (related.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: Text(
              'لا توجد فيديوهات مرتبطة متاحة.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondaryColor),
            ),
          )
        else
          ...related.map(
            (item) => YoutubeVideoCard(
              video: item,
              compact: true,
              onTap: () => onVideoTap(item),
            ),
          ),
      ],
    );
  }
}

class _YoutubeLoadingList extends StatelessWidget {
  const _YoutubeLoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 18),
      itemBuilder: (_, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 14,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }
}

class _YoutubeMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _YoutubeMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                height: 1.55,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _InlineError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withOpacity(.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.errorColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textSecondaryColor),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }
}

String _duration(int seconds) {
  final duration = Duration(seconds: seconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final remainder = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }
  return '$minutes:${remainder.toString().padLeft(2, '0')}';
}

String _compactNumber(int value) {
  if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(1)} مليار';
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)} مليون';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)} ألف';
  return '$value';
}
