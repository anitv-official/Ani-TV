import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central download manager. Sources only provide a final media URL; this
/// service owns queueing, persistence, storage, progress and notifications.
class DownloadService {
  static const _key = 'anitv_downloads';
  static const _channel = MethodChannel('com.anitv.app/downloads');
  static const int maxConcurrentDownloads = 2;
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);
  static final Set<String> _paused = <String>{};
  static final Set<String> _cancelled = <String>{};
  static final Map<String, Future<void>> _running = <String, Future<void>>{};
  static final Map<String, Completer<String>> _waiters = <String, Completer<String>>{};
  static Future<void> _writeQueue = Future<void>.value();
  static bool _initialized = false;
  static bool _pumping = false;

  static void initialize() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      final args = call.arguments is Map ? call.arguments as Map : const {};
      final taskId = args['taskId']?.toString() ?? '';
      if (taskId.isEmpty) return false;
      if (call.method == 'pauseDownload') await pauseTask(taskId);
      if (call.method == 'resumeDownload') await resumeTask(taskId);
      if (call.method == 'cancelDownload') await cancelTask(taskId);
      return true;
    });
    unawaited(_recoverInterruptedTasks());
  }

  static Future<void> _recoverInterruptedTasks() async {
    final entries = await list();
    var changed = false;
    for (final entry in entries) {
      if (entry['status'] == 'downloading') {
        entry['status'] = 'paused';
        entry['error'] = 'تم إيقاف التنزيل مؤقتًا بعد إغلاق التطبيق';
        changed = true;
      }
      final path = entry['path']?.toString() ?? '';
      if (entry['status'] == 'completed' && path.isNotEmpty && !File(path).existsSync()) {
        entry['status'] = 'failed';
        entry['error'] = 'الملف غير موجود على الجهاز';
        changed = true;
      }
    }
    if (changed) await _replaceAll(entries);
    _pump();
  }

  static void pause(String taskId) => unawaited(pauseTask(taskId));
  static void resume(String taskId) => unawaited(resumeTask(taskId));
  static void cancel(String taskId) => unawaited(cancelTask(taskId));
  static bool isPaused(String taskId) => _paused.contains(taskId);
  static bool isCancelled(String taskId) => _cancelled.contains(taskId);

  static Future<void> pauseTask(String taskId) async {
    _paused.add(taskId);
    await _update(taskId, {'status': 'paused', 'error': ''});
  }

  static Future<void> resumeTask(String taskId) async {
    _paused.remove(taskId);
    _cancelled.remove(taskId);
    await _update(taskId, {'status': 'queued', 'error': ''});
    _pump();
  }

  static Future<void> cancelTask(String taskId) async {
    _cancelled.add(taskId);
    _paused.remove(taskId);
    await _update(taskId, {'status': 'cancelled'});
    _pump();
  }

  static Future<void> retry(String taskId) async {
    _paused.remove(taskId);
    _cancelled.remove(taskId);
    await _update(taskId, {'status': 'queued', 'error': '', 'bytes': 0, 'progress': 0});
    _pump();
  }

  static Future<List<Map<String, dynamic>>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key) ?? '[]';
    try {
      final decoded = jsonDecode(raw);
      return decoded is List
          ? decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static Future<String?> enqueueMediaDownload({
    required String taskId,
    required String kind,
    required String title,
    required String mediaUrl,
    String episode = '',
    String season = '',
    String coverUrl = '',
    String sourceId = '',
    String quality = '',
    Map<String, String> headers = const {},
  }) async {
    if (mediaUrl.trim().isEmpty) return null;
    final existing = await list();
    final duplicate = existing.where((item) => item['id'] == taskId || item['url'] == mediaUrl).firstOrNull;
    if (duplicate != null) {
      final status = duplicate['status']?.toString();
      if (status == 'failed' || status == 'cancelled') {
        await retry(duplicate['id'].toString());
      }
      return duplicate['id']?.toString();
    }
    final root = await getApplicationDocumentsDirectory();
    final folder = Directory('${root.path}/AniTV/Downloads/${_safe(kind)}/${_safe(title)}')..createSync(recursive: true);
    final filename = '${_safe(episode.isEmpty ? title : episode)}.mp4';
    final path = '${folder.path}/$filename';
    await _add({
      'id': taskId,
      'kind': kind,
      'title': title,
      'season': season,
      'episode': episode,
      'url': mediaUrl,
      'path': path,
      'part_path': '$path.part',
      'cover_url': coverUrl,
      'source_id': sourceId,
      'quality': quality,
      'headers': headers,
      'status': 'queued',
      'progress': 0,
      'bytes': 0,
      'total': 0,
      'speed': 0,
      'error': '',
      'timestamp': DateTime.now().toIso8601String(),
    });
    _pump();
    return taskId;
  }

  static Future<String> waitFor(String taskId) async {
    final entries = await list();
    final current = entries.where((item) => item['id'] == taskId).firstOrNull;
    if (current?['status'] == 'completed') return current!['path'].toString();
    if (current?['status'] == 'failed' || current?['status'] == 'cancelled') {
      throw Exception(current?['error']?.toString() ?? 'فشل التنزيل');
    }
    final waiter = _waiters.putIfAbsent(taskId, Completer<String>.new);
    return waiter.future;
  }

  static Future<void> delete(String taskId) async {
    _cancelled.add(taskId);
    final entries = await list();
    final item = entries.where((entry) => entry['id'] == taskId).firstOrNull;
    if (item != null) {
      for (final key in ['path', 'part_path']) {
        final path = item[key]?.toString() ?? '';
        if (path.isNotEmpty) {
          final file = File(path);
          if (file.existsSync()) await file.delete();
        }
      }
    }
    entries.removeWhere((entry) => entry['id'] == taskId);
    await _replaceAll(entries);
    _completeWaiter(taskId, error: const DownloadCancelledException());
  }

  static Future<int> storageBytes() async {
    var total = 0;
    for (final item in await list()) {
      final path = item['path']?.toString() ?? '';
      final file = File(path);
      if (file.existsSync()) total += file.lengthSync();
    }
    return total;
  }

  static Future<void> clearCompleted() async {
    final entries = await list();
    for (final item in entries.where((item) => item['status'] == 'completed').toList()) {
      await delete(item['id'].toString());
    }
  }

  static void _pump() {
    if (_pumping) return;
    _pumping = true;
    scheduleMicrotask(() async {
      try {
        final entries = await list();
        for (final item in entries) {
          if (_running.length >= maxConcurrentDownloads) break;
          final id = item['id']?.toString() ?? '';
          if (id.isEmpty || _running.containsKey(id) || item['status'] != 'queued') continue;
          final future = _run(item);
          _running[id] = future;
          unawaited(future.whenComplete(() {
            _running.remove(id);
            _pump();
          }));
        }
      } finally {
        _pumping = false;
      }
    });
  }

  static Future<void> _run(Map<String, dynamic> item) async {
    final id = item['id'].toString();
    final path = item['path'].toString();
    final partPath = item['part_path']?.toString() ?? '$path.part';
    final part = File(partPath);
    final target = File(path);
    final headers = <String, String>{};
    final rawHeaders = item['headers'] as Map?;
    rawHeaders?.forEach((key, value) => headers[key.toString()] = value.toString());
    var received = part.existsSync() ? part.lengthSync() : 0;
    final client = http.Client();
    try {
      await _update(id, {'status': 'downloading', 'error': '', 'bytes': received});
      final request = http.Request('GET', Uri.parse(item['url'].toString()));
      request.headers.addAll(headers);
      if (received > 0) request.headers['Range'] = 'bytes=$received-';
      final response = await client.send(request).timeout(const Duration(seconds: 30));
      if (response.statusCode == 416 && target.existsSync()) {
        await _complete(id, path);
        return;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('HTTP ${response.statusCode}');
      final append = received > 0 && response.statusCode == 206;
      if (!append) received = 0;
      final total = (response.contentLength ?? 0) + received;
      final sink = part.openWrite(mode: append ? FileMode.append : FileMode.write);
      var lastTick = DateTime.now();
      var lastBytes = received;
      await _update(id, {'total': total, 'bytes': received, 'progress': _progress(received, total)});
      await _notify('جارٍ التنزيل', item['episode']?.toString() ?? item['title']?.toString() ?? '', received, total, taskId: id);
      await for (final chunk in response.stream.timeout(const Duration(seconds: 30))) {
        while (isPaused(id) && !isCancelled(id)) {
          await _update(id, {'status': 'paused', 'bytes': received, 'progress': _progress(received, total), 'speed': 0});
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
        if (isCancelled(id)) {
          await sink.close();
          throw const DownloadCancelledException();
        }
        sink.add(chunk);
        received += chunk.length;
        final now = DateTime.now();
        final elapsed = now.difference(lastTick).inMilliseconds;
        if (elapsed >= 500) {
          final speed = ((received - lastBytes) * 1000 / elapsed).round();
          await _update(id, {'status': 'downloading', 'bytes': received, 'total': total, 'progress': _progress(received, total), 'speed': speed});
          await _notify('جارٍ التنزيل', item['episode']?.toString() ?? item['title']?.toString() ?? '', received, total, taskId: id);
          lastTick = now;
          lastBytes = received;
        }
      }
      await sink.close();
      if (total > 0 && received < total) throw Exception('الملف غير مكتمل');
      if (received == 0) throw Exception('الملف فارغ');
      if (target.existsSync()) await target.delete();
      await part.rename(path);
      await _complete(id, path);
    } on DownloadCancelledException catch (error) {
      await _update(id, {'status': 'cancelled', 'error': 'تم إلغاء التنزيل'});
      _completeWaiter(id, error: error);
    } catch (error) {
      await _update(id, {'status': 'failed', 'error': error.toString()});
      await _notify('فشل التنزيل', item['episode']?.toString() ?? item['title']?.toString() ?? '', 0, 0, taskId: id, failed: true);
      _completeWaiter(id, error: error);
    } finally {
      client.close();
      _paused.remove(id);
      _cancelled.remove(id);
    }
  }

  static Future<void> _complete(String id, String path) async {
    final entries = await list();
    final item = entries.where((entry) => entry['id'] == id).firstOrNull;
    final bytes = File(path).existsSync() ? File(path).lengthSync() : 0;
    await _update(id, {'status': 'completed', 'progress': 1, 'bytes': bytes, 'total': bytes, 'speed': 0, 'error': '', 'completed_at': DateTime.now().toIso8601String()});
    if (item != null) {
      await _notify('اكتمل التنزيل', item['episode']?.toString() ?? item['title']?.toString() ?? '', bytes, bytes, taskId: id, complete: true);
    }
    _completeWaiter(id, path: path);
  }

  static double _progress(int bytes, int total) => total > 0 ? (bytes / total).clamp(0, 1).toDouble() : 0;

  static void _completeWaiter(String id, {String? path, Object? error}) {
    final waiter = _waiters.remove(id);
    if (waiter == null || waiter.isCompleted) return;
    if (error != null) waiter.completeError(error);
    else waiter.complete(path!);
  }

  static Future<void> _update(String id, Map<String, dynamic> values) async {
    final entries = await list();
    final index = entries.indexWhere((entry) => entry['id'] == id);
    if (index == -1) return;
    entries[index].addAll(values);
    await _replaceAll(entries, notify: true);
  }

  static Future<void> _add(Map<String, dynamic> entry) async {
    final entries = await list();
    entries.removeWhere((item) => item['id'] == entry['id']);
    entries.insert(0, entry);
    await _replaceAll(entries);
  }

  static Future<void> _replaceAll(List<Map<String, dynamic>> entries, {bool notify = true}) async {
    _writeQueue = _writeQueue.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(entries));
      if (notify) changes.value++;
    });
    await _writeQueue;
  }

  static Future<String> saveAnimeEpisode({
    required String animeTitle,
    required String episodeTitle,
    required String url,
    String coverUrl = '',
    String sourceId = '',
    Map<String, String> headers = const {},
  }) async {
    final id = 'anime:${_safe(animeTitle)}/${_safe(episodeTitle)}';
    await enqueueMediaDownload(taskId: id, kind: 'Anime', title: animeTitle, episode: episodeTitle, mediaUrl: url, coverUrl: coverUrl, sourceId: sourceId, headers: headers);
    return waitFor(id);
  }

  static Future<bool> hasMangaChapter({required String mangaTitle, required String chapterTitle}) async {
    final root = await getApplicationDocumentsDirectory();
    final folder = Directory('${root.path}/AniTV/Downloads/Manga/${_safe(mangaTitle)}/${_safe(chapterTitle)}');
    return folder.existsSync() && folder.listSync().whereType<File>().isNotEmpty;
  }

  static Future<String> saveMangaChapter({
    required String mangaTitle,
    required String chapterTitle,
    required List<String> imageUrls,
    String coverUrl = '',
    String sourceId = '',
  }) async {
    final taskId = 'manga:${_safe(mangaTitle)}/${_safe(chapterTitle)}';
    final root = await getApplicationDocumentsDirectory();
    final folder = Directory('${root.path}/AniTV/Downloads/Manga/${_safe(mangaTitle)}/${_safe(chapterTitle)}')..createSync(recursive: true);
    var saved = 0;
    try {
      await _add({'id': taskId, 'kind': 'manga', 'title': mangaTitle, 'chapter': chapterTitle, 'path': folder.path, 'cover_url': coverUrl, 'source_id': sourceId, 'status': 'downloading', 'progress': 0, 'bytes': 0, 'total': imageUrls.length, 'error': '', 'timestamp': DateTime.now().toIso8601String()});
      await _notify('جارٍ تنزيل $mangaTitle', chapterTitle, 0, imageUrls.length, taskId: taskId);
      for (var i = 0; i < imageUrls.length; i++) {
        while (isPaused(taskId) && !isCancelled(taskId)) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
        if (isCancelled(taskId)) throw const DownloadCancelledException();
        final response = await http.get(Uri.parse(imageUrls[i]));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          await File('${folder.path}/${(i + 1).toString().padLeft(3, '0')}.jpg').writeAsBytes(response.bodyBytes);
          saved++;
          await _update(taskId, {'status': 'downloading', 'progress': saved / imageUrls.length, 'bytes': saved, 'total': imageUrls.length});
          await _notify('جارٍ تنزيل $mangaTitle', chapterTitle, saved, imageUrls.length, taskId: taskId);
        }
      }
      if (saved == 0) throw Exception('لم يتم حفظ أي صورة');
      await _add({'id': taskId, 'kind': 'manga', 'title': mangaTitle, 'chapter': chapterTitle, 'path': folder.path, 'cover_url': coverUrl, 'source_id': sourceId, 'status': 'completed', 'progress': 1, 'bytes': folder.listSync().whereType<File>().fold<int>(0, (sum, file) => sum + file.lengthSync()), 'total': imageUrls.length, 'timestamp': DateTime.now().toIso8601String()});
      return folder.path;
    } catch (error) {
      await _update(taskId, {'status': error is DownloadCancelledException ? 'cancelled' : 'failed', 'error': error.toString()});
      rethrow;
    } finally {
      _finish(taskId);
    }
  }

  static void _finish(String taskId) {
    _paused.remove(taskId);
    _cancelled.remove(taskId);
  }

  static Future<bool> sendToAdm(String url, {String? title}) async {
    if (url.isEmpty) return false;
    try {
      return await _channel.invokeMethod<bool>('sendToAdm', {'url': url, 'title': title ?? ''}) ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> _notify(String title, String body, int progress, int total, {bool complete = false, bool failed = false, String taskId = '', bool paused = false}) async {
    try {
      await _channel.invokeMethod('downloadNotification', {'title': title, 'body': body, 'progress': progress, 'total': total, 'complete': complete, 'failed': failed, 'taskId': taskId, 'paused': paused});
    } catch (_) {}
  }

  static String _safe(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^a-zA-Z0-9\u0600-\u06FF._-]+'), '_');
    final safe = cleaned.replaceAll(RegExp(r'^[_ .-]+|[_ .-]+$'), '');
    if (safe.isEmpty) return 'untitled';
    return safe.substring(0, safe.length > 100 ? 100 : safe.length);
  }
}

class DownloadCancelledException implements Exception {
  const DownloadCancelledException();
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
