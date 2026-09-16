import 'package:flutter_test/flutter_test.dart';
import 'package:anitv/sources/mangatime_source.dart';
import 'package:anitv/sources/source_registry.dart';

void main() {
  test('MangaTime exposes the shared manga source contract', () {
    final source = MangaTimeSource();
    expect(source.id, 'mangatime');
    expect(source.name, 'MangaTime');
    expect(source.kind, 'manga');
    expect(source.handles('mangatime://series/naruto-digital-colored?id=series-1'), isTrue);
    expect(source.handles('https://mangatime.org/series/naruto-digital-colored'), isTrue);
    expect(SourceRegistry.mangaSources.any((entry) => entry.id == 'mangatime'), isTrue);
  });

  test('MangaTime keeps chapter identifiers source-specific', () {
    final source = MangaTimeSource();
    expect(source.handles('mangatime://chapter?id=chapter-1&number=12'), isTrue);
  });
}
