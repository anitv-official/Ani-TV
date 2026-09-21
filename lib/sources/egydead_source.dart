import '../services/cloudstream_engine_service.dart';
import 'source_base.dart';

class EgydeadSource extends ContentSource {
  static const provider = 'ايجي ديد';

  @override
  String get id => 'egydead';

  @override
  String get name => 'Egydead';

  @override
  String get kind => 'movie';

  @override
  List<String> get hosts => const ['egydead.live', 'egydead.com', 'tv10.egydead.live'];

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final results = await CloudStreamEngineService.search(provider, query.trim());
    return results.map(_mapSearch).where((item) => item['url'].toString().isNotEmpty).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async => const [];

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final raw = await CloudStreamEngineService.load(provider, url);
    final result = item(
      title: _text(raw['title'] ?? raw['name'], 'Egydead'),
      url: url,
      image: _text(raw['image_url'] ?? raw['poster_url']),
      type: _text(raw['type'], 'movie'),
      description: _text(raw['plot'] ?? raw['description']),
    );
    final episodes = (raw['episodes'] as List?)
            ?.whereType<Map>()
            .map((episode) => {
                  'title': _text(episode['name'], 'حلقة'),
                  'url': _text(episode['data']),
                  'number': episode['episode'] ?? 0,
                  'season': episode['season'] ?? 1,
                  'image_url': _text(episode['poster_url']),
                })
            .where((episode) => episode['url'].toString().isNotEmpty)
            .toList() ??
        const <Map<String, dynamic>>[];
    result['episodes'] = episodes;
    result['source_id'] = id;
    return result;
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async {
    final links = await CloudStreamEngineService.loadLinks(provider, url);
    final mapped = links
        .map((link) => {
              'url': _text(link['url']),
              'label': _text(link['name'] ?? link['source'], 'Egydead'),
              'name': _text(link['name'] ?? link['source'], 'Egydead'),
              'quality': link['quality'] ?? 'Auto',
              'type': _text(link['type'], 'hls').toLowerCase(),
              'referer': _text(link['referer']),
              if (link['headers'] is Map) 'headers': Map<String, dynamic>.from(link['headers'] as Map),
            })
        .where((link) => _isPlayable(link['url'].toString()))
        .toList();
    if (mapped.isEmpty) return null;
    return {'source_id': id, 'stream_url': mapped.first['url'], 'direct_stream_urls': mapped, 'servers': mapped};
  }

  Map<String, dynamic> _mapSearch(Map<String, dynamic> raw) => item(
        title: _text(raw['title'] ?? raw['name'], 'بدون عنوان'),
        url: _text(raw['url']),
        image: _text(raw['image_url'] ?? raw['poster_url']),
        type: _text(raw['type'], 'movie'),
        description: _text(raw['plot'] ?? raw['description']),
      );

  String _text(dynamic value, [String fallback = '']) => value == null || value.toString().trim().isEmpty ? fallback : value.toString().trim();

  bool _isPlayable(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) return false;
    final lower = value.toLowerCase();
    return RegExp(r'\.(m3u8|mp4|mpd|webm)(?:[?#].*)?$', caseSensitive: false).hasMatch(lower) ||
        lower.contains('embed') || lower.contains('player') || lower.contains('stream') || lower.contains('vid');
  }
}
