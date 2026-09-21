import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import '../extension_base.dart';
import '../../sources/source_base.dart';
import 'extension_http.dart';

class Anime3rbExtension extends AniExtension {
  static const _base = 'https://anime3rb.com/';
  static const _playerHost = 'video.vid3rb.com';
  final http.Client _client = http.Client();
  final Map<String, String> _cookies = {};

  @override String get id => 'anime3rb';
  @override String get name => 'Anime3rb';
  @override String get kind => 'anime';
  @override List<String> get hosts => const ['anime3rb.com'];
  @override String get contentLabel => 'أنمي';
  @override String get iconUrl => 'https://anime3rb.com/favicon.ico';
  @override ExtensionStatus get status => ExtensionStatus.limited;
  @override String get statusMessage => 'بحث Livewire وروابط فيديو خارجية';

  Map<String, String> _headers({String? referer}) => {
        'User-Agent': ExtensionHttp.userAgent,
        'Accept': 'text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8',
        'Accept-Language': 'ar,en-US;q=0.9,en;q=0.8',
        if (referer != null) 'Referer': referer,
        if (_cookies.isNotEmpty) 'Cookie': _cookies.entries.map((e) => '${e.key}=${e.value}').join('; '),
      };

  Future<http.Response> _get(String url, {String? referer}) async {
    final response = await _client.get(Uri.parse(url), headers: _headers(referer: referer)).timeout(const Duration(seconds: 25));
    _saveCookies(response);
    return response;
  }

  void _saveCookies(http.Response response) {
    final value = response.headers['set-cookie'];
    if (value == null) return;
    for (final part in value.split(RegExp(r', (?=[^;,]+=)'))) {
      final pair = part.split(';').first.split('=');
      if (pair.length >= 2) _cookies[pair.first.trim()] = pair.sublist(1).join('=').trim();
    }
  }

  String _abs(String value, String base) => Uri.parse(base).resolve(value.trim()).toString();
  String _clean(String value) => SourceUtils.cleanTitle(value.replaceAll(RegExp(r'\s+'), ' ').replaceFirst(RegExp(r'بترجمة.*$', caseSensitive: false), '').trim());
  String _image(dynamic node, String pageUrl) {
    if (node == null) return '';
    final attrs = node.attributes as Map<String, String>;
    final value = (attrs['src'] ?? attrs['data-src'] ?? '').trim();
    return value.isEmpty ? '' : _abs(value, pageUrl);
  }

  @override Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    try {
      final response = await _get(_base);
      if (response.statusCode >= 400) return [];
      final doc = html_parser.parse(utf8.decode(response.bodyBytes, allowMalformed: true));
      final results = <Map<String, dynamic>>[];
      for (final card in doc.querySelectorAll('#videos a.video-card, a.video-card')) {
        final href = card.attributes['href'];
        if (href == null || href.isEmpty) continue;
        final title = _clean(card.querySelector('h3.title-name')?.text ?? card.text);
        if (title.isEmpty) continue;
        results.add(_item(title, _abs(href, _base), _image(card.querySelector('img'), _base)));
      }
      return _dedupe(results);
    } catch (_) { return []; }
  }

  @override Future<List<Map<String, dynamic>>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return latest();
    try {
      final home = await _get(_base);
      if (home.statusCode >= 400) return [];
      final doc = html_parser.parse(utf8.decode(home.bodyBytes, allowMalformed: true));
      final csrf = doc.querySelector('meta[name="csrf-token"]')?.attributes['content'] ?? doc.querySelector('input[name="_token"]')?.attributes['value'] ?? '';
      final component = doc.querySelector('[wire\:snapshot]');
      final snapshot = component?.attributes['wire:snapshot'] ?? '';
      if (csrf.isEmpty || snapshot.isEmpty) return [];
      final payload = {
        '_token': csrf,
        'components': [{'snapshot': snapshot, 'updates': {'query': value}, 'calls': []}],
      };
      final response = await _client.post(Uri.parse('${_base}livewire/update'), headers: {..._headers(referer: _base), 'Content-Type': 'application/json', 'Accept': 'application/json', 'Origin': 'https://anime3rb.com'}, body: jsonEncode(payload)).timeout(const Duration(seconds: 25));
      _saveCookies(response);
      final data = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
      final html = data['components']?[0]?['effects']?['html']?.toString() ?? '';
      final resultDoc = html_parser.parse(html);
      return _dedupe(resultDoc.querySelectorAll('a.simple-title-card').map((card) {
        final href = card.attributes['href'] ?? '';
        final title = _clean(card.querySelector('h4')?.text ?? card.text);
        return _item(title, _abs(href, _base), _image(card.querySelector('img'), _base));
      }).where((e) => e['title'].toString().isNotEmpty).toList());
    } catch (_) { return []; }
  }

  Map<String, dynamic> _item(String title, String url, String image) => item(title: title, url: url, image: image, type: 'anime');
  List<Map<String, dynamic>> _dedupe(List<Map<String, dynamic>> values) {
    final seen = <String>{};
    return values.where((e) => seen.add(e['url'].toString())).toList();
  }

  @override Future<Map<String, dynamic>> details(String url) async {
    final response = await _get(url, referer: _base);
    final doc = html_parser.parse(utf8.decode(response.bodyBytes, allowMalformed: true));
    final title = _clean(doc.querySelector('h1')?.text ?? name);
    final poster = _image(doc.querySelector('img[alt*="بوستر"], .poster img'), url);
    final episodes = <Map<String, dynamic>>[];
    for (final link in doc.querySelectorAll('.video-list a[href]')) {
      final href = link.attributes['href'] ?? '';
      if (href.isEmpty) continue;
      final data = link.querySelector('.video-data');
      final parts = data?.children ?? const [];
      final rawNumber = parts.isNotEmpty ? parts.first.text : link.text;
      final rawTitle = parts.length > 1 ? parts[1].text : link.text;
      final number = int.tryParse(RegExp(r'\d+').firstMatch(rawNumber)?.group(0) ?? '') ?? episodes.length + 1;
      episodes.add({'id': '${number}', 'title': _clean(rawTitle).isEmpty ? 'الحلقة $number' : _clean(rawTitle), 'number': number, 'season': 1, 'url': _abs(href, url), 'image': _image(link.querySelector('img'), url).isEmpty ? poster : _image(link.querySelector('img'), url)});
    }
    episodes.sort((a, b) => (a['number'] as int).compareTo(b['number'] as int));
    return {..._item(title, url, poster), 'episodes': episodes, 'total_episodes': episodes.length};
  }

  @override Future<Map<String, dynamic>?> streams(String url) async {
    try {
      final response = await _get(url, referer: _base);
      final html = utf8.decode(response.bodyBytes, allowMalformed: true);
      final player = RegExp(r'https?://video\.vid3rb\.com/player[^"\'\\ ]+', caseSensitive: false).firstMatch(html)?.group(0);
      if (player == null) return null;
      final playerResponse = await _client.get(Uri.parse(player.replaceAll(r'\\/', '/').replaceAll('&amp;', '&')), headers: {..._headers(referer: _base), 'Referer': _base, 'Sec-Fetch-Dest': 'iframe'}).timeout(const Duration(seconds: 25));
      final playerHtml = utf8.decode(playerResponse.bodyBytes, allowMalformed: true);
      final match = RegExp(r'var\s+video_sources\s*=\s*(\[.*?\])\s*;', dotAll: true).firstMatch(playerHtml);
      if (match == null) return null;
      final raw = jsonDecode(match.group(1)!) as List;
      final links = <Map<String, String>>[];
      for (final entry in raw.whereType<Map>()) {
        if (entry['premium'] == true || entry['premium'].toString().toLowerCase() == 'true') continue;
        final src = entry['src']?.toString().replaceAll(r'\\/', '/').replaceAll('&amp;', '&') ?? '';
        if (src.isEmpty) continue;
        final label = entry['label']?.toString() ?? 'Auto';
        links.add({'url': src, 'quality': RegExp(r'\d{3,4}').firstMatch(label)?.group(0) ?? 'Auto', 'name': 'Anime3rb', 'label': label, 'type': 'video'});
      }
      if (links.isEmpty) return null;
      return {'stream_url': links.first['url'], 'direct_stream_urls': links, 'headers': {'Referer': 'https://video.vid3rb.com/', 'User-Agent': ExtensionHttp.userAgent}, 'allowed_hosts': [_playerHost]};
    } catch (_) { return null; }
  }
}
