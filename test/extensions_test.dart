import 'package:flutter_test/flutter_test.dart';
import 'package:anitv/extensions/extension_base.dart';
import 'package:anitv/extensions/extension_catalog.dart';
import 'package:anitv/sources/source_registry.dart';

void main() {
  test('extension catalog exposes the three requested providers', () {
    final extensions = ExtensionCatalog.all;
    expect(extensions.map((extension) => extension.id).toSet(), {'anime_witcher', 'egydead', 'youtube'});
    expect(extensions.every((extension) => extension.hosts.isNotEmpty), isTrue);
    expect(extensions.every((extension) => extension.status.isAvailable), isTrue);
  });

  test('extension URLs are routed through the existing source registry', () {
    expect(SourceRegistry.sourceFor('https://animewitcher.com/watch/demo')?.id, 'anime_witcher');
    expect(SourceRegistry.sourceFor('https://tv10.egydead.live/film/demo')?.id, 'egydead');
    expect(SourceRegistry.sourceFor('https://www.youtube.com/watch?v=demo123')?.id, 'youtube');
    expect(SourceRegistry.sourceFor('https://youtu.be/demo123')?.id, 'youtube');
  });
}
