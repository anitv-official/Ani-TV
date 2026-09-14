import 'package:flutter_test/flutter_test.dart';
import 'package:anitv/sources/manga_slayer_source.dart';

void main() {
  test('Manga Slayer handles internal and current source URLs', () {
    final source = MangaSlayerSource();
    expect(source.handles('mangaslayer://manga/10952'), isTrue);
    expect(source.handles('https://sparkmanga.net/manga/naruto/700/'), isTrue);
    expect(source.kind, 'manga');
  });
}
