import 'dart:convert';
import 'package:http/http.dart' as http;
import 'source_base.dart';

/// Cima Cloud/Fasel source.
///
/// The endpoint layout mirrors the Cima Cloud Android client: home/search,
/// movie/series details, episode lists, and server lists. We intentionally
/// keep the response normalization here so malformed labels or ad markup can
/// never reach the UI/player.
class CimaCloudSource extends ContentSource {
  static const _api = 'https://1654865.xyz/v1.3/api';
  static const _userAgent = 'okhttp/4.10.0';
  final http.Client _client = http.Client();
  String _cookie = '';
  final String _deviceId = 'anitv-${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';
  final String _cloudflareId =
      ('anitv${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'.padRight(31, '0'))
          .substring(0, 31);

  @override String get id => 'cima_cloud';
  @override String get name => 'Cima Cloud';
  @override String get kind => 'movie';
  @override List<String> get hosts => const ['1654865.xyz', 'www.cima-cloud.com'];

  @override Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final response = await _get(Uri.parse('$_api/home'));
    final sections = response['sections'];
    final items = <Map<String, dynamic>>[];
    if (sections is List) {
      for (final section in sections.whereType<Map>()) {
        final rows = section['section_items'];
        if (rows is List) {
          items.addAll(rows.whereType<Map>().where(_isCatalogItem).map(_catalogItem));
        }
      }
    }
    return _unique(items);
  }

  @override Future<List<Map<String, dynamic>>> search(String query) async {
    final uri = Uri.parse('$_api/search');
    final response = await _client.post(uri,
      headers: _headers,
      body: {'title': query.trim(), 'type': '0', 'sort': '1', 'page': '1'},
    ).timeout(const Duration(seconds: 35));
    final data = _decode(response);
    final raw = data['results'] ?? data['data'] ?? data['items'];
    if (raw is! List) return const [];
    return _unique(raw.whereType<Map>().where(_isCatalogItem).map(_catalogItem).toList());
  }

  @override Future<Map<String, dynamic>> details(String url) async {
    final parsed = _parseUrl(url);
    final response = await _get(Uri.parse('$_api/${parsed.type}/${parsed.id}'));
    final raw = _unwrap(response);
    if (raw is! Map) throw Exception('لم يتم العثور على تفاصيل المحتوى');
    final result = _normalizeDetails(raw, parsed.type, parsed.id);
    if (parsed.type == 'series') {
      try {
        final episodes = await _get(Uri.parse('$_api/series/${parsed.id}/episodes'));
        result['episodes'] = _normalizeEpisodes(_unwrap(episodes));
      } catch (_) {
        result['episodes'] = <Map<String, dynamic>>[];
      }
    }
    return result;
  }

  @override Future<Map<String, dynamic>?> streams(String url) async {
    final parsed = _parseUrl(url);
    final endpoint = parsed.type == 'episode'
        ? '$_api/episode/${parsed.id}/servers'
        : '$_api/${parsed.type}/${parsed.id}/servers';
    final response = await _get(Uri.parse(endpoint));
    final raw = _unwrap(response);
    final servers = <Map<String, dynamic>>[];
    void collect(dynamic value) {
      if (value is List) {
        for (final entry in value) collect(entry);
      } else if (value is Map) {
        final link = _text(value['url'] ?? value['src'] ?? value['link'] ?? value['file']);
        if (link.isNotEmpty && _safePlayable(link)) {
          final label = _text(value['name'] ?? value['label'] ?? value['server'], 'سيرفر');
          servers.add({'url': link, 'label': label, 'name': label, 'type': 'direct'});
        }
      }
    }
    collect(raw);
    final unique = <String, Map<String, dynamic>>{};
    for (final server in servers) unique[server['url'] as String] = server;
    if (unique.isEmpty) return null;
    return {'stream_url': unique.values.first['url'], 'direct_stream_urls': unique.values.toList(), 'servers': unique.values.toList(), 'title': 'مصادر Cima Cloud'};
  }

  Map<String, dynamic> _catalogItem(Map raw) {
    final id = _text(raw['id']);
    final isSeries = (_text(raw['type']).toLowerCase() == 'series' || _text(raw['type']).toLowerCase() == 'serie');
    final type = isSeries ? 'مسلسل' : 'فيلم';
    final path = isSeries ? 'series' : 'movie';
    return item(title: _text(raw['name'] ?? raw['title'], 'بدون عنوان'), url: '$_api/$path/$id', image: _text(raw['poster'] ?? raw['image'] ?? raw['image_url']), type: type, description: _text(raw['overview'] ?? raw['description']), rating: _text(raw['vote_average']));
  }

  bool _isCatalogItem(Map raw) {
    final type = _text(raw['type']).toLowerCase();
    return type == 'movie' || type == 'film' || type == 'series' || type == 'serie';
  }

  Map<String, dynamic> _normalizeDetails(Map raw, String type, String id) => {
    ...item(title: _text(raw['name'] ?? raw['title'], 'بدون عنوان'), url: '$_api/$type/$id', image: _text(raw['poster'] ?? raw['image'] ?? raw['image_url']), type: type == 'series' ? 'مسلسل' : 'فيلم', description: _text(raw['overview'] ?? raw['description']), rating: _text(raw['vote_average'])),
    'episodes': _normalizeEpisodes(raw['episodes']),
    'backdrop': _text(raw['backdrop']),
    'year': raw['year'] ?? raw['release_year'] ?? '',
  };

  List<Map<String, dynamic>> _normalizeEpisodes(dynamic raw) {
    if (raw is Map) raw = raw['episodes'] ?? raw['data'] ?? raw['items'] ?? raw['seasons'];
    if (raw is! List) return <Map<String, dynamic>>[];
    final flattened = <Map>[];
    for (final entry in raw.whereType<Map>()) {
      final nested = entry['episodes'];
      if (nested is List) {
        flattened.addAll(nested.whereType<Map>());
      } else {
        flattened.add(entry);
      }
    }
    return flattened.map((ep) {
      final id = _text(ep['id'] ?? ep['episode_id']);
      final number = ep['episode_number'] ?? ep['number'] ?? ep['episode'] ?? '';
      return {'title': _text(ep['name'] ?? ep['title'], number.toString().isEmpty ? 'حلقة' : 'الحلقة $number'), 'url': '$_api/episode/$id/servers', 'episode_id': id, 'number': number};
    }).where((ep) => (ep['episode_id'] as String).isNotEmpty).toList();
  }

  ({String type, String id}) _parseUrl(String url) {
    final uri = Uri.parse(url);
    final parts = uri.pathSegments;
    final index = parts.indexWhere((part) => part == 'movie' || part == 'series' || part == 'episode');
    if (index < 0 || index + 1 >= parts.length) throw Exception('رابط Cima Cloud غير صالح');
    return (type: parts[index], id: parts[index + 1]);
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final response = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 35));
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null) _rememberCookie(setCookie);
    return _decode(response);
  }

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'User-Agent': _userAgent,
    'firebase_id': _deviceId,
    'cloudflare-id': _cloudflareId,
    if (_cookie.isNotEmpty) 'Cookie': _cookie,
  };

  void _rememberCookie(String value) {
    final match = RegExp(r'(?i)([a-z0-9_]+)=([^;]+)').firstMatch(value);
    if (match == null) return;
    if (match.group(1) == 'ci_session') _cookie = '${match.group(1)}=${match.group(2)}';
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('تعذر الاتصال بـ Cima Cloud (${response.statusCode})');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
    if (decoded is! Map) throw Exception('استجابة Cima Cloud غير صالحة');
    if (decoded['blocked'] == true) throw Exception('خادم Cima Cloud حجب هذا الطلب مؤقتًا');
    if (decoded['status'] == false && decoded['data'] is String) throw Exception(decoded['data'].toString());
    return Map<String, dynamic>.from(decoded);
  }

  dynamic _unwrap(Map<String, dynamic> data) => data['data'] is Map || data['data'] is List ? data['data'] : data;
  String _text(dynamic value, [String fallback = '']) => value == null || value.toString().trim().isEmpty || value.toString() == 'false' ? fallback : SourceUtils.cleanTitle(value.toString());
  bool _safePlayable(String value) { final uri = Uri.tryParse(value); if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return false; final lower = value.toLowerCase(); return RegExp(r'\.(mp4|m3u8|webm|mpd)(?:[?#].*)?$').hasMatch(lower) || lower.contains('/api/file') || lower.contains('streamtape') || lower.contains('filemoon') || lower.contains('uqload'); }
  List<Map<String, dynamic>> _unique(List<Map<String, dynamic>> input) { final seen = <String>{}; return input.where((x) => seen.add('${x['url']}|${x['title']}')).toList(); }
}

/// Kept as a source-name compatibility alias for old imports.
class WecimaSource extends CimaCloudSource {}
