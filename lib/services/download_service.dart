import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadService {
  static const _key = 'anitv_downloads';

  static Future<List<Map<String, dynamic>>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key) ?? '[]';
    final decoded = jsonDecode(raw);
    return decoded is List ? decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
  }

  static Future<void> _add(Map<String, dynamic> entry) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await list();
    entries.removeWhere((item) => item['id'] == entry['id']);
    entries.insert(0, entry);
    await prefs.setString(_key, jsonEncode(entries));
  }

  static Future<String> saveMangaChapter({required String mangaTitle, required String chapterTitle, required List<String> imageUrls}) async {
    final root = await getApplicationDocumentsDirectory();
    final safe = _safe('$mangaTitle-$chapterTitle');
    final folder = Directory('${root.path}/AniTV/Downloads/Manga/$safe')..createSync(recursive: true);
    var saved = 0;
    for (var i = 0; i < imageUrls.length; i++) {
      final response = await http.get(Uri.parse(imageUrls[i]));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await File('${folder.path}/${(i + 1).toString().padLeft(3, '0')}.jpg').writeAsBytes(response.bodyBytes);
        saved++;
      }
    }
    if (saved == 0) throw Exception('لم يتم حفظ أي صورة');
    await _add({'id': 'manga:${folder.path}', 'kind': 'manga', 'title': mangaTitle, 'chapter': chapterTitle, 'path': folder.path, 'timestamp': DateTime.now().toIso8601String()});
    return folder.path;
  }

  static Future<String> saveAnimeEpisode({required String animeTitle, required String episodeTitle, required String url}) async {
    final root = await getApplicationDocumentsDirectory();
    final folder = Directory('${root.path}/AniTV/Downloads/Anime')..createSync(recursive: true);
    final name = _safe('$animeTitle-$episodeTitle');
    final file = File('${folder.path}/$name.mp4');
    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('تعذر تنزيل الحلقة');
    await file.writeAsBytes(response.bodyBytes);
    await _add({'id': 'anime:${file.path}', 'kind': 'anime', 'title': animeTitle, 'episode': episodeTitle, 'path': file.path, 'timestamp': DateTime.now().toIso8601String()});
    return file.path;
  }

  static String _safe(String value) => value.replaceAll(RegExp(r'[^a-zA-Z0-9\u0600-\u06FF._-]+'), '_').substring(0, value.length > 100 ? 100 : value.length);
}
