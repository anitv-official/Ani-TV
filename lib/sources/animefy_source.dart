import 'dart:convert';

import 'package:http/http.dart' as http;

import 'html_client.dart';
import 'source_base.dart';

/// Animefy adapter. The API has had several compatible v4 response shapes;
/// this adapter keeps the request/normalisation boundary isolated from the UI.
class AnimefySource extends ContentSource {
  static const _base = 'https://animeify.net/animeify/apis_v4';
  static const _files = 'https://animeify.net/animeify/files';
  static const _ua = 'AniTV/1.0 (Android)';

  @override
  String get id => 'animefy';

  @override
  String get name => 'Animefy';

  @override
  String get kind => 'anime';

  @override
  List<String> get hosts => ['animeify.net', 'animefy.net'];

  @override
  bool handles(String url) => url.startsWith('animefy://') || super.handles(url);

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return const [];
    final decoded = await _api('anime/load_anime_list_v2.php', {
      'search': value,
      'query': value,
      'q': value,
      'page': '1',
      'limit': '50',
    });
    return _items(decoded).map(_anime).where(_isValid).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final decoded = await _api('anime/load_latest_anime.php', {'page': '$page', 'limit': '50'});
    return _items(decoded).map(_anime).where(_isValid).toList();
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final uri = Uri.tryParse(url);
    final id = uri?.queryParameters['id'] ?? uri?.pathSegments.lastOrNull ?? '';
    if (id.isEmpty) throw Exception('تعذر تحميل تفاصيل الأنمي');
    final decoded = await _api('anime/load_anime_details.php', {'id': id, 'anime_id': id, 'animeId': id});
    final raw = _firstMap(decoded) ?? <String, dynamic>{'id': id};
    final result = _anime(raw);
    result['url'] = url;
    result['episodes'] = await _episodes(id, raw);
    result['total_episodes'] = (result['episodes'] as List).length;
    return result;
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'animefy') return null;
    final animeId = uri.queryParameters['anime'] ?? '';
    final episodeId = uri.queryParameters['episode'] ?? '';
    if (episodeId.isEmpty) return null;
    final decoded = await _api('anime/load_servers.php', {
      'id': episodeId,
      'episode_id': episodeId,
      'episodeId': episodeId,
      'anime_id': animeId,
      'animeId': animeId,
    });
    final candidates = <Map<String, dynamic>>[];
    for (final map in _mapsDeep(decoded)) {
      final name = _text(map['name'] ?? map['server'] ?? map['title'] ?? 'Animefy');
      final quality = _text(map['quality'] ?? map['resolution'] ?? map['quality_name'] ?? '');
      for (final raw in _stringsDeep(map)) {
        final value = _decodeUrl(raw);
        if (!_looksLikeUrl(value)) continue;
        if (_isMedia(value)) {
          candidates.add({'url': value, 'quality': quality, 'server': name, 'name': name});
        } else {
          final resolved = await _extract(value);
          for (final media in resolved) {
            candidates.add({'url': media, 'quality': quality, 'server': name, 'name': name, 'headers': {'Referer': value}});
          }
        }
      }
    }
    final unique = <String>{};
    final links = candidates.where((item) => unique.add(item['url'].toString())).toList();
    if (links.isEmpty) return null;
    return {
      'source_id': id,
      'stream_url': links.first['url'],
      'direct_stream_urls': links,
      'servers': links,
      'headers': {'Referer': 'https://animeify.net/', 'User-Agent': _ua},
    };
  }

  Future<List<Map<String, dynamic>>> _episodes(String animeId, Map<String, dynamic> details) async {
    final decoded = await _api('episodes/load_episodes.php', {
      'id': animeId,
      'anime_id': animeId,
      'animeId': animeId,
      'page': '1',
      'limit': '10000',
    });
    final rawItems = _items(decoded);
    final sourceItems = rawItems.isNotEmpty ? rawItems : _items(details['episodes']);
    final episodes = <Map<String, dynamic>>[];
    for (var index = 0; index < sourceItems.length; index++) {
      final raw = sourceItems[index];
      final id = _text(raw['id'] ?? raw['episode_id'] ?? raw['episodeId'] ?? raw['ep_id'] ?? raw['number'] ?? '${index + 1}');
      final number = _number(raw['episode_number'] ?? raw['episode'] ?? raw['number'] ?? raw['ep'], index + 1);
      final rawTitle = _text(raw['title'] ?? raw['name'] ?? raw['episode_name'] ?? raw['ep_name']);
      final title = 'الحلقة $number${rawTitle.isEmpty || _looksGeneric(rawTitle, number) ? '' : ' - ${SourceUtils.cleanTitle(rawTitle)}'}';
      final internal = Uri(scheme: 'animefy', host: 'episode', queryParameters: {'anime': animeId, 'episode': id, 'title': title}).toString();
      episodes.add({
        'id': id,
        'episode_id': id,
        'number': number,
        'episode_number': number,
        'title': title,
        'name': title,
        'image': _image(raw['image'] ?? raw['thumbnail'] ?? raw['thumb']),
        'thumbnail': _image(raw['image'] ?? raw['thumbnail'] ?? raw['thumb']),
        'url': internal,
      });
    }
    episodes.sort((a, b) => (a['number'] as int).compareTo(b['number'] as int));
    return episodes;
  }

  Map<String, dynamic> _anime(Map<String, dynamic> raw) {
    final id = _text(raw['id'] ?? raw['anime_id'] ?? raw['animeId'] ?? raw['slug'] ?? raw['mal_id']);
    final title = _text(raw['title'] ?? raw['name'] ?? raw['anime_name'] ?? raw['english_title']);
    final details = raw['details'] is Map ? Map<String, dynamic>.from(raw['details']) : const <String, dynamic>{};
    final item = this.item(
      title: title.isEmpty ? 'بدون عنوان' : title,
      url: Uri(scheme: 'animefy', host: 'anime', queryParameters: {'id': id}).toString(),
      image: _image(raw['image'] ?? raw['poster'] ?? raw['cover'] ?? raw['thumbnail'] ?? raw['poster_url']),
      type: 'anime',
      genres: _list(raw['genres'] ?? raw['categories'] ?? raw['tags']),
      description: _text(raw['description'] ?? raw['story'] ?? raw['synopsis'] ?? details['description']),
      rating: _text(raw['rating'] ?? raw['score']),
    );
    item.addAll({
      'anime_id': id,
      'doc_id': id,
      'alternative_title': _text(raw['alternative_title'] ?? raw['other_name'] ?? raw['romaji_title']),
      'status': _text(raw['status'] ?? raw['state']),
      'year': _text(raw['year'] ?? raw['release_year']),
      'total_episodes': _number(raw['episodes_count'] ?? raw['episode_count'] ?? raw['total_episodes'], 0),
      'studio': _list(raw['studio'] ?? raw['studios']),
    });
    return item;
  }

  Future<dynamic> _api(String endpoint, Map<String, String> params) async {
    final uri = Uri.parse('$_base/$endpoint');
    final headers = {'User-Agent': _ua, 'Accept': 'application/json, text/plain, */*', 'Referer': 'https://animeify.net/'};
    final attempts = <Future<http.Response>>[
      http.post(uri, headers: {...headers, 'Content-Type': 'application/x-www-form-urlencoded'}, body: params),
      http.post(uri, headers: {...headers, 'Content-Type': 'application/json'}, body: jsonEncode(params)),
      http.get(uri.replace(queryParameters: params), headers: headers),
    ];
    for (final request in attempts) {
      try {
        final response = await request.timeout(const Duration(seconds: 20));
        if (response.statusCode < 200 || response.statusCode >= 300 || response.body.trim().isEmpty) continue;
        final body = utf8.decode(response.bodyBytes, allowMalformed: false).trim();
        final parsed = jsonDecode(body);
        if (parsed is Map || parsed is List) return parsed;
      } catch (_) {}
    }
    return const <dynamic>[];
  }

  Future<List<String>> _extract(String pageUrl) async {
    try {
      final html = await HtmlClient.getHtml(pageUrl);
      return SourceUtils.extractMediaUrls(html, pageUrl).where(_isMedia).toList();
    } catch (_) {
      return const [];
    }
  }

  List<Map<String, dynamic>> _items(dynamic value) {
    if (value is List) return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (value is Map) {
      for (final key in ['data', 'results', 'items', 'anime', 'animes', 'episodes', 'servers', 'list']) {
        final nested = value[key];
        final items = _items(nested);
        if (items.isNotEmpty) return items;
      }
      return [Map<String, dynamic>.from(value)];
    }
    return const [];
  }

  Map<String, dynamic>? _firstMap(dynamic value) {
    final items = _items(value);
    return items.isEmpty ? null : items.first;
  }

  Iterable<Map<String, dynamic>> _mapsDeep(dynamic value) sync* {
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      yield map;
      for (final child in map.values) {
        yield* _mapsDeep(child);
      }
    } else if (value is List) {
      for (final child in value) yield* _mapsDeep(child);
    }
  }

  Iterable<String> _stringsDeep(dynamic value) sync* {
    if (value is String) {
      yield value;
    } else if (value is Map) {
      for (final child in value.values) yield* _stringsDeep(child);
    } else if (value is List) {
      for (final child in value) yield* _stringsDeep(child);
    }
  }

  String _decodeUrl(String value) {
    var result = value.trim();
    for (var i = 0; i < 2; i++) {
      try {
        final decoded = utf8.decode(base64Url.decode(base64Url.normalize(result)));
        if (_looksLikeUrl(decoded)) result = decoded;
      } catch (_) {}
      try {
        final decoded = Uri.decodeComponent(result);
        if (decoded == result) break;
        result = decoded;
      } catch (_) {}
    }
    return result.replaceAll('\\/', '/').replaceAll('&amp;', '&');
  }

  String _image(dynamic value) {
    final raw = _text(value);
    if (raw.isEmpty) return '';
    if (raw.startsWith('http')) return raw;
    return '$_files/thumbnails/${raw.replaceFirst(RegExp(r'^/+'), '')}';
  }

  List<dynamic> _list(dynamic value) => value is List ? value.map(_text).where((e) => e.isNotEmpty).toList() : (value == null ? const [] : [_text(value)]);
  String _text(dynamic value) => value == null || value is Map || value is List ? '' : value.toString().trim();
  int _number(dynamic value, int fallback) => value is num ? value.toInt() : int.tryParse(_text(value)) ?? fallback;
  bool _isValid(Map<String, dynamic> value) => _text(value['title']).isNotEmpty && _text(value['url']).isNotEmpty;
  bool _looksLikeUrl(String value) => value.startsWith('http://') || value.startsWith('https://');
  bool _isMedia(String value) => RegExp(r'\.(?:mp4|m3u8|mkv|webm)(?:[?#].*)?$', caseSensitive: false).hasMatch(value) || value.contains('.m3u8?') || value.contains('manifest');
  bool _looksGeneric(String title, int number) => title == '$number' || title.toLowerCase() == 'episode $number' || title == 'الحلقة $number';
}

extension _AnimefyLastOrNull<T> on List<T> {
  T? get lastOrNull => isEmpty ? null : last;
}
