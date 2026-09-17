import 'dart:convert';
import 'package:http/http.dart' as http;
import 'source_base.dart';

/// FaselHD source. The API domain is refreshed from the public config file
/// used by the Android client, with a known working fallback.
class FaselHdSource extends ContentSource {
  static const _configUrl = 'https://abcdefegh.watchit.tn/api_urls.json';
  static const _fallbackApi = 'https://kahitdgku.com/faselhd15/public/api/';
  static const _userAgent = 'okhttp/4.10.0';
  final http.Client _client = http.Client();
  final Map<String, Map<String, dynamic>> _cache = {};
  String _base = _fallbackApi;

  @override String get id => 'fasel_hd';
  @override String get name => 'FaselHD';
  @override String get kind => 'movie';
  @override List<String> get hosts => const ['kahitdgku.com', 'abcdef.flech.tn', 'hrrejhp.com', 'fashd.com'];

  Future<void> _refreshBase() async {
    try {
      final r = await _client.get(Uri.parse(_configUrl), headers: const {'Accept': 'application/json'}).timeout(const Duration(seconds: 12));
      final x = jsonDecode(r.body);
      final value = x is Map ? (x['backupApiUrlNoureddine'] ?? x['backupApiUrlhadr']) : null;
      if (value is String && value.startsWith('http')) _base = value.endsWith('/') ? value : '$value/';
    } catch (_) {}
  }

  @override Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    await _refreshBase();
    final movies = await _get('movies/latestadded/0?page=$page');
    final series = await _get('series/latestadded/0?page=$page');
    return [..._items(movies['data']), ..._items(series['data'])];
  }

  @override Future<List<Map<String, dynamic>>> search(String query) async {
    await _refreshBase();
    final response = await _get('search/${Uri.encodeComponent(query.trim())}/0');
    final raw = response['search'] ?? response['data'] ?? response['results'] ?? response['items'];
    final result = _items(raw);
    if (result.isNotEmpty) return result;
    final home = await _get('media/homecontent/0');
    final q = query.trim().toLowerCase();
    return _items(home['latest'] ?? home['data']).where((x) =>
      q.isEmpty || x['title'].toString().toLowerCase().contains(q)).toList();
  }

  @override Future<Map<String, dynamic>> details(String url) async {
    await _refreshBase();
    final parsed = _parse(url);
    final path = parsed.type == 'series' ? 'series/showplayer/${parsed.id}/0' : 'media/detail/${parsed.id}/0';
    final raw = await _get(path);
    final result = _normalize(raw, parsed.type, parsed.id);
    _cache[url] = result;
    return result;
  }

  @override Future<Map<String, dynamic>?> streams(String url) async {
    await _refreshBase();
    final parsed = _parse(url);
    final cached = _cache[url];
    dynamic videos = cached?['videos'];
    if (videos is! List || videos.isEmpty) {
      final path = parsed.type == 'episode'
          ? 'series/episode/${parsed.id}/0'
          : 'media/detail/${parsed.id}/0';
      final fresh = await _get(path);
      videos = fresh['videos'] ?? fresh['episode_stream'] ?? fresh['data'];
    }
    final sourceVideos = videos is List ? videos : const [];
    final links = <Map<String, dynamic>>[];
    for (final v in sourceVideos.whereType<Map>()) {
      final link = _playerUrl(_text(v['link'] ?? v['url'] ?? v['file']));
      if (link.isEmpty || !_safePlayable(link)) continue;
      final label = _text(v['server'] ?? v['name'] ?? v['video_name'], 'FaselHD');
      links.add({'url': link, 'label': label, 'name': label, 'type': 'embed', 'referer': _text(v['header'])});
    }
    if (links.isEmpty) {
      final raw = await _get(parsed.type == 'episode'
          ? 'series/episode/${parsed.id}/0'
          : 'stream/show/${parsed.id}/0');
      _collectVideos(raw, links);
    }
    final unique = <String, Map<String, dynamic>>{};
    for (final x in links) unique[x['url'] as String] = x;
    if (unique.isEmpty) return null;
    return {'stream_url': unique.values.first['url'], 'direct_stream_urls': unique.values.toList(), 'servers': unique.values.toList(), 'title': 'مصادر FaselHD'};
  }

  List<Map<String, dynamic>> _items(dynamic raw) {
    if (raw is! List) return [];
    final result = <Map<String, dynamic>>[];
    for (final value in raw.whereType<Map>()) {
      final id = _text(value['id']);
      final isSeries = _text(value['type']).toLowerCase() == 'serie' || _text(value['type']).toLowerCase() == 'series';
      if (id.isEmpty) continue;
      final path = isSeries ? 'series' : 'movie';
      final catalogItem = item(title: _text(value['title'] ?? value['name'], 'بدون عنوان'), url: '$_base$path/$id/0', image: _text(value['poster_path'] ?? value['poster']), type: isSeries ? 'مسلسل' : 'فيلم', description: _description(value), rating: _text(value['vote_average']));
      result.add(catalogItem);
      _cache[catalogItem['url'].toString()] = catalogItem;
    }
    return result;
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> raw, String type, String id) {
    final title = _text(raw['title'] ?? raw['name'], 'بدون عنوان');
    final image = _text(raw['poster_path'] ?? raw['poster']);
    final result = <String, dynamic>{...item(title: title, url: '$_base$type/$id/0', image: image, type: type == 'series' ? 'مسلسل' : 'فيلم', description: _description(raw), rating: _text(raw['vote_average'])), 'backdrop': _text(raw['backdrop_path']), 'year': raw['release_date'] ?? raw['first_air_date'] ?? '', 'videos': <Map>[]};
    if (type == 'series') {
      final episodes = <Map<String, dynamic>>[];
      final seasons = raw['seasons'];
      if (seasons is List) {
        for (final season in seasons.whereType<Map>()) {
          final eps = season['episodes'];
          if (eps is List) for (final ep in eps.whereType<Map>()) {
            final epUrl = '${_base}episode/${_text(ep['id'])}/0';
            final entry = {'title': _text(ep['name'], 'الحلقة ${ep['episode_number'] ?? ''}'), 'url': epUrl, 'episode_id': _text(ep['id']), 'number': ep['episode_number'] ?? '', 'videos': ep['videos'] is List ? ep['videos'] : const []};
            episodes.add(entry);
            _cache[epUrl] = {...item(title: entry['title'] as String, url: epUrl, type: 'حلقة'), 'videos': entry['videos']};
          }
        }
      }
      result['episodes'] = episodes;
    } else {
      result['videos'] = raw['videos'] is List ? raw['videos'] : const [];
    }
    _cache[result['url'].toString()] = result;
    return result;
  }

  void _collectVideos(dynamic raw, List<Map<String, dynamic>> output) {
    if (raw is List) for (final x in raw) _collectVideos(x, output);
    if (raw is Map) {
      final link = _text(raw['link'] ?? raw['url'] ?? raw['file']);
      final player = _playerUrl(_text(raw['link'] ?? raw['url'] ?? raw['file']));
      if (player.isNotEmpty && _safePlayable(player)) output.add({'url': player, 'label': _text(raw['server'], 'FaselHD'), 'name': _text(raw['server'], 'FaselHD'), 'type': 'embed', 'referer': _text(raw['header'])});
      for (final key in ['videos', 'episode_stream', 'data', 'streams', 'servers']) _collectVideos(raw[key], output);
    }
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final uri = Uri.parse('$_base$path');
    final r = await _client.get(uri, headers: const {'Accept': 'application/json', 'User-Agent': _userAgent}).timeout(const Duration(seconds: 35));
    if (r.statusCode < 200 || r.statusCode >= 300) throw Exception('تعذر الاتصال بـ FaselHD (${r.statusCode})');
    final x = jsonDecode(utf8.decode(r.bodyBytes, allowMalformed: true));
    if (x is! Map) throw Exception('استجابة FaselHD غير صالحة');
    return Map<String, dynamic>.from(x);
  }

  ({String type, String id}) _parse(String url) {
    final p = Uri.parse(url).pathSegments;
    final i = p.indexWhere((x) => x == 'movie' || x == 'series' || x == 'episode');
    if (i < 0 || i + 1 >= p.length) throw Exception('رابط FaselHD غير صالح');
    return (type: p[i] == 'movie' ? 'movie' : p[i] == 'episode' ? 'episode' : 'series', id: p[i + 1]);
  }

  String _description(Map raw) {
    final value = _text(raw['overview'] ?? raw['description']);
    if (value.isNotEmpty) return value;
    return _text(raw['subtitle']);
  }
  String _playerUrl(String value) {
    final match = RegExp(r'^https?://down\.vidtube\.one/([^/?#]+)\.html', caseSensitive: false).firstMatch(value);
    if (match != null) return 'https://vidtube.one/embed-${match.group(1)}.html';
    final uq = RegExp(r'^https?://(?:www\.)?uqload\.(?:cx|io|net|vc)/([^/?#]+)\.html', caseSensitive: false).firstMatch(value);
    if (uq != null && !value.toLowerCase().contains('/embed-')) return 'https://uqload.${Uri.parse(value).host.split('.').last}/embed-${uq.group(1)}.html';
    final wish = RegExp(r'^https?://(?:www\.)?streamwish\.(?:fun|to)/([^/?#]+)', caseSensitive: false).firstMatch(value);
    if (wish != null && !value.toLowerCase().contains('/e/')) return 'https://streamwish.fun/e/${wish.group(1)}';
    return value;
  }
  String _text(dynamic value, [String fallback = '']) => value == null || value.toString().trim().isEmpty || value.toString() == 'false' ? fallback : SourceUtils.cleanTitle(value.toString());
  bool _safePlayable(String value) { final u = Uri.tryParse(value); if (u == null || (u.scheme != 'http' && u.scheme != 'https')) return false; final s = value.toLowerCase(); return RegExp(r'\.(mp4|m3u8|webm|mpd)(?:[?#].*)?$').hasMatch(s) || RegExp(r'(vidtube|vidto|uqload|streamtape|filemoon|streamwish|voe|dood|mp4upload|mixdrop|yourupload|updown\.icu)').hasMatch(s); }
}
