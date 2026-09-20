import 'package:flutter_test/flutter_test.dart';
import 'package:anitv/sources/source_registry.dart';
import 'package:anitv/sources/web_catalog_source.dart';

void main() {
  test('new catalog adapters expose stable identities and hosts', () {
    final sources = <WebCatalogSource>[
      AnimeWitcherSource(),
      Anime3rbSource(),
      WecimaSource(),
      KormozSource(),
    ];
    expect(sources.map((source) => source.id), {
      'anime_witcher',
      'anime3rb',
      'wecima',
      'kormoz',
    });
    expect(sources.every((source) => source.hosts.isNotEmpty), isTrue);
  });

  test('new adapters are visible in the source catalog', () {
    final ids = SourceRegistry.visibleSources.map((source) => source.id).toSet();
    expect(ids, containsAll({'anime_witcher', 'anime3rb', 'wecima', 'kormoz'}));
  });
}
