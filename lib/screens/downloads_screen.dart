import 'dart:io';
import 'package:flutter/material.dart';
import '../services/download_service.dart';
import '../theme/app_theme.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});
  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await DownloadService.list();
    if (mounted) setState(() { _items = items; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final manga = _items.where((e) => e['kind'] == 'manga').toList();
    final anime = _items.where((e) => e['kind'] == 'anime').toList();
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('التنزيلات'), backgroundColor: AppTheme.backgroundColor),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('لا توجد تنزيلات محفوظة', style: TextStyle(color: Colors.white70)))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  if (manga.isNotEmpty) _section('المانجا المنزلة', manga, Icons.menu_book),
                  if (anime.isNotEmpty) _section('الأنمي المنزّل', anime, Icons.movie),
                ]),
    );
  }

  Widget _section(String title, List<Map<String, dynamic>> items, IconData icon) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold))),
      ...items.map((item) => Card(
        color: AppTheme.surfaceColor,
        child: ListTile(
          leading: Icon(icon, color: AppTheme.primaryColor),
          title: Text(item['title']?.toString() ?? '', style: const TextStyle(color: Colors.white)),
          subtitle: Text(item['kind'] == 'manga' ? 'الفصل: ${item['chapter'] ?? ''}' : 'الحلقة: ${item['episode'] ?? ''}', style: const TextStyle(color: Colors.white60)),
          trailing: File(item['path']?.toString() ?? '').existsSync() ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.error_outline, color: Colors.orange),
        ),
      )),
      const SizedBox(height: 20),
    ],
  );
}
