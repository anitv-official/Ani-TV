import 'dart:io';

import 'package:flutter/material.dart';

import '../services/download_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_navigation_drawer.dart';
import '../widgets/ui/app_fixed_header.dart';
import '../widgets/ui/poster_image.dart';
import '../widgets/ui/state_views.dart';
import 'manga_reader_screen.dart';
import 'video_player_screen.dart';

class DownloadsScreen extends StatefulWidget {
  final bool embedded;
  const DownloadsScreen({super.key, this.embedded = false});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    DownloadService.changes.addListener(_refresh);
    _refresh();
  }

  @override
  void dispose() {
    DownloadService.changes.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final items = await DownloadService.list();
    if (mounted) setState(() { _items = items; _loading = false; });
  }

  Future<void> _clearCompleted() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف التنزيلات المكتملة؟'),
        content: const Text('سيتم حذف الملفات المكتملة فقط من مساحة AniTV. لن تتأثر ملفاتك الشخصية.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed == true) await DownloadService.clearCompleted();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final active = _items.where((item) => !{'completed', 'cancelled'}.contains(item['status'])).toList();
    final completed = _items.where((item) => item['status'] == 'completed').toList();
    final failed = _items.where((item) => item['status'] == 'failed' || item['status'] == 'cancelled').toList();
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      endDrawer: widget.embedded ? null : const AppNavigationDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            if (!widget.embedded)
              AppFixedHeader(title: 'التنزيلات', trailing: IconButton(onPressed: completed.isEmpty ? null : _clearCompleted, tooltip: 'حذف المكتمل', icon: const Icon(Icons.delete_sweep_outlined))),
            Expanded(
              child: _loading
                  ? const LoadingView(message: 'جارٍ تحميل التنزيلات...', size: 64)
                  : _items.isEmpty
                      ? const EmptyState(icon: Icons.download_outlined, title: 'لا توجد تنزيلات', message: 'ستظهر هنا الحلقات والفصول التي تقوم بتنزيلها.')
                      : RefreshIndicator(
                          onRefresh: _refresh,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                            children: [
                              FutureBuilder<int>(future: DownloadService.storageBytes(), builder: (_, snapshot) => _storageSummary(snapshot.data ?? 0)),
                              if (active.isNotEmpty) _section('قيد التنزيل أو الانتظار', active),
                              if (completed.isNotEmpty) _section('اكتملت', completed),
                              if (failed.isNotEmpty) _section('تحتاج إلى إجراء', failed),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _storageSummary(int bytes) {
    final mb = bytes / (1024 * 1024);
    final label = mb >= 1024 ? '${(mb / 1024).toStringAsFixed(1)} GB' : '${mb.toStringAsFixed(1)} MB';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderColor)),
      child: Row(children: [const Icon(Icons.storage_rounded, color: AppTheme.primaryColor), const SizedBox(width: 10), Text('مساحة تنزيلات AniTV: $label', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)), const Spacer(), Text('${_items.where((e) => e['status'] == 'completed').length} ملف', style: const TextStyle(color: AppTheme.textSecondaryColor))]),
    );
  }

  Widget _section(String title, List<Map<String, dynamic>> items) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.only(bottom: 9), child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800))), ...items.map(_taskCard), const SizedBox(height: 12)]);
  }

  Widget _taskCard(Map<String, dynamic> item) {
    final status = item['status']?.toString() ?? 'queued';
    final progress = (item['progress'] is num ? (item['progress'] as num).toDouble() : 0).clamp(0, 1);
    final bytes = (item['bytes'] is num ? (item['bytes'] as num).toInt() : 0);
    final total = (item['total'] is num ? (item['total'] as num).toInt() : 0);
    final isManga = item['kind'] == 'manga';
    final path = item['path']?.toString() ?? '';
    final exists = isManga ? Directory(path).existsSync() : File(path).existsSync();
    final playable = status == 'completed' && exists;
    final id = item['id']?.toString() ?? '';
    final title = item['episode']?.toString().isNotEmpty == true ? item['episode'].toString() : item['chapter']?.toString() ?? item['title']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderColor)),
      child: Column(children: [
        Row(children: [PosterImage(url: item['cover_url']?.toString(), width: 54, height: 70, fallbackIcon: isManga ? Icons.menu_book : Icons.movie_outlined, borderRadius: BorderRadius.circular(9)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item['title']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), const SizedBox(height: 5), Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12)), const SizedBox(height: 7), _statusLine(status, progress)])), if (playable) IconButton(onPressed: () => _open(item, isManga), tooltip: 'تشغيل بدون اتصال', icon: const Icon(Icons.play_circle_fill_rounded, color: AppTheme.primaryColor))]),
        if (status == 'downloading' || status == 'paused' || status == 'queued') ...[
          const SizedBox(height: 9),
          LinearProgressIndicator(value: total > 0 ? progress : null, minHeight: 5, borderRadius: BorderRadius.circular(5), color: AppTheme.primaryColor),
          const SizedBox(height: 5),
          Row(children: [Text('${(progress * 100).round()}%', style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11)), if (total > 0) Text('  ${_formatBytes(bytes)} / ${_formatBytes(total)}', style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11)), const Spacer(), if (status == 'paused') IconButton(onPressed: () => DownloadService.resumeTask(id), icon: const Icon(Icons.play_arrow_rounded, color: Colors.white)), if (status != 'paused') IconButton(onPressed: () => DownloadService.pauseTask(id), icon: const Icon(Icons.pause_rounded, color: Colors.white)), IconButton(onPressed: () => DownloadService.cancelTask(id), icon: const Icon(Icons.close_rounded, color: Colors.orange))]),
        ],
        if (status == 'failed' || status == 'cancelled' || (status == 'completed' && !exists)) Row(children: [Expanded(child: Text(item['error']?.toString().isNotEmpty == true ? item['error'].toString() : 'الملف غير موجود أو فشل التنزيل', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.orange, fontSize: 11))), TextButton(onPressed: () => DownloadService.retry(id), child: const Text('إعادة المحاولة'))]),
        if (status == 'completed') Align(alignment: AlignmentDirectional.centerEnd, child: TextButton.icon(onPressed: () => DownloadService.delete(id), icon: const Icon(Icons.delete_outline, size: 18), label: const Text('حذف'))),
      ]),
    );
  }

  Widget _statusLine(String status, double progress) {
    final text = {'queued': 'في قائمة الانتظار', 'downloading': 'جارٍ التنزيل', 'paused': 'متوقف مؤقتًا', 'completed': 'تم التنزيل', 'failed': 'فشل التنزيل', 'cancelled': 'تم الإلغاء'}[status] ?? status;
    final color = status == 'completed' ? Colors.greenAccent : status == 'failed' || status == 'cancelled' ? Colors.orange : AppTheme.primaryColor;
    return Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700));
  }

  String _formatBytes(int value) {
    if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(0)} KB';
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _open(Map<String, dynamic> item, bool isManga) async {
    final path = item['path']?.toString() ?? '';
    if (isManga) {
      final directory = Directory(path);
      if (!directory.existsSync()) return;
      final files = directory.listSync().whereType<File>().where((file) => file.path.toLowerCase().endsWith('.jpg')).toList()..sort((a, b) => a.path.compareTo(b.path));
      if (!mounted || files.isEmpty) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => MangaReaderScreen(pages: files.map((file) => file.path).toList(), title: item['chapter']?.toString(), chapterId: item['chapter']?.toString(), comicImageUrl: item['cover_url']?.toString())));
    } else if (File(path).existsSync() && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerScreen(url: path, title: item['episode']?.toString() ?? 'حلقة', episodeId: path)));
    }
  }
}
