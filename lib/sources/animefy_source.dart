import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import 'source_base.dart';

/// Animefy API adapter.
///
/// Animefy's Xamarin client posts form fields with their original casing. Keep
/// that boundary explicit: sending guessed aliases makes the API return an
/// empty body instead of a catalog.
class AnimefySource extends ContentSource {
  static const _base = 'https://animeify.net/animeify/apis_v4';
  static const _thumbnailBase = 'https://animeify.net/animeify/files/thumbnails/';
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
      'FilterType': 'Search',
      'FilterData': '',
      'AnimeListMode': 'NAME',
      'SearchText': value,
    });
    return _items(decoded).map(_anime).where(_isValid).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    // The API returns the complete sorted catalog; pagination is performed by
    // the existing application layer. AnimeListMode is the APK sort value.
    final decoded = await _api('anime/load_anime_list_v2.php', {
      'FilterType': '',
      'FilterData': '',
      'AnimeListMode': 'NAME',
      'SearchText': '',
    });
    final all = _items(decoded).map(_anime).where(_isValid).toList();
    const pageSize = 50;
    final start = (page - 1) * pageSize;
    return start >= all.length ? const [] : all.skip(start).take(pageSize).toList();
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final uri = Uri.tryParse(url);
    final id = uri?.queryParameters['id'] ?? '';
    if (id.isEmpty) throw Exception('تعذر تحميل تفاصيل الأنمي');

    final decoded = await _api('anime/load_anime_details.php', {'AnimeID': id});
    final raw = _firstMap(decoded) ?? <String, dynamic>{'AnimeID': id};
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
    if (animeId.isEmpty || episodeId.isEmpty) return null;

    final decoded = await _api('anime/load_servers.php', {
      'AnimeID': animeId,
      'Episode': episodeId,
    });
    final candidates = <Map<String, dynamic>>[];
    for (final map in _mapsDeep(decoded)) {
      final serverName = _text(map['servers_name_ma'] ?? map['server_name'] ?? map['name'] ?? 'Animefy');
      for (final key in const [
        'server_a', 'server_b', 'server_c', 'server_d', 'server_e', 'server_f',
        'server_g', 'server_hd', 'server_sd', 'server_fhd', 'WatchLink',
        'StreamLink', 'DownloadLink',
      ]) {
        final value = _decodeUrl(_text(map[key]));
        if (!_looksLikeUrl(value)) continue;
        final quality = key.contains('fhd') ? 'FHD' : key.contains('hd') ? 'HD' : key.contains('sd') ? 'SD' : '';
        candidates.add({'url': value, 'quality': quality, 'server': serverName, 'name': serverName});
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
    final decoded = await _api('episodes/load_episodes.php', {'AnimeID': animeId});
    final sourceItems = _items(decoded).isNotEmpty ? _items(decoded) : _items(details['Episodes']);
    final episodes = <Map<String, dynamic>>[];
    for (var index = 0; index < sourceItems.length; index++) {
      final raw = sourceItems[index];
      final id = _text(raw['Episode'] ?? raw['EpisodeNumber'] ?? raw['id'] ?? '${index + 1}');
      final number = _number(raw['EpisodeNumber'] ?? raw['Episode'], index + 1);
      final title = 'الحلقة $number';
      final internal = Uri(scheme: 'animefy', host: 'episode', queryParameters: {
        'anime': animeId,
        'episode': id,
        'title': title,
      }).toString();
      final image = _image(raw['Thumbnail']);
      episodes.add({
        'id': id,
        'episode_id': id,
        'number': number,
        'episode_number': number,
        'title': title,
        'name': title,
        'image': image,
        'thumbnail': image,
        'url': internal,
      });
    }
    episodes.sort((a, b) => (a['number'] as int).compareTo(b['number'] as int));
    return episodes;
  }

  Map<String, dynamic> _anime(Map<String, dynamic> raw) {
    final id = _text(raw['AnimeID'] ?? raw['AnimeId'] ?? raw['RelationId'] ?? raw['AnimeRelationId'] ?? raw['id']);
    final arabic = _text(raw['ARTitle']);
    final english = _text(raw['ENTitle']);
    final title = arabic.isNotEmpty ? arabic : (english.isNotEmpty ? english : _text(raw['JPTitle']));
    final item = this.item(
      title: title.isEmpty ? 'بدون عنوان' : title,
      url: Uri(scheme: 'animefy', host: 'anime', queryParameters: {'id': id}).toString(),
      image: _image(raw['Thumbnail'] ?? raw['catalogthumbnail']),
      type: 'anime',
      genres: _list(raw['Genres'] ?? raw['Tags']),
      description: _text(raw['Description'] ?? raw['Synopsis'] ?? raw['Story']),
      rating: _text(raw['Rating'] ?? raw['Score']),
    );
    item.addAll({
      'anime_id': id,
      'doc_id': id,
      'alternative_title': english,
      'japanese_title': _text(raw['JPTitle']),
      'arabic_title': arabic,
      'synonyms': _list(raw['Synonyms']),
      'season': _text(raw['Season']),
      'duration': _text(raw['Duration']),
      'premiered': _text(raw['Premiered']),
      'aired': _text(raw['Aired']),
      'trailer': _text(raw['Trailer'] ?? raw['YTTrailer']),
      'creators': _list(raw['Creators']),
      'total_episodes': _number(raw['Episodes'], 0),
      'rank': _text(raw['Rank']),
      'popularity': _text(raw['Popularity']),
      'relation_id': _text(raw['RelationId'] ?? raw['AnimeRelationId']),
    });
    return item;
  }

  Future<dynamic> _api(String endpoint, Map<String, String> params) async {
    final uri = Uri.parse('$_base/$endpoint');
    final response = await http.post(uri, headers: {
      'User-Agent': _ua,
      'Accept': 'application/json, text/plain, */*',
      'Referer': 'https://animeify.net/',
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
    }, body: params).timeout(const Duration(seconds: 20));
    final body = utf8.decode(response.bodyBytes, allowMalformed: false).trim();
    developer.log('Animefy $endpoint method=POST status=${response.statusCode} bytes=${body.length}', name: 'AnimefySource');
    if (response.statusCode < 200 || response.statusCode >= 300 || body.isEmpty) return const <dynamic>[];
    try {
      final parsed = jsonDecode(body);
      developer.log('Animefy $endpoint items=${_items(parsed).length}', name: 'AnimefySource');
      return parsed is Map || parsed is List ? parsed : const <dynamic>[];
    } catch (_) {
      return const <dynamic>[];
    }
  }

  List<Map<String, dynamic>> _items(dynamic value) {
    if (value is List) return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (value is Map) {
      for (final key in const ['data', 'results', 'items', 'anime', 'animes', 'episodes', 'servers', 'list']) {
        final nested = _items(value[key]);
        if (nested.isNotEmpty) return nested;
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
      for (final child in map.values) yield* _mapsDeep(child);
    } else if (value is List) {
      for (final child in value) yield* _mapsDeep(child);
    }
  }

  String _decodeUrl(String value) {
    var result = value.trim().replaceAll('\\/', '/').replaceAll('&amp;', '&');
    try {
      final decoded = Uri.decodeComponent(result);
      if (_looksLikeUrl(decoded)) result = decoded;
    } catch (_) {}
    return result;
  }

  String _image(dynamic value) {
    final raw = _text(value);
    if (raw.isEmpty) return '';
    if (raw.startsWith('http')) return raw;
    return '$_thumbnailBase${raw.replaceFirst(RegExp(r'^/+'), '')}';
  }

  List<dynamic> _list(dynamic value) => value is List ? value.map(_text).where((e) => e.isNotEmpty).toList() : (value == null ? const [] : [_text(value)]);
  String _text(dynamic value) => value == null || value is Map || value is List ? '' : value.toString().trim();
  int _number(dynamic value, int fallback) => value is num ? value.toInt() : int.tryParse(_text(value)) ?? fallback;
  bool _isValid(Map<String, dynamic> value) => _text(value['title']).isNotEmpty && _text(value['url']).isNotEmpty;
  bool _looksLikeUrl(String value) => value.startsWith('http://') || value.startsWith('https://');
}
