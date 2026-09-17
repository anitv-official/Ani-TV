import 'package:flutter_test/flutter_test.dart';
import 'package:anitv/sources/manga_dar_source.dart';
import 'package:anitv/sources/source_registry.dart';

void main() {
  test('Manga Dar remains unavailable after source removal', () {
    final source = MangaDarSource();
    expect(source.id, 'manga_dar');
    expect(source.name, 'Manga Dar');
    expect(source.kind, 'manga');
    expect(source.handles('https://mangadar.com/manga/one-piece/'), isTrue);
    expect(source.handles('mangadar://manga/one-piece'), isTrue);
    expect(SourceRegistry.mangaSources.any((entry) => entry.id == 'manga_dar'), isFalse);
  });
}
