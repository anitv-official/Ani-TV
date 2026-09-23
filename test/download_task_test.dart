import 'package:flutter_test/flutter_test.dart';
import 'package:anitv/models/download_task.dart';

void main() {
  test('DownloadTask preserves typed state and progress fields', () {
    final task = DownloadTask.fromMap({
      'id': 'anime:a/episode-1',
      'content_id': 'a',
      'kind': 'anime',
      'title': 'A',
      'episode': 'Episode 1',
      'status': 'downloading',
      'progress': .68,
      'bytes': 245,
      'total': 360,
      'speed': 12,
      'eta_seconds': 10,
      'retry_count': 1,
    });

    expect(task.contentType, DownloadContentType.anime);
    expect(task.status, DownloadStatus.downloading);
    expect(task.progress, .68);
    expect(task.downloadedBytes, 245);
    expect(task.totalBytes, 360);
    expect(task.speedBytesPerSecond, 12);
    expect(task.etaSeconds, 10);
    expect(DownloadTask.fromMap(task.toMap()).status, DownloadStatus.downloading);
  });

  test('unknown legacy values remain safely representable', () {
    final task = DownloadTask.fromMap({'id': 'legacy', 'kind': 'old-kind', 'status': 'old-status'});
    expect(task.contentType, DownloadContentType.unknown);
    expect(task.status, DownloadStatus.queued);
  });
}
