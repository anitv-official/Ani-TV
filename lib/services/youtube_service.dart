import 'package:flutter/services.dart';

class YoutubeVideo {
  final String url;
  final String title;
  final String thumbnailUrl;
  final String uploader;
  final String uploaded;
  final String description;
  final int durationSeconds;
  final int viewCount;

  const YoutubeVideo({
    required this.url,
    required this.title,
    this.thumbnailUrl = '',
    this.uploader = '',
    this.uploaded = '',
    this.description = '',
    this.durationSeconds = 0,
    this.viewCount = -1,
  });

  factory YoutubeVideo.fromMap(Map<Object?, Object?> value) {
    return YoutubeVideo(
      url: value['url']?.toString() ?? '',
      title: value['title']?.toString() ?? 'فيديو بدون عنوان',
      thumbnailUrl: value['thumbnail']?.toString() ?? '',
      uploader: value['uploader']?.toString() ?? '',
      uploaded: value['uploaded']?.toString() ?? '',
      description: value['description']?.toString() ?? '',
      durationSeconds: _asInt(value['duration']),
      viewCount: _asInt(value['views'], fallback: -1),
    );
  }

  Map<String, dynamic> toMap() => {
        'url': url,
        'title': title,
        'thumbnail': thumbnailUrl,
        'uploader': uploader,
        'uploaded': uploaded,
        'description': description,
        'duration': durationSeconds,
        'views': viewCount,
      };
}

class YoutubeStream {
  final String url;
  final String quality;
  final String format;

  const YoutubeStream({
    required this.url,
    required this.quality,
    this.format = '',
  });

  factory YoutubeStream.fromMap(Map<Object?, Object?> value) {
    return YoutubeStream(
      url: value['url']?.toString() ?? '',
      quality: value['quality']?.toString() ?? 'تلقائي',
      format: value['format']?.toString() ?? '',
    );
  }

  Map<String, String> toPlayerMap() => {
        'url': url,
        'quality': quality,
        'label': quality,
      };
}

class YoutubePlayback {
  final YoutubeVideo video;
  final List<YoutubeStream> streams;
  final List<YoutubeVideo> related;

  const YoutubePlayback({
    required this.video,
    required this.streams,
    required this.related,
  });

  factory YoutubePlayback.fromMap(Map<Object?, Object?> value) {
    final streams = _mapList(value['streams'], YoutubeStream.fromMap)
        .where((stream) => stream.url.isNotEmpty)
        .toList(growable: false);
    return YoutubePlayback(
      video: YoutubeVideo.fromMap(value),
      streams: streams,
      related: _mapList(value['related'], YoutubeVideo.fromMap)
          .where((video) => video.url.isNotEmpty)
          .toList(growable: false),
    );
  }
}

class YoutubeService {
  static const MethodChannel _channel =
      MethodChannel('com.anitv.app/youtube');

  const YoutubeService();

  Future<List<YoutubeVideo>> search(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];
    final response = await _invokeMap('search', {'query': normalized});
    return _mapList(response['items'], YoutubeVideo.fromMap)
        .where((video) => video.url.isNotEmpty)
        .toList(growable: false);
  }

  Future<YoutubePlayback> streams(String videoUrl) async {
    final response = await _invokeMap('streams', {'url': videoUrl});
    final playback = YoutubePlayback.fromMap(response);
    if (playback.streams.isEmpty) {
      throw const YoutubeServiceException(
        'لا يتوفر لهذا الفيديو مسار تدريجي يمكن تشغيله داخل التطبيق.',
      );
    }
    return playback;
  }

  Future<List<YoutubeVideo>> related(String videoUrl) async {
    final response = await _invokeMap('related', {'url': videoUrl});
    return _mapList(response['items'], YoutubeVideo.fromMap)
        .where((video) => video.url.isNotEmpty)
        .toList(growable: false);
  }

  Future<Map<Object?, Object?>> _invokeMap(
    String method,
    Map<String, Object> arguments,
  ) async {
    try {
      final response =
          await _channel.invokeMethod<Map<Object?, Object?>>(method, arguments);
      if (response == null) {
        throw const YoutubeServiceException('لم تصل استجابة من خدمة يوتيوب.');
      }
      return response;
    } on PlatformException catch (error) {
      throw YoutubeServiceException(
        error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'تعذر الاتصال بيوتيوب.',
      );
    } on MissingPluginException {
      throw const YoutubeServiceException(
        'خدمة يوتيوب متاحة في نسخة أندرويد فقط.',
      );
    }
  }
}

class YoutubeServiceException implements Exception {
  final String message;
  const YoutubeServiceException(this.message);

  @override
  String toString() => message;
}

List<T> _mapList<T>(
  Object? value,
  T Function(Map<Object?, Object?> value) convert,
) {
  if (value is! List) return <T>[];
  return value
      .whereType<Map>()
      .map((entry) => convert(Map<Object?, Object?>.from(entry)))
      .toList(growable: false);
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
