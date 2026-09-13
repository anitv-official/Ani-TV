import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:http/http.dart' as http;

class AnimeSlayerApi {
  static const base = 'https://anslayer.com/anime/public/';
  static const _clientId = 'android-app2';
  // Secrets must be supplied by a trusted proxy/build environment. Values
  // are intentionally absent from source control and the default APK.
  static const _clientSecret = String.fromEnvironment('ANISLAYER_CLIENT_SECRET');
  static const _certSha1 = '44D8B79265DDBB9C887320F64521A76D72F6D7D4';
  static const _backupPassword = String.fromEnvironment('ANISLAYER_BACKUP_PASSWORD');
  static final _client = http.Client();

  static Map<String, String> get _headers => {
        'Client-Id': _clientId,
        if (_clientSecret.isNotEmpty) 'Client-Secret': _clientSecret,
        'Accept': 'application/json',
        'User-Agent': 'okhttp/3.12.12',
      };

  static Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    final uri = Uri.parse('$base$path').replace(queryParameters: query);
    final response = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('Anime Slayer request failed');
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  static Future<dynamic> _post(String path, Map<String, dynamic> payload) async {
    final response = await _client.post(
      Uri.parse('$base$path'),
      headers: {..._headers, 'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'json': jsonEncode(payload)},
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('Anime Slayer server request failed');
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  static Future<List<Map<String, dynamic>>> search(String query, {int offset = 0}) async {
    final payload = {'list_type': 'anime_list', 'anime_name': query.trim(), '_offset': offset, '_limit': 30};
    final json = await _get('animes/get-published-animes', {'json': jsonEncode(payload)});
    return _records(json).map(_mapAnime).where((item) => item['title'].toString().isNotEmpty).toList();
  }

  static Future<List<Map<String, dynamic>>> latest({int offset = 0}) async {
    final json = await _get('animes/get-published-animes', {
      'json': jsonEncode({'list_type': 'latest_episodes', '_offset': offset, '_limit': 30}),
    });
    return _records(json).map(_mapAnime).toList();
  }

  static Future<Map<String, dynamic>> details(int animeId) async {
    final json = await _get('anime/get-anime-details', {
      'anime_id': '$animeId',
      'fetch_episodes': 'Yes',
      'more_info': 'Yes',
    });
    final root = _response(json);
    final raw = root is Map && root['anime'] is Map ? root['anime'] : root;
    final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final info = data['more_info_result'] is Map ? Map<String, dynamic>.from(data['more_info_result']) : <String, dynamic>{};
    final rawEpisodes = data['episodes'] is Map ? data['episodes']['data'] : data['episodes'];
    final episodes = rawEpisodes is List ? rawEpisodes.whereType<Map>().map((e) => _mapEpisode(e, animeId)).toList() : <Map<String, dynamic>>[];
    final title = _text(data['anime_name']);
    final description = _text(data['anime_description']);
    return {
      'title': title,
      'url': _detailUrl(animeId),
      'image_url': _text(data['anime_cover_image_full_url']).isNotEmpty ? _text(data['anime_cover_image_full_url']) : _text(data['anime_cover_image_url']),
      'banner_image_url': _text(data['anime_banner_image_url']),
      'type': 'anime',
      'category': 'anime',
      'source': 'Anime Slayer',
      'source_id': 'anime_slayer',
      'genres': _splitList(data['anime_genres']),
      'description': description,
      'synopsis': description,
      'rating': _text(data['anime_rating']).isNotEmpty ? _text(data['anime_rating']) : _text(info['score']),
      'english_title': _text(data['anime_english_title']),
      'status': _text(data['anime_status']),
      'release_year': _text(data['anime_release_year']),
      'release_day': _text(data['anime_release_day']),
      'studios': _text(info['anime_studios']),
      'episodes': episodes,
      'total_episodes': episodes.length,
      'anime_id': animeId,
    };
  }

  static Future<Map<String, dynamic>?> streams(int animeId, int episodeId) async {
    final json = await _post('episodes/get-episodes-new', {'anime_id': animeId, 'episode_ids': [episodeId], 'limit': 1});
    final records = _findEpisodes(json);
    final episode = records.firstWhere((e) => _toInt(e['episode_id']) == episodeId, orElse: () => records.isEmpty ? <String, dynamic>{} : records.first);
    final urls = episode['episode_urls'] is List ? episode['episode_urls'] : const [];
    final servers = <Map<String, dynamic>>[];
    for (final raw in urls.whereType<Map>()) {
      final name = _text(raw['episode_server_name']);
      final sourceUrl = _text(raw['episode_url']);
      if (sourceUrl.isEmpty) continue;
      if (name.toLowerCase() == 'cdn') {
        servers.addAll(await _resolveBackup(sourceUrl, raw));
      } else if (name.toLowerCase() == 'muilt') {
        servers.addAll(await _resolveMulti(sourceUrl, raw));
      } else {
        servers.add({'quality': name.isEmpty ? 'خادم' : name, 'url': sourceUrl, 'server': name});
      }
    }
    if (servers.isEmpty) return null;
    final unique = <String>{};
    final clean = servers.where((s) => unique.add(_text(s['url']))).toList();
    final direct = clean.where((s) => RegExp(r'\.(mp4|m3u8|webm)(?:\?|$)', caseSensitive: false).hasMatch(_text(s['url']))).toList();
    return {
      'source_id': 'anime_slayer',
      'stream_url': (direct.isNotEmpty ? direct : clean).first['url'],
      'direct_stream_urls': direct.isNotEmpty ? direct : clean,
      'download_links': <String, dynamic>{'Auto': direct.isNotEmpty ? direct : clean},
      'headers': {'User-Agent': 'Mozilla/5.0', 'Referer': 'https://anslayer.com/'},
    };
  }

  static Future<List<Map<String, dynamic>>> _resolveMulti(String url, Map raw) async {
    final candidates = <String>{url};
    try {
      final uri = Uri.parse(url);
      candidates.add(Uri.https('anslayer.com', '${uri.path}${uri.query.isEmpty ? '' : '?${uri.query}'}').toString());
    } catch (_) {}
    for (final candidate in candidates) {
      try {
        final response = await _client.get(Uri.parse(candidate), headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 8));
        if (response.statusCode < 200 || response.statusCode >= 300) continue;
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final list = decoded is List ? decoded : decoded is Map && decoded['data'] is List ? decoded['data'] : const [];
        final result = <Map<String, dynamic>>[];
        for (final item in list) {
          final value = item is String ? item : item is Map ? _text(item['url']).isNotEmpty ? _text(item['url']) : _text(item['file']) : '';
          if (value.isNotEmpty) result.add({'quality': item is Map ? _text(item['quality']) : 'خادم', 'url': value, 'server': 'muilt'});
        }
        if (result.isNotEmpty) return result;
      } catch (_) {}
    }
    return [{'quality': 'muilt', 'url': url, 'server': 'muilt'}];
  }

  static Future<List<Map<String, dynamic>>> _resolveBackup(String sourceUrl, Map raw) async {
    try {
      final source = Uri.parse(sourceUrl);
      final seedResponse = await _client.get(Uri.parse('${base}google.php'), headers: _headers).timeout(const Duration(seconds: 8));
      final seed = utf8.decode(seedResponse.bodyBytes).trim();
      if (seed.isEmpty) return [{'quality': 'cdn', 'url': sourceUrl, 'server': 'cdn'}];
      final inf = _createInf(seed);
      final endpoint = source.replace(path: source.path.replaceFirst(RegExp(r'/vq\.php$'), '/v-qs.php'));
      final response = await _client.post(endpoint, headers: {'Content-Type': 'application/x-www-form-urlencoded', 'User-Agent': 'okhttp/3.12.12'}, body: {
        'f': source.queryParameters['f'] ?? '',
        'e': source.queryParameters['e'] ?? '',
        'inf': inf,
      }).timeout(const Duration(seconds: 12));
      final decrypted = _decryptRnc(response.body);
      final decoded = jsonDecode(decrypted);
      final files = decoded is List ? decoded : const [];
      final result = <Map<String, dynamic>>[];
      for (final item in files.whereType<Map>()) {
        final file = _text(item['file']);
        if (file.isEmpty) continue;
        result.add({'quality': _quality(file), 'url': file, 'server': 'cdn'});
      }
      if (result.isNotEmpty) return result;
    } catch (_) {}
    return [{'quality': 'cdn', 'url': sourceUrl, 'server': 'cdn'}];
  }

  static String _createInf(String seed) {
    final payload = jsonEncode({'uhy': 'com.anslayer', 'dma': 47, 'mvd': '1.5.10', 'vko': _certSha1});
    final keyText = '${seed.substring(0, seed.length > 10 ? 10 : seed.length)}${_certSha1.substring(0, 22)}'.padRight(16, '0').substring(0, 16);
    final encrypter = enc.Encrypter(enc.AES(enc.Key(Uint8List.fromList(utf8.encode(keyText))), mode: enc.AESMode.ecb));
    return jsonEncode({'a': encrypter.encrypt(payload, iv: enc.IV.fromLength(16)).base64, 'b': seed});
  }

  static String _decryptRnc(String value) {
    if (_backupPassword.isEmpty) throw Exception('Anime Slayer secure configuration is unavailable');
    final data = base64.decode(value.trim());
    if (data.length < 66) throw Exception('Invalid CDN response');
    final salt = data.sublist(2, 10);
    final hmacSalt = data.sublist(10, 18);
    final encKey = _pbkdf2(_backupPassword, salt, 10000, 32);
    final hmacKey = _pbkdf2(_backupPassword, hmacSalt, 10000, 32);
    final expected = Hmac(sha256, hmacKey).convert(data.sublist(0, data.length - 32)).bytes;
    if (!_same(expected, data.sublist(data.length - 32))) throw Exception('Invalid CDN signature');
    final iv = enc.IV(Uint8List.fromList(data.sublist(18, 34)));
    final decryptor = enc.Encrypter(enc.AES(enc.Key(Uint8List.fromList(encKey)), mode: enc.AESMode.cbc));
    return decryptor.decrypt(enc.Encrypted(Uint8List.fromList(data.sublist(34, data.length - 32))), iv: iv);
  }

  static List<int> _pbkdf2(String password, List<int> salt, int rounds, int length) {
    final result = <int>[];
    var block = 1;
    while (result.length < length) {
      var u = Hmac(sha1, utf8.encode(password)).convert([...salt, (block >> 24) & 255, (block >> 16) & 255, (block >> 8) & 255, block & 255]).bytes;
      final t = List<int>.from(u);
      for (var i = 1; i < rounds; i++) {
        u = Hmac(sha1, utf8.encode(password)).convert(u).bytes;
        for (var j = 0; j < t.length; j++) t[j] ^= u[j];
      }
      result.addAll(t);
      block++;
    }
    return result.sublist(0, length);
  }

  static bool _same(List<int> a, List<int> b) => a.length == b.length && List.generate(a.length, (i) => a[i] == b[i]).every((v) => v);
  static String _quality(String url) => url.toLowerCase().contains('/hh.mp4') ? '1080p' : url.toLowerCase().contains('/h.mp4') ? '720p' : url.toLowerCase().contains('/s.mp4') ? '480p' : '360p';
  static List<Map<String, dynamic>> _records(dynamic json) => _response(json) is Map && _response(json)['data'] is List ? (_response(json)['data'] as List).whereType<Map>().map(Map<String, dynamic>.from).toList() : [];
  static dynamic _response(dynamic json) => json is Map && json['response'] != null ? json['response'] : json;
  static List<Map<String, dynamic>> _findEpisodes(dynamic json) => _records(json).isNotEmpty ? _records(json) : _response(json) is Map && _response(json)['episodes'] is Map && _response(json)['episodes']['data'] is List ? (_response(json)['episodes']['data'] as List).whereType<Map>().map(Map<String, dynamic>.from).toList() : [];
  static Map<String, dynamic> _mapAnime(Map raw) => {'anime_id': _toInt(raw['anime_id']), 'title': _text(raw['anime_name']), 'english_title': _text(raw['anime_english_title']), 'url': _detailUrl(_toInt(raw['anime_id'])), 'image_url': _text(raw['anime_cover_image_url']), 'banner_image_url': _text(raw['anime_banner_image_url']), 'type': 'anime', 'description': _text(raw['anime_description']), 'genres': _splitList(raw['anime_genres']), 'rating': _text(raw['anime_rating']), 'status': _text(raw['anime_status']), 'release_year': _text(raw['anime_release_year'])};
  static Map<String, dynamic> _mapEpisode(Map raw, int animeId) => {'title': _text(raw['episode_name']).isNotEmpty ? _text(raw['episode_name']).replaceAll(RegExp(r'\s*:\s*'), ' ') : 'الحلقة ${_toInt(raw['episode_number'])}', 'url': _episodeUrl(animeId, _toInt(raw['episode_id'])), 'number': _toInt(raw['episode_number']), 'episode_id': _toInt(raw['episode_id']), 'anime_id': animeId, 'servers': raw['episode_urls'] is List ? raw['episode_urls'] : const []};
  static String _detailUrl(int id) => '$base-anime-details?anime_id=$id';
  static String _episodeUrl(int animeId, int episodeId) => '${base}episode-reference?anime_id=$animeId&episode_id=$episodeId';
  static String _text(dynamic value) => value == null ? '' : value.toString().trim();
  static int _toInt(dynamic value) => int.tryParse(_text(value)) ?? 0;
  static List<String> _splitList(dynamic value) => _text(value).split(RegExp(r'[,،]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
}
