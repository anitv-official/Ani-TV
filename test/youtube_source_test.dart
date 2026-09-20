import 'package:flutter_test/flutter_test.dart';
import 'package:anitv/sources/source_registry.dart';
import 'package:anitv/sources/youtube_source.dart';

void main() {
  test('YouTube is exposed with YouTube hosts and video kind', () {
    final source = SourceRegistry.visibleSources.whereType<YoutubeSource>().single;
    expect(source.id, 'youtube');
    expect(source.kind, 'youtube');
    expect(source.handles('https://www.youtube.com/watch?v=abc123'), isTrue);
    expect(source.handles('https://youtu.be/abc123'), isTrue);
  });
}
