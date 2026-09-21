import 'dart:convert';
import 'package:http/http.dart' as http;
import '../extension_base.dart';
import 'extension_http.dart';

class AnimeWitcherExtension extends AniExtension {
  static const _host = 'animewitcher.com';
  static const _base = 'https://animewitcher.com';
  static const _firestoreBase =
      'https://firestore.googleapis.com/v1/projects/animewitcher-1c66d/databases/(default)/documents';
  static String _algoliaAppId = 'QVHT7NPEJG';
  static String _algoliaApiKey = 'ce13098070fa521b536571bafbcfc083';
  static const _client = 'Algolia for Android (3.27.0); Android (16)';

  @override String get id => 'anime_witcher';
  @override String get name => 'Anime Witcher';
  @override String get kind => 'anime';
  @override List<String> get hosts => const [_host];
  @override String get contentLabel => 'أنمي ومسلسلات';
  @override String get iconUrl => 'https://animewitcher.com/favicon.ico';
  @override ExtensionStatus get status => ExtensionStatus.available;
  @override String get statusMessage => 'Algolia وFirestore';

  Map<String, String> get _algoliaHeaders => {
        'X-Algolia-Application-Id': _algoliaAppId,
        'X-Algolia-API-Key': _algoliaApiKey,
        'User-Agent': _client,
        'Content-Type': 'application/json; charset=UTF-8',
      };

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final data = await _queryAlgolia('recent', '', page: page, hits: 30);
    return _hits(data['hits']).map(_hitToItem).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return latest();
    final data = await _queryAlgolia('series', value, page: 0, hits: 50);
    return _hits(data['hits']).map(_hitToItem).toList();
  }

  Future<Map<String, dynamic>> _queryAlgolia(String index, String query, {required int page, required int hits}) async {
    final uri = Uri.parse('https://$_algoliaAppId-dsn.algolia.net/1/indexes/$index/query');
    final params = Uri.encodeQueryComponent('query=$query&hitsPerPage=$hits&page=${page < 0 ? 0 : page - (index == 'recent' && page > 0 ? 1 : 0)}');
    Future<http.Response> request() => http.post(uri, headers: _algoliaHeaders, body: jsonEncode({'params': params})).timeout(const Duration(seconds: 20));
    var response = await request();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await _refreshSettings();
      response = await request();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('Anime Witcher Algolia HTTP ${response.statusCode}');
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(response.bodyBytes)) as Map);
  }

  Future<void> _refreshSettings() async {
    try {
      final json = await ExtensionHttp.getJson('$_firestoreBase/Settings/constants');
      final fields = (json as Map)['fields'] as Map?;
      final app = _value(fields?['algolia_app_id'] ?? fields?['algoliaAppId']);
      final key = _value(fields?['algolia_api_key'] ?? fields?['algoliaApiKey']);
      if (app.isNotEmpty) _algoliaAppId = app;
      if (key.isNotEmpty) _algoliaApiKey = key;
    } catch (_) {}
  }

  List<Map<String, dynamic>> _hits(dynamic value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  Map<String, dynamic> _hitToItem(Map<String, dynamic> hit) {
    final idValue = (hit['anime_id'] ?? hit['objectID'] ?? hit['path'] ?? '').toString();
    final encoded = Uri.encodeComponent(idValue);
    return item(
      title: ExtensionHttp.text((hit['name'] ?? hit['title'] ?? 'Anime Witcher').toString()).replaceAll(RegExp(r'</?em>'), ''),
      url: '$_base/watch/$encoded?data=${Uri.encodeComponent(jsonEncode(hit))}',
      image: (hit['poster_uri'] ?? hit['poster_url_aniList'] ?? hit['thumb_uri'] ?? '').toString(),
      type: 'anime',
      genres: hit['tags'] is List ? List<dynamic>.from(hit['tags']) : const [],
      description: ExtensionHttp.text((hit['story'] ?? hit['details']?['story'] ?? '').toString()),
      rating: (hit['rating'] ?? '').toString(),
    )..addAll({'provider_data': hit});
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final uri = Uri.parse(url);
    final animeId = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    Map<String, dynamic> hit = {};
    final raw = uri.queryParameters['data'];
    if (raw != null) {
      try { hit = Map<String, dynamic>.from(jsonDecode(raw) as Map); } catch (_) {}
    }
    if (hit.isEmpty && animeId.isNotEmpty) {
      try {
        final data = await _queryAlgolia('series', '', page: 0, hits: 1);
        final found = _hits(data['hits']).where((e) => '${e['objectID'] ?? e['anime_id']}' == animeId);
        if (found.isNotEmpty) hit = found.first;
      } catch (_) {}
    }
    final path = (hit['doc_ref'] ?? hit['path'] ?? 'anime_list/$animeId').toString().replaceFirst('anime_list/', '');
    final episodes = await _episodes(path);
    final result = _hitToItem({...hit, 'name': hit['name'] ?? animeId, 'anime_id': animeId});
    result['episodes'] = episodes;
    result['total_episodes'] = episodes.length;
    result['status'] = hit['details'] is Map ? hit['details']['state'] : '';
    result['year'] = hit['details'] is Map ? hit['details']['year'] : null;
    return result;
  }

  Future<List<Map<String, dynamic>>> _episodes(String animePath) async {
    try {
      final json = await ExtensionHttp.getJson('$_firestoreBase/anime_list/${Uri.encodeComponent(animePath)}/episodes_summery/summery');
      final fields = (json as Map)['fields'] as Map?;
      final values = fields?['episodes']?['arrayValue']?['values'];
      if (values is! List) return [];
      final episodes = <Map<String, dynamic>>[];
      for (final entry in values) {
        final f = entry['mapValue']?['fields'] as Map? ?? {};
        final id = _value(f['doc_id']);
        final number = int.tryParse(_value(f['number'])) ?? episodes.length + 1;
        final titleMap = f['title_translated']?['mapValue']?['fields'];
        final title = _value(titleMap is Map ? titleMap['ar'] : null).isNotEmpty ? _value(titleMap['ar']) : (_value(f['name']).isEmpty ? 'الحلقة $number' : _value(f['name']));
        episodes.add({'id': id, 'number': number, 'title': title, 'image': _value(f['thumb_uri']), 'url': '$_base/watch/${Uri.encodeComponent(animePath)}?episode_id=${Uri.encodeComponent(id)}'});
      }
      episodes.sort((a, b) => (a['number'] as int).compareTo(b['number'] as int));
      return episodes;
    } catch (_) { return []; }
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async {
    final uri = Uri.parse(url);
    final episodeId = uri.queryParameters['episode_id'];
    if (episodeId == null || episodeId.isEmpty) return null;
    final path = uri.pathSegments.length >= 2 ? Uri.decodeComponent(uri.pathSegments[1]) : '';
    final serverUrl = '$_firestoreBase/anime_list/${Uri.encodeComponent(path)}/episodes/${Uri.encodeComponent(episodeId)}/servers2/all_servers';
    try {
      final json = await ExtensionHttp.getJson(serverUrl);
      final values = (json as Map)['fields']?['servers']?['arrayValue']?['values'];
      final links = <Map<String, String>>[];
      if (values is List) {
        for (final entry in values) {
          final fields = entry['mapValue']?['fields'] as Map? ?? {};
          final link = _value(fields['link']);
          final quality = _value(fields['quality']);
          final name = _value(fields['name']);
          if (link.isEmpty || link.startsWith('<')) continue;
          links.add({'url': link, 'quality': quality.isEmpty ? 'Auto' : quality, 'name': name.isEmpty ? 'Anime Witcher' : name, 'label': name});
        }
      }
      links.sort((a, b) => _quality(b['quality']).compareTo(_quality(a['quality'])));
      if (links.isEmpty) return null;
      return {'stream_url': links.first['url'], 'direct_stream_urls': links, 'headers': {'Referer': _base, 'User-Agent': ExtensionHttp.userAgent}};
    } catch (_) { return null; }
  }

  static int _quality(String? value) => int.tryParse((value ?? '').replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  static String _value(dynamic field) {
    if (field is Map) return (field['stringValue'] ?? field['integerValue'] ?? field['booleanValue'] ?? '').toString();
    return field?.toString() ?? '';
  }
}
