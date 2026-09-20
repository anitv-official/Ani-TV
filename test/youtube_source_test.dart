import 'package:flutter_test/flutter_test.dart';
import 'package:anitv/sources/source_registry.dart';
import 'package:anitv/sources/youtube_source.dart';
import 'package:anitv/models/remote_plugin.dart';

void main() {
  test('YouTube is exposed with YouTube hosts and video kind', () {
    final source = SourceRegistry.visibleSources.whereType<YoutubeSource>().single;
    expect(source.id, 'youtube');
    expect(source.kind, 'youtube');
    expect(source.handles('https://www.youtube.com/watch?v=abc123'), isTrue);
    expect(source.handles('https://youtu.be/abc123'), isTrue);
  });

  test('YouTube plugin can be persisted as a built-in source', () {
    const plugin = RemotePlugin(
      name: 'YouTube',
      internalName: 'YouTube',
      description: '',
      downloadUrl: 'https://example.com/YouTube.cs3',
      iconUrl: '',
      language: 'en',
      repositoryUrl: 'https://example.com/repo.json',
      fileHash: '',
      version: 1,
      fileSize: 0,
      tvTypes: const ['live'],
      isBuiltIn: true,
    );
    expect(RemotePlugin.fromJson(plugin.toJson()).isBuiltIn, isTrue);
    expect(SourceRegistry.sourceForPlugin(plugin), isA<YoutubeSource>());
  });

  test('YouTube videos expose a playable WebView URL', () async {
    final result = await YoutubeSource().streams('https://www.youtube.com/watch?v=abc123');
    expect(result?['stream_url'], 'https://www.youtube.com/watch?v=abc123');
    expect((result?['direct_stream_urls'] as List).single['type'], 'youtube');
  });
}
