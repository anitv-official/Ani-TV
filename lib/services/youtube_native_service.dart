import 'package:flutter/services.dart';

class YoutubeNativeService {
  YoutubeNativeService._();

  static const MethodChannel _channel = MethodChannel('com.anitv.app/youtube');

  static Future<Map<String, dynamic>?> extractStreams(String url) async {
    if (url.trim().isEmpty) return null;
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'extractStreams',
      <String, dynamic>{'url': url.trim()},
    );
    if (raw == null) return null;
    final result = Map<String, dynamic>.from(raw);
    final streams = (result['streams'] as List?)
            ?.whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((item) => item['url'] is String && (item['url'] as String).isNotEmpty)
            .toList() ??
        const <Map<String, dynamic>>[];
    if (streams.isEmpty) return null;
    return {
      'source_id': 'youtube_native',
      'stream_url': streams.first['url'],
      'direct_stream_urls': streams,
      'servers': streams,
      'subtitles': result['subtitles'] ?? const [],
      'headers': const <String, String>{'Referer': 'https://www.youtube.com/'},
    };
  }
}
