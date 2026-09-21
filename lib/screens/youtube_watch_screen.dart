import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../sources/source_registry.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_controls.dart';
import '../widgets/ui/poster_image.dart';

class YouTubeWatchScreen extends StatefulWidget {
  final String url;
  final String title;
  final String imageUrl;

  const YouTubeWatchScreen({super.key, required this.url, required this.title, this.imageUrl = ''});

  @override
  State<YouTubeWatchScreen> createState() => _YouTubeWatchScreenState();
}

class _YouTubeWatchScreenState extends State<YouTubeWatchScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  Map<String, dynamic>? _streams;
  List<Map<String, dynamic>> _related = [];
  List<Map<String, String>> _qualityOptions = [];
  String _selectedQuality = '';
  bool _loading = true;
  bool _changingQuality = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = ''; });
    try {
      final streams = await SourceRegistry.streams(widget.url);
      final streamUrl = streams?['stream_url']?.toString() ?? '';
      if (streams == null || streamUrl.isEmpty) {
        throw Exception('لا توجد صيغة تشغيل متاحة');
      }
      final options = _readQualityOptions(streams);
      final controller = await _initializeController(streamUrl, streams);
      if (!mounted) {
        controller.dispose();
        return;
      }
      _streams = streams;
      _qualityOptions = options;
      _selectedQuality = options.isEmpty ? '' : options.first['quality'] ?? '';
      _videoController = controller;
      _chewieController = _createChewieController(controller);
      setState(() => _loading = false);
      _loadRelated();
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'تعذر تشغيل الفيديو حالياً.'; });
    }
  }

  Future<VideoPlayerController> _initializeController(String url, Map<String, dynamic> streams) async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: Map<String, String>.from(streams['headers'] ?? const {}),
    );
    try {
      await controller.initialize();
      return controller;
    } catch (_) {
      controller.dispose();
      rethrow;
    }
  }

  List<Map<String, String>> _readQualityOptions(Map<String, dynamic> streams) {
    final raw = streams['direct_stream_urls'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((item) {
      return {
        'url': item['url']?.toString() ?? '',
        'quality': item['quality']?.toString().trim().isNotEmpty == true ? item['quality'].toString() : 'تلقائي',
      };
    }).where((item) => item['url']!.isNotEmpty).toList(growable: false);
  }

  ChewieController _createChewieController(VideoPlayerController controller) {
    return ChewieController(
      videoPlayerController: controller,
      autoPlay: true,
      looping: false,
      showControls: true,
      allowFullScreen: true,
      fullScreenByDefault: false,
      allowPlaybackSpeedChanging: true,
      aspectRatio: controller.value.aspectRatio > 0 ? controller.value.aspectRatio : 16 / 9,
      customControls: CustomControls(
        title: widget.title,
        onBackPressed: () => Navigator.of(context).maybePop(),
        qualityOptions: _qualityOptions,
        selectedQuality: _selectedQuality,
        onQualityChanged: _changeQuality,
      ),
      materialProgressColors: ChewieProgressColors(
        playedColor: AppTheme.primaryColor,
        handleColor: AppTheme.primaryColor,
        bufferedColor: Colors.white54,
        backgroundColor: Colors.white24,
      ),
    );
  }

  Future<void> _changeQuality(String url, String quality) async {
    if (_changingQuality || url.isEmpty) return;
    final previous = _videoController;
    final previousChewie = _chewieController;
    final position = previous?.value.position ?? Duration.zero;
    final wasPlaying = previous?.value.isPlaying == true;
    final streams = _streams;
    if (streams == null) return;

    setState(() => _changingQuality = true);
    try {
      final next = await _initializeController(url, streams);
      if (!mounted) {
        next.dispose();
        return;
      }
      await next.seekTo(position);
      if (wasPlaying) await next.play();
      previousChewie?.dispose();
      previous?.dispose();
      _videoController = next;
      _selectedQuality = quality;
      _chewieController = _createChewieController(next);
      setState(() => _changingQuality = false);
    } catch (_) {
      if (mounted) setState(() => _changingQuality = false);
    }
  }

  Future<void> _loadRelated() async {
    try {
      final source = SourceRegistry.sourceFor(widget.url);
      if (source == null) return;
      final related = await source.search(widget.title);
      if (!mounted) return;
      setState(() => _related = related.where((item) => item['url'] != widget.url).take(20).toList());
    } catch (_) {
      // The player remains usable when related content is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final chewie = _chewieController;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        children: [
          if (_loading)
            const AspectRatio(aspectRatio: 16 / 9, child: Center(child: CircularProgressIndicator()))
          else if (_error.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_off_rounded, color: Colors.white70, size: 42),
                const SizedBox(height: 10),
                Text(_error, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة')),
              ])),
            )
          else if (chewie != null)
            AspectRatio(aspectRatio: _videoController?.value.aspectRatio ?? 16 / 9, child: Chewie(controller: chewie)),
          if (_changingQuality) const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('فيديوهات مرتبطة', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ),
          ..._related.map((item) => ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: SizedBox(width: 140, height: 80, child: PosterImage(url: item['image_url']?.toString(), borderRadius: BorderRadius.circular(8))),
                title: Text(item['title']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                subtitle: Text([item['rating']?.toString() ?? '', item['duration']?.toString() ?? ''].where((value) => value.isNotEmpty).join(' • '), style: const TextStyle(color: Colors.white60)),
                onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => YouTubeWatchScreen(url: item['url'].toString(), title: item['title'].toString(), imageUrl: item['image_url']?.toString() ?? ''))),
              )),
        ],
      ),
    );
  }
}
