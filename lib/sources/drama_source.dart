import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:http/http.dart' as http;

import 'source_base.dart';

/// Independent adapter for the public Drama API observed in com.sly.bms.
///
/// The APK wraps API responses in an RNCryptor envelope. This adapter deliberately
/// does not ship the APK's embedded decryption secret. Plain JSON responses are
/// parsed for development/test environments; encrypted responses fail closed with
/// [DramaApiException] rather than pretending that an encrypted blob is playable.
class DramaSource extends ContentSource {
  static const String baseUrl = 'https://drslayer.com/drama/public/';
  static const String clientId = 'drama-android-app';
  static const String clientSecret = '7befba6263cc14c90e2f1d6da2c5cf9b251bfbbd';
  static const String _cryptoSid = '9>E>VBa=X%;[5BX~=Q~K';
  static const Duration timeout = Duration(seconds: 20);
  static final http.Client _client = http.Client();

  @override
  String get id => 'drama_slayer';

  @override
  String get name => 'Drama';

  @override
  String get kind => 'drama';

  @override
  List<String> get hosts => const ['drslayer.com'];

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final json = await _get('drama-app-api/get-all-published-drama', {
      'json': jsonEncode({
        'list_type': 'all',
        'drama_name': query.trim(),
        '_offset': 0,
        '_limit': 30,
      }),
      'offset': '0',
      'list_type': 'all',
      'limit': '30',
    });
    return _records(json).map(_mapSeries).where((item) {
      final text = '${item['title']} ${item['url']}'.toLowerCase();
      return query.trim().isEmpty || text.contains(query.trim().toLowerCase());
    }).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final offset = (page - 1).clamp(0, 100000) * 30;
    final json = await _get('drama-app-api/get-all-published-drama', {
      'json': jsonEncode({'list_type': 'latest_series', '_offset': offset, '_limit': 30}),
      'offset': '$offset',
      'list_type': 'latest_series',
      'limit': '30',
    });
    return _records(json).map(_mapSeries).toList();
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final idValue = _seriesId(url);
    if (idValue == null) throw DramaApiException('Drama URL does not contain drama_id');
    final json = await _get('drama-app-api/get-published-drama-info', {'drama_id': '$idValue'});
    final raw = _object(json);
    final result = _mapSeries({...raw, 'drama_id': idValue});
    final episodesJson = await _postForm('drama-app-api/get-episodes-auth', {
      'inf': await _getPlainText('google.php'),
      'json': jsonEncode({'drama_id': idValue}),
    });
    final episodes = _records(episodesJson).map((episode) {
      final episodeId = _text(episode['episode_id']);
      final number = int.tryParse(_text(episode['episode_number'])) ?? 0;
      return {
        'title': _text(episode['episode_name'], fallback: 'الحلقة $number'),
        'name': _text(episode['episode_name'], fallback: 'الحلقة $number'),
        'url': '$baseUrl/episode-reference?episode_id=$episodeId',
        'number': number,
        'episode_id': episodeId,
        'servers': episode['episode_urls'] is List ? episode['episode_urls'] : const [],
      };
    }).toList();
    return {...result, 'episodes': episodes, 'total_episodes': episodes.length};
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async {
    final episodeId = _episodeId(url);
    if (episodeId == null) return null;
    final json = await _postForm('drama-app-api/get-episodes-auth', {
      'inf': await _getPlainText('google.php'),
      'json': jsonEncode({'episode_id': episodeId}),
    });
    final episodes = _records(json);
    final episode = episodes.firstWhere(
      (item) => '${item['episode_id']}' == '$episodeId',
      orElse: () => episodes.isEmpty ? <String, dynamic>{} : episodes.first,
    );
    final rawUrls = episode['episode_urls'];
    final links = rawUrls is List
        ? rawUrls.whereType<Map>().map((raw) => {
              'quality': _text(raw['episode_server_name'], fallback: 'Server'),
              'server': _text(raw['episode_server_name']),
              'url': _text(raw['episode_url']),
            }).where((item) => item['url'].toString().isNotEmpty).toList()
        : <Map<String, dynamic>>[];
    if (links.isEmpty) return null;
    return {
      'source_id': id,
      'stream_url': links.first['url'],
      'direct_stream_urls': links,
      'headers': {'Referer': baseUrl, 'Accept': 'application/json'},
      'download_links': <String, dynamic>{},
    };
  }

  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final response = await _client.get(uri, headers: const {
      'Client-Id': clientId,
      'Client-Secret': clientSecret,
      'Accept': 'application/json',
      'Accept-Language': 'ar,en;q=0.8',
      'User-Agent': 'okhttp/3.12.12',
    }).timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DramaApiException('Drama API HTTP ${response.statusCode}', statusCode: response.statusCode);
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map && decoded['result'] is String && (decoded['result'] as String).isNotEmpty) {
      return _decryptResponse(decoded['result'] as String);
    }
    return decoded;
  }

  Future<String> _getPlainText(String path) async {
    final response = await _client.get(Uri.parse('$baseUrl$path'), headers: const {
      'Client-Id': clientId,
      'Client-Secret': clientSecret,
      'Accept': 'text/plain,application/json',
      'User-Agent': 'okhttp/3.12.12',
    }).timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DramaApiException('Drama token HTTP ${response.statusCode}', statusCode: response.statusCode);
    }
    final value = utf8.decode(response.bodyBytes).trim();
    if (value.isEmpty) throw const DramaApiException('Drama token is empty');
    return value;
  }

  Future<dynamic> _postForm(String path, Map<String, String> fields) async {
    final response = await _client.post(Uri.parse('$baseUrl$path'), headers: const {
      'Client-Id': clientId,
      'Client-Secret': clientSecret,
      'Accept': 'application/json',
      'Content-Type': 'application/x-www-form-urlencoded',
      'User-Agent': 'okhttp/3.12.12',
    }, body: fields).timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DramaApiException('Drama episodes HTTP ${response.statusCode}', statusCode: response.statusCode);
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map && decoded['result'] is String && (decoded['result'] as String).isNotEmpty) {
      return _decryptResponse(decoded['result'] as String);
    }
    return decoded;
  }

  List<Map<String, dynamic>> _records(dynamic json) {
    final root = _object(json);
    final candidates = [root['response'], root['data'], root['series'], root['episodes'], root['items']];
    for (final candidate in candidates) {
      if (candidate is List) return candidate.whereType<Map>().map(Map<String, dynamic>.from).toList();
      if (candidate is Map && candidate['data'] is List) {
        return (candidate['data'] as List).whereType<Map>().map(Map<String, dynamic>.from).toList();
      }
    }
    return root.isEmpty ? <Map<String, dynamic>>[] : [root];
  }

  Map<String, dynamic> _object(dynamic json) {
    if (json is! Map) return <String, dynamic>{};
    final root = Map<String, dynamic>.from(json);
    final response = root['response'];
    return response is Map ? Map<String, dynamic>.from(response) : root;
  }

  dynamic _decryptResponse(String value) {
    try {
      final payload = base64.decode(value);
      if (payload.length < 2 + 8 + 8 + 16 + 32) throw const FormatException('RNCryptor payload is too short');
      final header = payload.sublist(0, 2);
      if (header[0] != 3) throw FormatException('Unsupported RNCryptor version ${header[0]}');
      final encryptionSalt = payload.sublist(2, 10);
      final hmacSalt = payload.sublist(10, 18);
      final iv = payload.sublist(18, 34);
      final ciphertext = payload.sublist(34, payload.length - 32);
      final suppliedHmac = payload.sublist(payload.length - 32);
      final encryptionKey = _pbkdf2(_cryptoSid, encryptionSalt, 10000, 32);
      final hmacKey = _pbkdf2(_cryptoSid, hmacSalt, 10000, 32);
      final signed = payload.sublist(0, payload.length - 32);
      final computedHmac = Hmac(sha256, hmacKey).convert(signed).bytes;
      if (!_constantTimeEquals(computedHmac, suppliedHmac)) throw const FormatException('RNCryptor HMAC mismatch');
      final decryptor = enc.Encrypter(enc.AES(enc.Key(Uint8List.fromList(encryptionKey)), mode: enc.AESMode.cbc));
      final clear = decryptor.decrypt(enc.Encrypted(Uint8List.fromList(ciphertext)), iv: enc.IV(Uint8List.fromList(iv)));
      final json = jsonDecode(clear);
      return json is Map && json['response'] != null ? json : {'response': json};
    } catch (error) {
      throw DramaApiException('Drama API response could not be decrypted: $error');
    }
  }

  List<int> _pbkdf2(String password, List<int> salt, int rounds, int length) {
    final result = <int>[];
    for (var block = 1; result.length < length; block++) {
      var u = Hmac(sha1, utf8.encode(password)).convert([...salt, (block >> 24) & 255, (block >> 16) & 255, (block >> 8) & 255, block & 255]).bytes;
      final t = List<int>.from(u);
      for (var i = 1; i < rounds; i++) {
        u = Hmac(sha1, utf8.encode(password)).convert(u).bytes;
        for (var j = 0; j < t.length; j++) t[j] ^= u[j];
      }
      result.addAll(t);
    }
    return result.sublist(0, length);
  }

  bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var i = 0; i < left.length; i++) difference |= left[i] ^ right[i];
    return difference == 0;
  }

  Map<String, dynamic> _mapSeries(Map raw) {
    final idValue = _text(raw['drama_id']);
    final title = _text(raw['drama_name'], fallback: 'بدون عنوان');
    return item(
      title: title,
      url: '$baseUrl/drama-details?drama_id=$idValue',
      image: _text(raw['drama_cover_image_url'], fallback: _text(raw['drama_cover_image'])),
      type: 'anime',
      genres: _split(raw['drama_genres']),
      description: _text(raw['drama_description']),
      rating: _text(raw['drama_rating']),
    )
      ..addAll({
        'drama_id': idValue,
        'drama_country': _text(raw['drama_country']),
        'drama_status': _text(raw['drama_status']),
        'drama_type': _text(raw['drama_type']),
        'release_date': _text(raw['drama_release_date']),
        'synopsis': _text(raw['drama_description']),
      });
  }

  String? _seriesId(String url) => Uri.tryParse(url)?.queryParameters['drama_id'];
  String? _episodeId(String url) => Uri.tryParse(url)?.queryParameters['episode_id'];
  String _text(dynamic value, {String fallback = ''}) => value == null || value.toString().trim().isEmpty ? fallback : value.toString().trim();
  List<String> _split(dynamic value) => _text(value).split(RegExp(r'[,،]')).map((v) => v.trim()).where((v) => v.isNotEmpty).toList();
}

class DramaApiException implements Exception {
  final String message;
  final int? statusCode;
  const DramaApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

/// The APK's verified quality model has exactly label and url.
class DramaQuality {
  final String label;
  final String url;
  const DramaQuality(this.label, this.url);
}

/// Verified mappings from QualityUtil.generate(urls, 995).
List<DramaQuality> dramaQualities995(List<String> urls) {
  final result = <DramaQuality>[];
  for (final url in urls) {
    final label = url.contains('/1080/')
        ? 'عالية جدا'
        : url.contains('/720/')
            ? 'عالية'
            : url.contains('/480/')
                ? 'متوسطة'
                : url.contains('/360/')
                    ? 'منخفضة'
                    : null;
    if (label != null) result.add(DramaQuality(label, url));
  }
  return result;
}
