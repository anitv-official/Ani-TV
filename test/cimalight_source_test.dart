import 'package:flutter_test/flutter_test.dart';
import 'package:anitv/sources/cimalight_source.dart';
import 'package:anitv/sources/source_registry.dart';

void main() {
  test('CimaLight is registered as a drama/movie source', () {
    final source = CimaLightSource();
    expect(source.id, 'cimalight');
    expect(source.name, 'CimaLight');
    expect(source.kind, 'drama');
    expect(source.handles('https://e.cimalight.co/watch.php?vid=80bc48ee5'), isTrue);
    expect(SourceRegistry.dramaSources.any((entry) => entry.id == 'cimalight'), isTrue);
  });

  test('CimaLight parses watch cards and deduplicates them', () {
    const html = '''
      <a href="https://e.cimalight.co/watch.php?vid=abc123" title="فيلم تجريبي 2026">
        <img src="/uploads/thumbs/test-1.jpg" alt="فيلم تجريبي 2026">
      </a>
      <a href="/watch.php?vid=abc123" title="فيلم تجريبي 2026">فيلم تجريبي 2026</a>
    ''';
    final cards = CimaLightSource.parseCards(html, 'https://e.cimalight.co');
    expect(cards, hasLength(1));
    expect(cards.single['title'], 'فيلم تجريبي 2026');
    expect(cards.single['url'], 'https://e.cimalight.co/watch.php?vid=abc123');
  });
}
