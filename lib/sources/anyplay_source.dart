import 'dart:convert';

import 'package:http/http.dart' as http;

import 'source_base.dart';

/// AnyPlay movie and TV source.
///
/// AnyPlay exposes TMDB-backed JSON endpoints for metadata and a public iframe
/// embed endpoint. The source deliberately keeps its own URL namespace so a
/// TMDB id cannot collide with another AniTV source.
class AnyPlaySource extends ContentSource {
  static const String _site = 'https://www.anyplay.stream';
  static const String _embed = 'https://anyplay.stream/embed';
  static const String _streamApi = 'https://api.anyplay.stream';
  static const Duration _timeout = Duration(seconds: 20);
  static final http.Client _client = http.Client();

  // These are the public server ids currently advertised by AnyPlay's player.
  // The source treats a failed server independently and still returns the
  // remaining choices.
  static const List<Map<String, String>> _servers = [
    {'id': '68ca4cbd203ee8afe6ee44cb', 'name': 'Server 1 - Fast'},
    {'id': '68ca4cd1203ee8afe6ee44cc', 'name': 'Server 2 - Secure'},
    {'id': '68ca4cdd203ee8afe6ee44cd', 'name': 'Server 3 - HD'},
    {'id': '68ca4cea203ee8afe6ee44ce', 'name': 'Server 4 - Ultra'},
    {'id': '68ca4cf7203ee8afe6ee44cf', 'name': 'Server 5 - Pro'},
    {'id': '68ca4d03203ee8afe6ee44d0', 'name': 'Server 6 - Fast'},
    {'id': '68ca4d15203ee8afe6ee44d1', 'name': 'Server 7 - Ultra'},
    {'id': '68cc06b42672fdfecc749029', 'name': 'Server 8 - Fast'},
    {'id': '68cc56953768c48a4c4055a9', 'name': 'Server 9'},
  ];

  @override
  String get id => 'anyplay';

  @override
  String get name => 'AnyPlay';

  @override
  String get kind => 'drama';

  @override
  List<String> get hosts => const ['anyplay.stream'];

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final data = await _getJson('/api/search', {'query': query.trim()});
    final results = data['results'];
    if (results is! List) return [];
    return results.whereType<Map>().where((raw) {
      final type = raw['media_type']?.toString();
      return type == 'movie' || type == 'tv';
    }).map((raw) {
      final item = Map<String, dynamic>.from(raw);
      final isTv = item['media_type'] == 'tv';
      final tmdbId = item['id']?.toString() ?? '';
      final title = (isTv ? item['name'] : item['title'])?.toString().trim() ?? '';
      return _contentItem(
        title: title.isEmpty ? 'بدون عنوان' : title,
        url: _contentUrl(isTv ? 'tv' : 'movie', tmdbId),
        raw: item,
        isTv: isTv,
      );
    }).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    // AnyPlay does not expose a single catalogue endpoint. Its home page
    // loads these public genre feeds, so use the same feeds for the source
    // catalogue instead of returning an empty list.
    const movieFeeds = ['action', 'comedy', 'drama', 'horror', 'romance', 'sciFi'];
    final feeds = [
      ...movieFeeds.map((genre) => {'path': '/api/movies/genre/$genre', 'isTv': false}),
      {'path': '/api/tv/popular', 'isTv': true},
    ];
    final results = await Future.wait(feeds.map((feed) async {
      try {
        final isTv = feed['isTv'] == true;
        final data = await _getJson(feed['path'] as String, {'page': '$page'});
        final rows = data['results'];
        if (rows is! List) return <Map<String, dynamic>>[];
        return rows.whereType<Map>().map((raw) {
          final item = Map<String, dynamic>.from(raw);
          final title = (isTv ? item['name'] : item['title'])?.toString().trim() ?? '';
          return _contentItem(
            title: title.isEmpty ? 'بدون عنوان' : title,
            url: _contentUrl(isTv ? 'tv' : 'movie', item['id']?.toString() ?? ''),
            raw: item,
            isTv: isTv,
          );
        }).where((item) => item['external_id'].toString().isNotEmpty).toList();
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    }));
    final merged = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final list in results) {
      for (final item in list) {
        if (seen.add('${item['content_type']}:${item['external_id']}')) merged.add(item);
      }
    }
    return merged;
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final parsed = _parseContentUrl(url);
    if (parsed == null) throw Exception('AnyPlay: invalid content URL');
    final type = parsed['type']!;
    final idValue = parsed['id']!;
    final isTv = type == 'tv';
    final raw = await _getJson(isTv ? '/api/tv/$idValue' : '/api/movies/$idValue');
    final result = _contentItem(
      title: ((isTv ? raw['name'] : raw['title'])?.toString().trim().isNotEmpty ?? false)
          ? (isTv ? raw['name'] : raw['title']).toString()
          : 'بدون عنوان',
      url: url,
      raw: raw,
      isTv: isTv,
    );

    if (isTv) {
      final seasons = <Map<String, dynamic>>[];
      final seasonItems = raw['seasons'];
      if (seasonItems is List) {
        for (final season in seasonItems.whereType<Map>()) {
          final number = int.tryParse('${season['season_number'] ?? ''}');
          if (number == null || number <= 0) continue;
          try {
            final seasonData = await _getJson('/api/tv/$idValue/season/$number');
            final episodes = (seasonData['episodes'] is List ? seasonData['episodes'] as List : const [])
                .whereType<Map>()
                .map((episode) => _episode(
                      title: 'الحلقة ${episode['episode_number'] ?? ''}'.trim(),
                      url: _episodeUrl(idValue, number, episode['episode_number']),
                      image: _image(episode['still_path']),
                      rawName: episode['name']?.toString(),
                      number: episode['episode_number'],
                      contentType: 'tv',
                      contentId: idValue,
                    ))
                .where((episode) => episode['url'].toString().isNotEmpty)
                .toList();
            seasons.add({'season_number': number, 'name': season['name'] ?? 'Season $number', 'episodes': episodes});
          } catch (_) {
            // A single unavailable season must not hide the rest of the show.
          }
        }
      }
      result['seasons'] = seasons;
      result['episodes'] = seasons.expand((season) => (season['episodes'] as List?) ?? const []).toList();
    } else {
      result['episodes'] = [_episode(
        title: 'تشغيل الفيلم',
        url: _episodeUrl(idValue, 0, 0, movie: true),
        contentType: 'movie',
        contentId: idValue,
      )];
    }
    return result;
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async {
    final parsed = _parseEpisodeUrl(url);
    if (parsed == null) return null;
    final type = parsed['type']!;
    final idValue = parsed['id']!;
    final season = parsed['season'];
    final episode = parsed['episode'];
    final links = <Map<String, dynamic>>[];
    for (final server in _servers) {
      final serverId = server['id'];
      if (serverId == null || serverId.isEmpty) continue;
      final embed = type == 'movie'
          ? '$_embed/movie/$serverId/$idValue'
          : '$_embed/tv/$serverId/$idValue/$season/$episode';
      links.add({
        'quality': server['name'] ?? 'AnyPlay',
        'server': server['name'] ?? '',
        'server_id': serverId,
        'url': embed,
      });
    }
    if (links.isEmpty) return null;
    // The embed page no longer contains the media URL. It now fetches the
    // actual player from api.anyplay.stream, so resolve every server through
    // that API before handing the URL to the app WebView.
    final resolvedLinks = await Future.wait(links.map((link) async {
      final player = await _resolvePlayerUrl(
        type: type,
        serverId: link['server_id']?.toString() ?? '',
        contentId: idValue,
        season: season,
        episode: episode,
      );
      return {...link, 'url': player ?? link['url']};
    }));
    final resolvedDirect = resolvedLinks.firstWhere(
      (link) => _isPlayablePlayerUrl(link['url']?.toString() ?? ''),
      orElse: () => <String, dynamic>{},
    )['url']?.toString();
    return {
      'source_id': id,
      'stream_url': resolvedDirect ?? links.first['url'],
      'direct_stream_urls': resolvedLinks,
      'headers': {'Referer': '$_site/'},
      'download_links': const <String, dynamic>{},
    };
  }

  Future<String?> _resolvePlayerUrl({
    required String type,
    required String serverId,
    required String contentId,
    String? season,
    String? episode,
  }) async {
    if (serverId.isEmpty) return null;
    final path = type == 'movie'
        ? '/movie/$serverId/$contentId'
        : '/tv/$serverId/$contentId/$season/$episode';
    try {
      final response = await _client.get(Uri.parse('$_streamApi$path'), headers: {
        'Accept': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/122 Safari/537.36',
      }).timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final data = jsonDecode(response.body);
      if (data is! Map) return null;
      final player = data['url']?.toString().trim() ?? '';
      return _isPlayablePlayerUrl(player) ? player : null;
    } catch (_) {
      return null;
    }
  }

  static bool _isPlayablePlayerUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty;
  }

  Future<String?> _resolveDirectMedia(String embedUrl) async {
    try {
      final response = await _client.get(Uri.parse(embedUrl), headers: {
        'Accept': 'text/html,application/xhtml+xml',
        'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/122 Safari/537.36',
      }).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final html = response.body
          .replaceAll(r'\/', '/')
          .replaceAll(r'\u0026', '&')
          .replaceAll(r'\u003a', ':')
          .replaceAll(r'\u002f', '/');
      final candidates = <String>{};
      for (final match in RegExp(r'''(?:https?:)?//[^\s"'<>\\]+(?:\.m3u8|\.mp4|\.mpd)(?:\?[^\s"'<>\\]*)?''', caseSensitive: false).allMatches(html)) {
        final value = match.group(0)!;
        candidates.add(value.startsWith('//') ? 'https:$value' : value);
      }
      for (final match in RegExp(r'''(?:file|src|source|url|stream|playlist)\s*[:=]\s*["']([^"']+)["']''', caseSensitive: false).allMatches(html)) {
        final value = match.group(1)!;
        candidates.add(value.startsWith('//') ? 'https:$value' : value);
      }
      for (final match in RegExp(r'''https?://[^\s"'<>\\]+(?:\.m3u8|\.mp4|\.mpd)(?:\?[^\s"'<>\\]*)?''', caseSensitive: false).allMatches(html)) {
        candidates.add(match.group(0)!);
      }
      candidates.addAll(extractPlayableMediaUrls(html));
      return candidates.firstWhere(_isPlayableMedia, orElse: () => '');
    } catch (_) {
      return null;
    }
  }

  bool _isPlayableMedia(String value) {
    final lower = value.toLowerCase();
    return (lower.startsWith('https://') || lower.startsWith('http://')) &&
        RegExp(r'\.(?:m3u8|mp4|mpd)(?:[?#].*)?$', caseSensitive: false).hasMatch(lower);
  }

  static List<String> extractPlayableMediaUrls(String body) {
    final output = <String>{};
    final media = RegExp(r'''(?:https?:)?//[^\s"'<>\\]+(?:\.m3u8|\.mp4|\.mpd)(?:\?[^\s"'<>\\]*)?''', caseSensitive: false);
    for (final match in media.allMatches(body)) {
      final value = match.group(0)!;
      output.add(value.startsWith('//') ? 'https:$value' : value);
    }
    final fields = RegExp(r'''(?:file|src|source|url|stream|playlist)\s*[:=]\s*["']([^"']+)["']''', caseSensitive: false);
    for (final match in fields.allMatches(body)) {
      final value = match.group(1)!;
      if (RegExp(r'^(?:https?:)?//.+\.(?:m3u8|mp4|mpd)(?:[?#].*)?$', caseSensitive: false).hasMatch(value)) {
        output.add(value.startsWith('//') ? 'https:$value' : value);
      }
    }
    for (final script in RegExp(r'<script[^>]*>([\s\S]*?)</script>', caseSensitive: false)
        .allMatches(body)
        .map((match) => match.group(1)?.trim() ?? '')) {
      try {
        _collectMediaValues(jsonDecode(script), output);
      } catch (_) {}
    }
    return output.toList();
  }

  static void _collectMediaValues(dynamic value, Set<String> output) {
    if (value is String && RegExp(r'^(?:https?:)?//.+\.(?:m3u8|mp4|mpd)(?:[?#].*)?$', caseSensitive: false).hasMatch(value)) {
      output.add(value.startsWith('//') ? 'https:$value' : value);
    } else if (value is Map) {
      for (final child in value.values) {
        _collectMediaValues(child, output);
      }
    } else if (value is List) {
      for (final child in value) {
        _collectMediaValues(child, output);
      }
    }
  }

  Map<String, dynamic> _contentItem({required String title, required String url, required Map<String, dynamic> raw, required bool isTv}) {
    final idValue = raw['id']?.toString() ?? _parseContentUrl(url)?['id'] ?? '';
    final poster = _image(raw['poster_path']);
    final backdrop = _image(raw['backdrop_path'], size: 'original');
    final date = (isTv ? raw['first_air_date'] : raw['release_date'])?.toString() ?? '';
    final genres = (raw['genres'] is List)
        ? (raw['genres'] as List).whereType<Map>().map((genre) => genre['name']).whereType<String>().toList()
        : <dynamic>[];
    return {
      ...item(title: title, url: url, image: poster.isEmpty ? backdrop : poster, type: 'drama', genres: genres, description: raw['overview']?.toString() ?? '', rating: raw['vote_average']?.toString() ?? ''),
      'source': name,
      'source_id': id,
      'external_id': idValue,
      'content_type': isTv ? 'tv' : 'movie',
      'original_title': (isTv ? raw['original_name'] : raw['original_title'])?.toString() ?? '',
      'backdrop_url': backdrop,
      'synopsis': raw['overview']?.toString() ?? '',
      'release_date': date,
      'year': date.length >= 4 ? date.substring(0, 4) : '',
      'duration': isTv ? (raw['episode_run_time'] is List && (raw['episode_run_time'] as List).isNotEmpty ? '${(raw['episode_run_time'] as List).first} دقيقة' : '') : (raw['runtime'] == null ? '' : '${raw['runtime']} دقيقة'),
      'total_episodes': raw['number_of_episodes'] ?? 0,
    };
  }

  Map<String, dynamic> _episode({required String title, required String url, String image = '', String? rawName, dynamic number, required String contentType, required String contentId}) => {
        'title': title.replaceAll(RegExp(r'\s+'), ' ').trim(),
        'url': url,
        'image': image,
        'name': rawName ?? title,
        'number': number,
        'content_type': contentType,
        'external_id': contentId,
      };

  Future<Map<String, dynamic>> _getJson(String path, [Map<String, String>? query]) async {
    final uri = Uri.parse('$_site$path').replace(queryParameters: query);
    final response = await _client.get(uri, headers: {'Accept': 'application/json'}).timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('AnyPlay HTTP ${response.statusCode}');
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw Exception('AnyPlay returned invalid JSON');
    return Map<String, dynamic>.from(decoded);
  }

  String _contentUrl(String type, String idValue) => '$_site/$type/$idValue';
  String _episodeUrl(String idValue, int season, dynamic episode, {bool movie = false}) => movie ? '$_site/movie/$idValue/episode' : '$_site/tv/$idValue/season/$season/episode/${episode ?? ''}';
  String _image(dynamic path, {String size = 'w500'}) => path == null || path.toString().isEmpty ? '' : 'https://image.tmdb.org/t/p/$size${path.toString().startsWith('/') ? path : '/$path'}';

  Map<String, String>? _parseContentUrl(String url) {
    final match = RegExp(r'anyplay\.stream/(movie|tv)/(\d+)', caseSensitive: false).firstMatch(url);
    return match == null ? null : {'type': match.group(1)!.toLowerCase(), 'id': match.group(2)!};
  }

  Map<String, String>? _parseEpisodeUrl(String url) {
    final movie = RegExp(r'anyplay\.stream/movie/(\d+)/episode', caseSensitive: false).firstMatch(url);
    if (movie != null) return {'type': 'movie', 'id': movie.group(1)!};
    final tv = RegExp(r'anyplay\.stream/tv/(\d+)/season/(\d+)/episode/(\d+)', caseSensitive: false).firstMatch(url);
    if (tv != null) return {'type': 'tv', 'id': tv.group(1)!, 'season': tv.group(2)!, 'episode': tv.group(3)!};
    return null;
  }
}
