import 'package:flutter_test/flutter_test.dart';
import 'package:anitv/sources/faselhd_source.dart';
import 'package:anitv/sources/source_registry.dart';
import 'package:anitv/models/remote_plugin.dart';

void main() {
  test('FaselHD is exposed as the first complete user-facing source', () {
    final source = SourceRegistry.visibleSources.whereType<FaselHdSource>().single;
    expect(source.id, 'fasel_hd');
    expect(source.kind, 'movie');
    expect(source.name, 'FaselHD');
    expect(source.handles('https://kahitdgku.com/faselhd15/public/api/movie/57102/0'), isTrue);
  });

  test('FaselHD source URLs distinguish movie, series, and episode routes', () {
    final source = FaselHdSource();
    expect(source.handles('https://hrrejhp.com/egybestanto/public/api/series/15030/0'), isTrue);
    expect(source.handles('https://hrrejhp.com/egybestanto/public/api/episode/1/0'), isTrue);
  });

  test('movie catalog is backed by the repository-mapped FaselHD adapter', () {
    expect(SourceRegistry.movieSources.whereType<FaselHdSource>(), isEmpty);
    expect(SourceRegistry.visibleSources.whereType<FaselHdSource>(), hasLength(1));
  });

  test('installed repository plugins resolve to their native source adapters', () {
    const plugin = RemotePlugin(
      name: 'Faselhd',
      internalName: 'Faselhd',
      description: '',
      downloadUrl: 'https://example.com/Faselhd.cs3',
      iconUrl: '',
      language: 'ar',
      repositoryUrl: 'https://example.com/repo.json',
      fileHash: '',
      version: 1,
      fileSize: 0,
      tvTypes: const ['movie', 'tvseries'],
    );
    expect(SourceRegistry.sourceForPlugin(plugin), isA<FaselHdSource>());
  });
}
