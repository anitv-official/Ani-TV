import 'dart:io';
import 'package:flutter/material.dart';
import '../services/download_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/poster_image.dart';
import '../widgets/ui/state_views.dart';
import 'manga_reader_screen.dart';
import 'video_player_screen.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});
  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  final Set<String> _expanded = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final items = await DownloadService.list();
    if (mounted) setState(() { _items = items; _loading = false; });
  }

  Map<String, List<Map<String, dynamic>>> _group(String kind) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final item in _items.where((e) => e['kind'] == kind)) {
      final key = '${item['source_id'] ?? ''}:${item['title'] ?? ''}';
      (groups[key] ??= []).add(item);
    }
    for (final list in groups.values) {
      list.sort((a, b) => _number(a).compareTo(_number(b)));
    }
    return groups;
  }

  int _number(Map<String, dynamic> item) {
    final text = item['chapter']?.toString() ?? item['episode']?.toString() ?? '';
    return int.tryParse(RegExp(r'\d+').firstMatch(text)?.group(0) ?? '') ?? 999999;
  }

  @override
  Widget build(BuildContext context) {
    final manga = _group('manga');
    final anime = _group('anime');
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('التنزيلات')),
      body: _loading
          ? const LoadingView(message: 'جارٍ تحميل التنزيلات...', size: 64)
          : _items.isEmpty
              ? const EmptyState(
                  icon: Icons.download_outlined,
                  title: 'لا توجد تنزيلات محفوظة',
                  message: 'ستظهر هنا الحلقات والفصول التي تقوم بتنزيلها.',
                )
              : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 28), children: [
                  if (manga.isNotEmpty) _section('المانجا المنزلة', manga, true),
                  if (anime.isNotEmpty) _section('الأنمي المنزّل', anime, false),
                ]),
    );
  }

  Widget _section(String title, Map<String, List<Map<String, dynamic>>> groups, bool isManga) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(padding: const EdgeInsets.only(bottom: 10, top: 6), child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800))),
      ...groups.entries.map((entry) => _seriesCard(entry.value, isManga)),
      const SizedBox(height: 16),
    ],
  );

  Widget _seriesCard(List<Map<String, dynamic>> items, bool isManga) {
    final first = items.first;
    final key = '${first['source_id'] ?? ''}:${first['title'] ?? ''}';
    final open = _expanded.contains(key);
    final cover = first['cover_url']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          leading: PosterImage(url: cover, width: 46, height: 62, fallbackIcon: isManga ? Icons.menu_book : Icons.movie_outlined, borderRadius: BorderRadius.circular(8)),
          title: Text(first['title']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
          subtitle: Text('${items.length} ${isManga ? 'فصل' : 'حلقة'} محفوظة', style: const TextStyle(color: AppTheme.textSecondaryColor)),
          trailing: IconButton(icon: Icon(open ? Icons.expand_less : Icons.expand_more, color: Colors.white), onPressed: () => setState(() => open ? _expanded.remove(key) : _expanded.add(key))),
        ),
        if (open) ...items.asMap().entries.map((downloadEntry) {
          final item = downloadEntry.value;
          final exists = File(item['path']?.toString() ?? '').existsSync() || (isManga && Directory(item['path']?.toString() ?? '').existsSync());
          return ListTile(
            dense: true,
            leading: Icon(isManga ? Icons.menu_book : Icons.play_circle_outline, color: AppTheme.primaryColor),
            title: Text((isManga ? item['chapter'] : item['episode'])?.toString() ?? '', style: const TextStyle(color: Colors.white)),
            trailing: Icon(exists ? Icons.check_circle : Icons.error_outline, color: exists ? AppTheme.successColor : AppTheme.warningColor),
            onTap: () => _open(item, isManga, nextItem: isManga && downloadEntry.key + 1 < items.length ? items[downloadEntry.key + 1] : null),
          );
        }),
      ]),
    );
  }

  Future<void> _open(Map<String, dynamic> item, bool isManga, {Map<String, dynamic>? nextItem}) async {
    final path = item['path']?.toString() ?? '';
    if (!File(path).existsSync() && isManga == false) return;
    if (isManga) {
      final files = Directory(path).existsSync() ? Directory(path).listSync().whereType<File>().where((f) => f.path.toLowerCase().endsWith('.jpg')).toList() : <File>[];
      files.sort((a, b) => a.path.compareTo(b.path));
      if (!mounted || files.isEmpty) return;
      List<String>? nextPages;
      if (nextItem != null && Directory(nextItem['path']?.toString() ?? '').existsSync()) {
        final nextFiles = Directory(nextItem['path'].toString()).listSync().whereType<File>().where((f) => f.path.toLowerCase().endsWith('.jpg')).toList()..sort((a, b) => a.path.compareTo(b.path));
        nextPages = nextFiles.map((f) => f.path).toList();
      }
      Navigator.push(context, MaterialPageRoute(builder: (_) => MangaReaderScreen(pages: files.map((f) => f.path).toList(), title: item['title']?.toString(), chapterId: item['chapter']?.toString(), comicImageUrl: item['cover_url']?.toString(), nextOfflinePages: nextPages, nextOfflineTitle: nextItem?['chapter']?.toString(), nextOfflineChapterId: nextItem?['chapter']?.toString())));
    } else if (mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerScreen(url: path, title: item['episode']?.toString() ?? 'حلقة', episodeId: path)));
    }
  }
}
