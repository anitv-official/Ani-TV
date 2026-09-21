import '../services/cloudstream_engine_service.dart';
import '../services/remote_repository_service.dart';
import 'source_base.dart';

class EgydeadSource extends ContentSource {
  static const provider = 'ايجي ديد';
  Future<void>? _ready;

  Future<void> _ensureReady() async {
    _ready ??= remoteRepositoryService.ensureBuiltInReady('Egydead').then((_) {});
    try {
      await _ready;
    } catch (_) {
      _ready = null;
      rethrow;
    }
  }

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
    await _ensureReady();
    final results = await CloudStreamEngineService.search(provider, query.trim());
    return results.map(_mapSearch).where((item) => item['url'].toString().isNotEmpty).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    // The bridge exposes the provider's search contract. An empty query maps
    // to the provider's current catalog and keeps this source usable from the
    // generic in-app source screen instead of rendering an empty page.
    return search('');
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    await _ensureReady();
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
    await _ensureReady();
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
