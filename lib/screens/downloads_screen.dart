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
    final active = _items.where((item) => !{'completed', 'cancelled', 'failed'}.contains(item['status'])).toList();
    final completed = _items.where((item) => item['status'] == 'completed').toList();
    final failed = _items.where((item) => item['status'] == 'failed' || item['status'] == 'cancelled').toList();
    final paused = _items.where((item) => {'paused', 'queued', 'waiting', 'retrying'}.contains(item['status'])).length;
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
                              _dashboardSummary(active.length, completed.length, paused, failed.length),
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

  Widget _dashboardSummary(int active, int completed, int paused, int failed) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTheme.borderColor)),
        child: Row(children: [_stat('نشطة', active, AppTheme.primaryColor), _stat('مكتملة', completed, Colors.greenAccent), _stat('معلقة', paused, Colors.amber), _stat('فشل', failed, Colors.orangeAccent)]),
      );

  Widget _stat(String label, int value, Color color) => Expanded(child: Column(children: [Text('$value', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(label, style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11))]));

  Widget _section(String title, List<Map<String, dynamic>> items) {
    final mangaGroups = <String, List<Map<String, dynamic>>>{};
    final standalone = <Map<String, dynamic>>[];
    for (final item in items) {
      if (item['kind'] == 'manga') {
        (mangaGroups[item['title']?.toString() ?? 'مانجا'] ??= []).add(item);
      } else {
        standalone.add(item);
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(bottom: 9), child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800))),
      ...mangaGroups.entries.map((group) => _mangaGroup(group.key, group.value)),
      ...standalone.map(_taskCard),
      const SizedBox(height: 12),
    ]);
  }

  Widget _mangaGroup(String title, List<Map<String, dynamic>> chapters) {
    chapters.sort((a, b) => (a['chapter']?.toString() ?? '').compareTo(b['chapter']?.toString() ?? ''));
    final cover = chapters.first['cover_url']?.toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [PosterImage(url: cover, width: 46, height: 58, fallbackIcon: Icons.menu_book, borderRadius: BorderRadius.circular(8)), const SizedBox(width: 10), Expanded(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))), Text('${chapters.length} فصل', style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12))]),
        const SizedBox(height: 8),
        ...chapters.map(_taskCard),
      ]),
    );
  }

  Widget _taskCard(Map<String, dynamic> item) {
    final status = item['status']?.toString() ?? 'queued';
    final progress = (item['progress'] is num ? (item['progress'] as num).toDouble() : 0.0).clamp(0.0, 1.0).toDouble();
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
          Row(children: [Text(total > 0 ? '${(progress * 100).round()}%' : _formatBytes(bytes), style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11)), if (total > 0) Text('  ${_formatBytes(bytes)} / ${_formatBytes(total)}', style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11)), if (item['speed'] is num && (item['speed'] as num) > 0) Text('  ${_formatSpeed((item['speed'] as num).toInt())}', style: const TextStyle(color: AppTheme.primaryColor, fontSize: 11)), if (item['eta_seconds'] is num && (item['eta_seconds'] as num) > 0) Text('  ${_formatEta((item['eta_seconds'] as num).toInt())}', style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11)), const Spacer(), if (status == 'paused') IconButton(onPressed: () => DownloadService.resumeTask(id), icon: const Icon(Icons.play_arrow_rounded, color: Colors.white)), if (status != 'paused') IconButton(onPressed: () => DownloadService.pauseTask(id), icon: const Icon(Icons.pause_rounded, color: Colors.white)), IconButton(onPressed: () => DownloadService.cancelTask(id), icon: const Icon(Icons.close_rounded, color: Colors.orange))]),
        ],
        if (status == 'failed' || status == 'cancelled' || (status == 'completed' && !exists)) Row(children: [Expanded(child: Text(item['error']?.toString().isNotEmpty == true ? item['error'].toString() : 'الملف غير موجود أو فشل التنزيل', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.orange, fontSize: 11))), TextButton.icon(onPressed: () => DownloadService.retry(id), icon: const Icon(Icons.refresh, size: 17), label: const Text('إعادة المحاولة'))]),
        if (status == 'completed') Align(alignment: AlignmentDirectional.centerEnd, child: TextButton.icon(onPressed: () => _confirmDelete(id), icon: const Icon(Icons.delete_outline, size: 18), label: const Text('حذف'))),
      ]),
    );
  }

  Widget _statusLine(String status, double progress) {
    final text = {'queued': 'في قائمة الانتظار', 'waiting': 'بانتظار الاتصال', 'retrying': 'إعادة المحاولة', 'downloading': 'جارٍ التنزيل', 'paused': 'متوقف مؤقتًا', 'completed': 'تم التنزيل', 'failed': 'فشل التنزيل', 'cancelled': 'تم الإلغاء'}[status] ?? status;
    final color = status == 'completed' ? Colors.greenAccent : status == 'failed' || status == 'cancelled' ? Colors.orange : AppTheme.primaryColor;
    return Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700));
  }

  String _formatBytes(int value) {
    if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(0)} KB';
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatSpeed(int value) => value <= 0 ? '' : '${_formatBytes(value)}/ث';
  String _formatEta(int seconds) => seconds <= 0 ? '' : seconds < 60 ? 'متبقي ${seconds}ث' : 'متبقي ${(seconds / 60).ceil()}د';

  Future<void> _confirmDelete(String id) async {
    final confirmed = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('حذف هذا التنزيل؟'), content: const Text('سيتم حذف ملف التنزيل فقط ولن تتأثر المفضلة أو سجل المشاهدة.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف'))]));
    if (confirmed == true) await DownloadService.delete(id);
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
