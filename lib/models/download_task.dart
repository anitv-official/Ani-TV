enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
  waiting,
  retrying,
}

enum DownloadContentType {
  anime,
  manga,
  manhwa,
  manhua,
  novel,
  movie,
  series,
  episode,
  video,
  chapter,
  season,
  unknown,
}

class DownloadTask {
  final String id;
  final String contentId;
  final DownloadContentType contentType;
  final String title;
  final String episode;
  final String chapter;
  final String season;
  final String url;
  final String path;
  final String coverUrl;
  final DownloadStatus status;
  final double progress;
  final int downloadedBytes;
  final int totalBytes;
  final int speedBytesPerSecond;
  final int etaSeconds;
  final int retryCount;
  final String error;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  const DownloadTask({
    required this.id,
    this.contentId = '',
    this.contentType = DownloadContentType.unknown,
    this.title = '',
    this.episode = '',
    this.chapter = '',
    this.season = '',
    this.url = '',
    this.path = '',
    this.coverUrl = '',
    this.status = DownloadStatus.queued,
    this.progress = 0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.speedBytesPerSecond = 0,
    this.etaSeconds = 0,
    this.retryCount = 0,
    this.error = '',
    this.createdAt,
    this.startedAt,
    this.completedAt,
  });

  factory DownloadTask.fromMap(Map<String, dynamic> map) => DownloadTask(
        id: map['id']?.toString() ?? '',
        contentId: map['content_id']?.toString() ?? '',
        contentType: _contentType(map['kind']?.toString()),
        title: map['title']?.toString() ?? '',
        episode: map['episode']?.toString() ?? '',
        chapter: map['chapter']?.toString() ?? '',
        season: map['season']?.toString() ?? '',
        url: map['url']?.toString() ?? '',
        path: map['path']?.toString() ?? '',
        coverUrl: map['cover_url']?.toString() ?? '',
        status: _status(map['status']?.toString()),
        progress: (map['progress'] is num ? (map['progress'] as num).toDouble() : 0).clamp(0, 1).toDouble(),
        downloadedBytes: _int(map['bytes']),
        totalBytes: _int(map['total']),
        speedBytesPerSecond: _int(map['speed']),
        etaSeconds: _int(map['eta_seconds']),
        retryCount: _int(map['retry_count']),
        error: map['error']?.toString() ?? '',
        createdAt: _date(map['created_at'] ?? map['timestamp']),
        startedAt: _date(map['started_at']),
        completedAt: _date(map['completed_at']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'content_id': contentId,
        'kind': contentType.name,
        'title': title,
        'episode': episode,
        'chapter': chapter,
        'season': season,
        'url': url,
        'path': path,
        'cover_url': coverUrl,
        'status': status.name,
        'progress': progress,
        'bytes': downloadedBytes,
        'total': totalBytes,
        'speed': speedBytesPerSecond,
        'eta_seconds': etaSeconds,
        'retry_count': retryCount,
        'error': error,
        'created_at': createdAt?.toIso8601String(),
        'started_at': startedAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
      };

  static int _int(dynamic value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
  static DateTime? _date(dynamic value) => value == null ? null : DateTime.tryParse(value.toString());
  static DownloadStatus _status(String? value) => DownloadStatus.values.firstWhere((item) => item.name == value, orElse: () => DownloadStatus.queued);
  static DownloadContentType _contentType(String? value) => DownloadContentType.values.firstWhere((item) => item.name == value?.toLowerCase(), orElse: () => DownloadContentType.unknown);
}
