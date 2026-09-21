import 'package:flutter_test/flutter_test.dart';
import 'package:anitv/sources/faselhd_source.dart';
import 'package:anitv/sources/source_registry.dart';

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

  test('movie catalog is backed by the FaselHD adapter', () {
    expect(SourceRegistry.visibleSources.whereType<FaselHdSource>(), hasLength(1));
  });

}
