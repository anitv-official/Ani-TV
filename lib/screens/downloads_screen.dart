import 'dart:io';
import 'package:flutter/material.dart';
import '../services/download_service.dart';
import '../theme/app_theme.dart';
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
      appBar: AppBar(title: const Text('التنزيلات'), backgroundColor: AppTheme.backgroundColor),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('لا توجد تنزيلات محفوظة', style: TextStyle(color: Colors.white70)))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  if (manga.isNotEmpty) _section('المانجا المنزلة', manga, true),
                  if (anime.isNotEmpty) _section('الأنمي المنزّل', anime, false),
                ]),
    );
  }

  Widget _section(String title, Map<String, List<Map<String, dynamic>>> groups, bool isManga) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold))),
      ...groups.entries.map((entry) => _seriesCard(entry.value, isManga)),
      const SizedBox(height: 20),
    ],
  );

  Widget _seriesCard(List<Map<String, dynamic>> items, bool isManga) {
    final first = items.first;
    final key = '${first['source_id'] ?? ''}:${first['title'] ?? ''}';
    final open = _expanded.contains(key);
    final cover = first['cover_url']?.toString() ?? '';
    return Card(
      color: AppTheme.surfaceColor,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(children: [
        ListTile(
          leading: cover.isNotEmpty ? Image.network(cover, width: 52, height: 70, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _icon(isManga)) : _icon(isManga),
          title: Text(first['title']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text('${items.length} ${isManga ? 'فصل' : 'حلقة'} محفوظة', style: const TextStyle(color: Colors.white60)),
          trailing: IconButton(icon: Icon(open ? Icons.expand_less : Icons.expand_more, color: Colors.white), onPressed: () => setState(() => open ? _expanded.remove(key) : _expanded.add(key))),
        ),
        if (open) ...items.map((item) => ListTile(
          dense: true,
          leading: Icon(isManga ? Icons.menu_book : Icons.play_circle_outline, color: AppTheme.primaryColor),
          title: Text((isManga ? item['chapter'] : item['episode'])?.toString() ?? '', style: const TextStyle(color: Colors.white)),
          trailing: File(item['path']?.toString() ?? '').existsSync() ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.error_outline, color: Colors.orange),
          onTap: () => _open(item, isManga),
        )),
      ]),
    );
  }

  Widget _icon(bool isManga) => Icon(isManga ? Icons.menu_book : Icons.movie, color: AppTheme.primaryColor, size: 38);

  Future<void> _open(Map<String, dynamic> item, bool isManga) async {
    final path = item['path']?.toString() ?? '';
    if (!File(path).existsSync() && isManga == false) return;
    if (isManga) {
      final files = Directory(path).existsSync() ? Directory(path).listSync().whereType<File>().where((f) => f.path.toLowerCase().endsWith('.jpg')).toList() : <File>[];
      files.sort((a, b) => a.path.compareTo(b.path));
      if (!mounted || files.isEmpty) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => MangaReaderScreen(pages: files.map((f) => f.path).toList(), title: item['title']?.toString(), chapterId: item['chapter']?.toString(), comicImageUrl: item['cover_url']?.toString())));
    } else if (mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerScreen(url: path, title: item['episode']?.toString() ?? 'حلقة', episodeId: path)));
    }
  }
}
