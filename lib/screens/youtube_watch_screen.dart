import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../sources/source_registry.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/content_card.dart';
import '../widgets/ui/poster_image.dart';
import 'video_player_screen.dart';

class YouTubeWatchScreen extends StatefulWidget {
  final String url;
  final String title;
  final String imageUrl;
  const YouTubeWatchScreen({super.key, required this.url, required this.title, this.imageUrl = ''});
  @override State<YouTubeWatchScreen> createState() => _YouTubeWatchScreenState();
}

class _YouTubeWatchScreenState extends State<YouTubeWatchScreen> {
  VideoPlayerController? _controller;
  Map<String, dynamic>? _streams;
  List<Map<String, dynamic>> _related = [];
  bool _loading = true;
  String _error = '';

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _controller?.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final streams = await SourceRegistry.streams(widget.url);
      if (streams == null || streams['stream_url']?.toString().isEmpty != false) throw Exception('لا توجد صيغة تشغيل متاحة');
      final controller = VideoPlayerController.networkUrl(Uri.parse(streams['stream_url'].toString()), httpHeaders: Map<String, String>.from(streams['headers'] ?? {}));
      await controller.initialize();
      await controller.play();
      final related = await SourceRegistry.sourceFor(widget.url)?.search(widget.title) ?? <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() { _streams = streams; _controller = controller; _related = related.where((e) => e['url'] != widget.url).take(20).toList(); _loading = false; });
    } catch (e) { if (mounted) setState(() { _loading = false; _error = 'تعذر تشغيل الفيديو حالياً'; }); }
  }

  void _openFullscreen() {
    final streams = _streams; if (streams == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerScreen(url: streams['stream_url'].toString(), title: widget.title, episodeId: widget.url, directStreamUrls: (streams['direct_stream_urls'] as List? ?? []).map((e) => Map<String, String>.from(e)).toList(), headers: Map<String, String>.from(streams['headers'] ?? {}), allowedHosts: const ['googlevideo.com'], allowWebView: false)));
  }

  @override Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.black, title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis)), body: ListView(children: [
      if (_loading) const AspectRatio(aspectRatio: 16 / 9, child: Center(child: CircularProgressIndicator()))
      else if (_error.isNotEmpty) AspectRatio(aspectRatio: 16 / 9, child: Center(child: Text(_error, style: const TextStyle(color: Colors.white))))
      else if (controller != null) Stack(children: [AspectRatio(aspectRatio: controller.value.aspectRatio, child: VideoPlayer(controller)), Positioned(bottom: 10, right: 10, child: IconButton(onPressed: _openFullscreen, icon: const Icon(Icons.fullscreen, color: Colors.white, size: 32)))])
      else const SizedBox.shrink(),
      Padding(padding: const EdgeInsets.all(16), child: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('فيديوهات مرتبطة', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))),
      ..._related.map((item) => ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), leading: SizedBox(width: 140, height: 80, child: PosterImage(url: item['image_url']?.toString(), borderRadius: BorderRadius.circular(8))), title: Text(item['title']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)), subtitle: Text([item['rating']?.toString() ?? '', item['duration']?.toString() ?? ''].where((e) => e.isNotEmpty).join(' • '), style: const TextStyle(color: Colors.white60)), onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => YouTubeWatchScreen(url: item['url'].toString(), title: item['title'].toString(), imageUrl: item['image_url']?.toString() ?? '')))),
    ]));
  }
}
