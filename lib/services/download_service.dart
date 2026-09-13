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
    final root = await getApplicationDocumentsDirectory();
    final series = _safe(mangaTitle);
    final folder = Directory('${root.path}/AniTV/Downloads/Manga/$series/${_safe(chapterTitle)}')
      ..createSync(recursive: true);
    var saved = 0;
    await _notify('جارٍ تنزيل $mangaTitle', chapterTitle, 0, imageUrls.length);
    for (var i = 0; i < imageUrls.length; i++) {
      final response = await http.get(Uri.parse(imageUrls[i]));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await File('${folder.path}/${(i + 1).toString().padLeft(3, '0')}.jpg').writeAsBytes(response.bodyBytes);
        saved++;
        await _notify('جارٍ تنزيل $mangaTitle', chapterTitle, saved, imageUrls.length);
      }
    }
    if (saved == 0) throw Exception('لم يتم حفظ أي صورة');
    await _notify('تم التنزيل $mangaTitle', chapterTitle, saved, imageUrls.length, complete: true);
    await _add({
      'id': 'manga:${folder.path}', 'kind': 'manga', 'title': mangaTitle,
      'chapter': chapterTitle, 'path': folder.path, 'cover_url': coverUrl,
      'source_id': sourceId, 'timestamp': DateTime.now().toIso8601String(),
    });
    return folder.path;
  }

  static Future<String> saveAnimeEpisode({
    required String animeTitle,
    required String episodeTitle,
    required String url,
    String coverUrl = '',
    String sourceId = '',
  }) async {
    final root = await getApplicationDocumentsDirectory();
    final series = _safe(animeTitle);
    final folder = Directory('${root.path}/AniTV/Downloads/Anime/$series')..createSync(recursive: true);
    final file = File('${folder.path}/${_safe(episodeTitle)}.mp4');
    final request = http.Request('GET', Uri.parse(url));
    final client = http.Client();
    final response = await client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('تعذر تنزيل الحلقة');
    final sink = file.openWrite();
    var received = 0;
    final total = response.contentLength ?? 0;
    await _notify('بدء التنزيل', animeTitle, 0, total);
    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      await _notify('جارٍ تنزيل $animeTitle', episodeTitle, received, total);
    }
    await sink.close();
    client.close();
    await _notify('تم التنزيل $animeTitle', episodeTitle, received, total, complete: true);
    await _add({
      'id': 'anime:${file.path}', 'kind': 'anime', 'title': animeTitle,
      'episode': episodeTitle, 'path': file.path, 'cover_url': coverUrl,
      'source_id': sourceId, 'timestamp': DateTime.now().toIso8601String(),
    });
    return file.path;
  }

  static Future<bool> sendToAdm(String url, {String? title}) async {
    if (url.isEmpty) return false;
    try {
      return await _channel.invokeMethod<bool>('sendToAdm', {'url': url, 'title': title ?? ''}) ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> _notify(String title, String body, int progress, int total, {bool complete = false}) async {
    try {
      await _channel.invokeMethod('downloadNotification', {
        'title': title, 'body': body, 'progress': progress, 'total': total, 'complete': complete,
      });
    } catch (_) {}
  }

  static String _safe(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^a-zA-Z0-9\u0600-\u06FF._-]+'), '_');
    return cleaned.substring(0, cleaned.length > 100 ? 100 : cleaned.length);
  }
}
