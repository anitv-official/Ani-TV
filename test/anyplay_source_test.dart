import 'package:flutter_test/flutter_test.dart';
import 'package:anitv/sources/anyplay_source.dart';
import 'package:anitv/sources/source_registry.dart';

void main() {
  test('AnyPlay exposes the drama source contract', () {
    final source = AnyPlaySource();
    expect(source.id, 'anyplay');
    expect(source.name, 'AnyPlay');
    expect(source.kind, 'drama');
    expect(source.handles('https://anyplay.stream/tv/1396'), isTrue);
    expect(source.handles('https://www.anyplay.stream/movie/969681'), isTrue);
    expect(SourceRegistry.dramaSources.any((entry) => entry.id == 'anyplay'), isTrue);
  });

  test('AnyPlay media parser extracts direct links from HTML and escaped JSON', () {
    const body = '''
      <video src="https://cdn.example.com/movie.m3u8?token=abc"></video>
      <script type="application/json">
        {"sources":[{"file":"https://cdn.example.com/episode.mp4"}]}
      </script>
    ''';
    final urls = AnyPlaySource.extractPlayableMediaUrls(body);
    expect(urls, contains('https://cdn.example.com/episode.mp4'));
    expect(urls, contains('https://cdn.example.com/movie.m3u8?token=abc'));
  });

  test('AnyPlay URL namespaces distinguish movies, TV, and episodes', () {
    final source = AnyPlaySource();
    expect(source.handles('https://anyplay.stream/movie/123/episode'), isTrue);
    expect(source.handles('https://anyplay.stream/tv/123/season/1/episode/2'), isTrue);
  });
}
