import 'dart:convert';

import 'package:http/http.dart' as http;

import 'html_client.dart';
import 'source_base.dart';

/// Anime Witcher source based on the APK's public Algolia and Firestore data
/// layout: series -> anime_list/{doc}/episodes -> servers.
class AnimeWitcherSource extends ContentSource {
  static const _algoliaHost = 'https://QVHT7NPEJG-dsn.algolia.net';
  static const _algoliaAppId = 'QVHT7NPEJG';
  static const _algoliaKey = 'ce13098070fa521b536571bafbcfc083';
  static const _firestore = 'https://firestore.googleapis.com/v1/projects/animewitcher-1c66d/databases/(default)/documents';
  static const _ua = 'AnimeWitcher/1.4.8 (Android)';

  @override
  String get id => 'anime_witcher';

  @override
  String get name => 'Anime Witcher';

  @override
  String get kind => 'anime';

  @override
  List<String> get hosts => ['animewitcher.com', 'animewitcherrs.com'];

  @override
  bool handles(String url) => url.startsWith('animewitcher://') || super.handles(url);

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return const [];
    final response = await _algoliaPost('series', {'params': Uri(queryParameters: {'query': value, 'hitsPerPage': '30'}).query});
    final hits = response['hits'] as List? ?? const [];
    return hits.whereType<Map>().map((hit) => _animeItem(Map<String, dynamic>.from(hit))).where(_valid).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final response = await _algoliaPost('series_date_created', {'params': Uri(queryParameters: {'query': '', 'hitsPerPage': '30', 'page': '${page - 1}'}).query});
    final hits = response['hits'] as List? ?? const [];
    return hits.whereType<Map>().map((hit) => _animeItem(Map<String, dynamic>.from(hit))).where(_valid).toList();
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final docId = _docIdFrom(url);
    if (docId.isEmpty) throw Exception('تعذر تحديد الأنمي من Anime Witcher');
    final raw = await _firestoreDocument('anime_list/${Uri.encodeComponent(docId)}');
    final result = _animeItem(raw);
    result['url'] = url;
    result['episodes'] = await _episodes(docId);
    return result;
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'animewitcher') return null;
    final animeId = uri.queryParameters['anime'] ?? '';
    final episodeId = uri.queryParameters['episode'] ?? '';
    if (animeId.isEmpty || episodeId.isEmpty) return null;
    final docs = await _firestoreCollection('anime_list/${Uri.encodeComponent(animeId)}/episodes/${Uri.encodeComponent(episodeId)}/servers');
    final links = <Map<String, dynamic>>[];
    for (final doc in docs) {
      final server = _decodeFields(doc['fields'] as Map? ?? const {});
      final name = _text(server['name'] ?? server['server'] ?? 'Anime Witcher');
      final quality = _text(server['quality'] ?? server['resolution'] ?? '');
      final link = _text(server['link'] ?? server['url'] ?? server['original_link']);
      if (link.isEmpty) continue;
      final direct = server['direct_link'] == true || server['direct'] == true || _looksMedia(link);
      if (direct) {
        links.add({'url': link, 'quality': quality, 'server': name, 'name': name});
        continue;
      }
      final resolved = await _resolveServer(link);
      for (final media in resolved) {
        links.add({'url': media, 'quality': quality, 'server': name, 'name': name, 'headers': {'Referer': link}});
      }
    }
    return links.isEmpty ? null : {'title': uri.queryParameters['title'] ?? 'حلقة', 'direct_stream_urls': links, 'servers': links};
  }

  Future<List<Map<String, dynamic>>> _episodes(String animeId) async {
    final docs = await _firestoreCollection('anime_list/${Uri.encodeComponent(animeId)}/episodes', query: {'pageSize': '1000', 'orderBy': 'order'});
    final episodes = <Map<String, dynamic>>[];
    for (final doc in docs) {
      final fields = _decodeFields(doc['fields'] as Map? ?? const {});
      final id = _documentId(doc['name']);
      final number = _number(fields['order'] ?? fields['episode'] ?? fields['number'], episodes.length + 1);
      final title = _text(fields['name'] ?? fields['episode_name'] ?? fields['title'] ?? 'الحلقة $number');
      final internal = Uri(scheme: 'animewitcher', host: 'episode', queryParameters: {'anime': animeId, 'episode': id, 'title': title}).toString();
      episodes.add({
        'id': id,
        'episode_id': id,
        'number': number,
        'episode_number': number,
        'title': title,
        'name': title,
        'image': _text(fields['thumb_uri'] ?? fields['episode_thumb'] ?? fields['episode_thumb2'] ?? ''),
        'thumbnail': _text(fields['thumb_uri'] ?? fields['episode_thumb'] ?? fields['episode_thumb2'] ?? ''),
        'duration': fields['duration'] ?? 0,
        'url': internal,
      });
    }
    episodes.sort((a, b) => (a['number'] as num).compareTo(b['number'] as num));
    return episodes;
  }

  Map<String, dynamic> _animeItem(Map<String, dynamic> raw) {
    final details = raw['details'] is Map ? Map<String, dynamic>.from(raw['details']) : <String, dynamic>{};
    final poster = raw['aniList_poster'] is Map ? Map<String, dynamic>.from(raw['aniList_poster']) : <String, dynamic>{};
    final title = _text(raw['name'] ?? raw['title'] ?? details['english_title'] ?? raw['objectID']);
    final docId = _text(raw['objectID'] ?? raw['doc_id'] ?? raw['name']);
    final image = _text(poster['large'] ?? poster['medium'] ?? raw['cover_uri'] ?? raw['poster_uri'] ?? '');
    final item = this.item(
      title: title,
      url: 'animewitcher://anime/${Uri.encodeComponent(docId)}',
      image: image,
      type: _text(raw['type']),
      genres: _asList(raw['tags'] ?? raw['genres']),
      description: _text(raw['story'] ?? raw['description']),
      rating: _text((raw['rating'] is Map ? raw['rating']['rate'] : raw['average_rate']) ?? ''),
    );
    item.addAll({
      'anime_id': docId,
      'doc_id': docId,
      'original_title': _text(details['english_title'] ?? ''),
      'alternate_titles': _asList(raw['other_names'] ?? raw['search_names']),
      'banner_image_url': _text(raw['cover_uri'] ?? ''),
      'status': _text(details['state'] ?? raw['status'] ?? ''),
      'year': _text(details['year'] ?? ''),
      'studio': _asList(details['studio']),
      'author': _text(raw['author'] ?? ''),
      'latest_episode': _text(details['eps_num'] ?? ''),
      'mal_id': _text(raw['mal_id'] ?? ''),
    });
    return item;
  }

  Future<Map<String, dynamic>> _algoliaPost(String index, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$_algoliaHost/1/indexes/$index/query'),
      headers: {'X-Algolia-Application-Id': _algoliaAppId, 'X-Algolia-API-Key': _algoliaKey, 'Content-Type': 'application/json', 'User-Agent': _ua},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('Anime Witcher search failed');
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(response.bodyBytes)) as Map);
  }

  Future<Map<String, dynamic>> _firestoreDocument(String path) async {
    final response = await http.get(Uri.parse('$_firestore/$path'), headers: {'Accept': 'application/json', 'User-Agent': _ua}).timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('Anime Witcher details failed');
    return _decodeDocument(jsonDecode(utf8.decode(response.bodyBytes)) as Map);
  }

  Future<List<Map<String, dynamic>>> _firestoreCollection(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$_firestore/$path').replace(queryParameters: query);
    final response = await http.get(uri, headers: {'Accept': 'application/json', 'User-Agent': _ua}).timeout(const Duration(seconds: 25));
    if (response.statusCode == 403) return const [];
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('Anime Witcher episodes failed');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    return decoded is Map && decoded['documents'] is List ? (decoded['documents'] as List).whereType<Map>().map(Map<String, dynamic>.from).toList() : const [];
  }

  Future<List<String>> _resolveServer(String url) async {
    try {
      final response = await http.get(Uri.parse(url), headers: {'User-Agent': _ua, 'Referer': 'https://animewitcher.com/'}).timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 400) return const [];
      return SourceUtils.extractMediaUrls(utf8.decode(response.bodyBytes, allowMalformed: true), url).where(_looksMedia).toList();
    } catch (_) {
      return const [];
    }
  }

  Map<String, dynamic> _decodeDocument(Map raw) => _decodeFields(raw['fields'] as Map? ?? const {});
  Map<String, dynamic> _decodeFields(Map fields) => fields.map((key, value) => MapEntry(key.toString(), _decodeValue(value)));
  dynamic _decodeValue(dynamic value) {
    if (value is! Map || value.isEmpty) return value;
    if (value.containsKey('stringValue')) return value['stringValue'];
    if (value.containsKey('integerValue')) return int.tryParse(value['integerValue'].toString()) ?? value['integerValue'];
    if (value.containsKey('doubleValue')) return value['doubleValue'];
    if (value.containsKey('booleanValue')) return value['booleanValue'];
    if (value.containsKey('timestampValue')) return value['timestampValue'];
    if (value.containsKey('mapValue')) return _decodeFields(value['mapValue']['fields'] as Map? ?? const {});
    if (value.containsKey('arrayValue')) return (value['arrayValue']['values'] as List? ?? const []).map(_decodeValue).toList();
    return value;
  }

  String _docIdFrom(String url) => Uri.tryParse(url)?.pathSegments.lastOrNull ?? '';
  String _documentId(dynamic path) => path.toString().split('/').last;
  int _number(dynamic value, int fallback) => value is num ? value.toInt() : int.tryParse(value.toString()) ?? fallback;
  String _text(dynamic value) => value == null || value is Map || value is List ? '' : value.toString().trim();
  List<dynamic> _asList(dynamic value) => value is List ? value.where((item) => _text(item).isNotEmpty).toList() : const [];
  bool _valid(Map<String, dynamic> item) => _text(item['title']).isNotEmpty && _text(item['url']).isNotEmpty;
  bool _looksMedia(String url) => RegExp(r'\.(m3u8|mp4|webm)(?:\?|$)', caseSensitive: false).hasMatch(url) || url.contains('manifest');
}

extension _LastOrNull<T> on List<T> {
  T? get lastOrNull => isEmpty ? null : last;
}
