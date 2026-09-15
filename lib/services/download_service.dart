import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadService {
  static const _key = 'anitv_downloads';
  static const _channel = MethodChannel('com.anitv.app/downloads');
  static Future<void> _writeQueue = Future<void>.value();
  static final Set<String> _paused = <String>{};
  static final Set<String> _cancelled = <String>{};

  static void initialize() {
    _channel.setMethodCallHandler((call) async {
      final args = call.arguments is Map ? call.arguments as Map : const {};
      final taskId = args['taskId']?.toString() ?? '';
      if (taskId.isEmpty) return false;
      if (call.method == 'pauseDownload') pause(taskId);
      if (call.method == 'resumeDownload') resume(taskId);
      if (call.method == 'cancelDownload') cancel(taskId);
      return true;
    });
  }

  static void pause(String taskId) => _paused.add(taskId);
  static void resume(String taskId) => _paused.remove(taskId);
  static void cancel(String taskId) {
    _cancelled.add(taskId);
    _paused.remove(taskId);
  }
  static bool isPaused(String taskId) => _paused.contains(taskId);
  static bool isCancelled(String taskId) => _cancelled.contains(taskId);
  static void _finish(String taskId) {
    _paused.remove(taskId);
    _cancelled.remove(taskId);
  }

  static Future<List<Map<String, dynamic>>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key) ?? '[]';
    final decoded = jsonDecode(raw);
    return decoded is List
        ? decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
  }

  static Future<void> _add(Map<String, dynamic> entry) async {
    _writeQueue = _writeQueue.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key) ?? '[]';
      final decoded = jsonDecode(raw);
      final entries = decoded is List ? decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];
      entries.removeWhere((item) => item['id'] == entry['id']);
      entries.insert(0, entry);
      await prefs.setString(_key, jsonEncode(entries));
    });
    await _writeQueue;
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
    final series = _safe(mangaTitle);
    final folder = Directory('${root.path}/AniTV/Downloads/Manga/$series/${_safe(chapterTitle)}')..createSync(recursive: true);
    var saved = 0;
    try {
      await _notify('جارٍ تنزيل $mangaTitle', chapterTitle, 0, imageUrls.length, taskId: taskId);
      for (var i = 0; i < imageUrls.length; i++) {
        while (isPaused(taskId) && !isCancelled(taskId)) {
          await _notify('التنزيل متوقف مؤقتًا', chapterTitle, saved, imageUrls.length, taskId: taskId, paused: true);
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
        if (isCancelled(taskId)) {
          await folder.delete(recursive: true);
          throw const DownloadCancelledException();
        }
        final response = await http.get(Uri.parse(imageUrls[i]));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          await File('${folder.path}/${(i + 1).toString().padLeft(3, '0')}.jpg').writeAsBytes(response.bodyBytes);
          saved++;
          await _notify('جارٍ تنزيل $mangaTitle', chapterTitle, saved, imageUrls.length, taskId: taskId);
        }
      }
      if (saved == 0) throw Exception('لم يتم حفظ أي صورة');
      await _notify('تم التنزيل $mangaTitle', chapterTitle, saved, imageUrls.length, taskId: taskId, complete: true);
      await _add({
        'id': 'manga:${folder.path}', 'kind': 'manga', 'title': mangaTitle,
        'chapter': chapterTitle, 'path': folder.path, 'cover_url': coverUrl,
        'source_id': sourceId, 'timestamp': DateTime.now().toIso8601String(),
      });
      return folder.path;
    } finally {
      _finish(taskId);
    }
  }

  static Future<bool> hasMangaChapter({
    required String mangaTitle,
    required String chapterTitle,
  }) async {
    final root = await getApplicationDocumentsDirectory();
    final folder = Directory('${root.path}/AniTV/Downloads/Manga/${_safe(mangaTitle)}/${_safe(chapterTitle)}');
    if (!folder.existsSync()) return false;
    return folder.listSync().whereType<File>().isNotEmpty;
  }

  static Future<String> saveAnimeEpisode({
    required String animeTitle,
    required String episodeTitle,
    required String url,
    String coverUrl = '',
    String sourceId = '',
  }) async {
    final taskId = 'anime:${_safe(animeTitle)}/${_safe(episodeTitle)}';
    final root = await getApplicationDocumentsDirectory();
    final series = _safe(animeTitle);
    final folder = Directory('${root.path}/AniTV/Downloads/Anime/$series')..createSync(recursive: true);
    final file = File('${folder.path}/${_safe(episodeTitle)}.mp4');
    final request = http.Request('GET', Uri.parse(url));
    final client = http.Client();
    try {
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('تعذر تنزيل الحلقة');
      final sink = file.openWrite();
      var received = 0;
      final total = response.contentLength ?? 0;
      await _notify('بدء التنزيل', animeTitle, 0, total, taskId: taskId);
      await for (final chunk in response.stream) {
        while (isPaused(taskId) && !isCancelled(taskId)) {
          await _notify('التنزيل متوقف مؤقتًا', episodeTitle, received, total, taskId: taskId, paused: true);
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
        if (isCancelled(taskId)) {
          await sink.close();
          await file.delete().catchError((_) {});
          throw const DownloadCancelledException();
        }
        sink.add(chunk);
        received += chunk.length;
        await _notify('جارٍ تنزيل $animeTitle', episodeTitle, received, total, taskId: taskId);
      }
      await sink.close();
      await _notify('تم التنزيل $animeTitle', episodeTitle, received, total, taskId: taskId, complete: true);
      await _add({
        'id': 'anime:${file.path}', 'kind': 'anime', 'title': animeTitle,
        'episode': episodeTitle, 'path': file.path, 'cover_url': coverUrl,
        'source_id': sourceId, 'timestamp': DateTime.now().toIso8601String(),
      });
      return file.path;
    } finally {
      client.close();
      _finish(taskId);
    }
  }

  static Future<bool> sendToAdm(String url, {String? title}) async {
    if (url.isEmpty) return false;
    try {
      return await _channel.invokeMethod<bool>('sendToAdm', {'url': url, 'title': title ?? ''}) ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> _notify(String title, String body, int progress, int total, {bool complete = false, String taskId = '', bool paused = false}) async {
    try {
      await _channel.invokeMethod('downloadNotification', {
        'title': title, 'body': body, 'progress': progress, 'total': total, 'complete': complete, 'taskId': taskId, 'paused': paused,
      });
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
