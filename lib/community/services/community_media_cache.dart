import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/community_models.dart';
import 'community_media_api.dart';

/// Persistent on-device cache for Community media.
/// B2 URLs are short-lived, so the URL is refreshed only when the local file
/// is missing or older than the configured TTL.
class CommunityMediaCache {
  CommunityMediaCache._();
  static final instance = CommunityMediaCache._();
  static const _ttl = Duration(days: 7);
  static const _indexFile = 'community_media_cache_v1.json';
  final Map<String, Future<File>> _inFlight = {};

  Future<File> get(PostMedia media) {
    final existing = _inFlight[media.id];
    if (existing != null) return existing;
    final request = _get(media);
    _inFlight[media.id] = request;
    request.whenComplete(() => _inFlight.remove(media.id));
    return request;
  }

  Future<File> _get(PostMedia media) async {
    if (media.isLocal) return File(media.path);
    final directory = await getApplicationSupportDirectory();
    final folder = Directory('${directory.path}/community_media');
    await folder.create(recursive: true);
    final index = await _readIndex();
    final cached = index[media.id];
    if (cached is Map) {
      final path = cached['path']?.toString() ?? '';
      final savedAt = DateTime.tryParse(cached['savedAt']?.toString() ?? '');
      final file = File(path);
      if (path.isNotEmpty && savedAt != null && await file.exists() &&
          DateTime.now().toUtc().difference(savedAt) < _ttl) {
        return file;
      }
    }

    final url = media.url ?? await CommunityMediaApi().secureUrl(media);
    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const StorageError('The media could not be downloaded.');
    }
    final extension = media.type == MediaType.image ? 'img' : 'audio';
    final file = File('${folder.path}/${_safe(media.id)}.$extension');
    await file.writeAsBytes(response.bodyBytes, flush: true);
    index[media.id] = {
      'path': file.path,
      'savedAt': DateTime.now().toUtc().toIso8601String(),
    };
    await _writeIndex(index);
    return file;
  }

  Future<Map<String, dynamic>> _readIndex() async {
    try {
      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/$_indexFile');
      if (!await file.exists()) return {};
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeIndex(Map<String, dynamic> index) async {
    try {
      final directory = await getApplicationSupportDirectory();
      await File('${directory.path}/$_indexFile')
          .writeAsString(jsonEncode(index), flush: true);
    } catch (_) {}
  }

  String _safe(String value) => value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  Future<void> clear(String mediaId) async {
    final index = await _readIndex();
    final item = index.remove(mediaId);
    if (item is Map) {
      final path = item['path']?.toString();
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
    }
    await _writeIndex(index);
  }
}
