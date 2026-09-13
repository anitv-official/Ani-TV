import 'package:flutter_test/flutter_test.dart';
import 'package:anitv/sources/drama_source.dart';
import 'package:anitv/sources/source_registry.dart';

void main() {
  test('Drama source is isolated and registered', () {
    final source = SourceRegistry.all.whereType<DramaSource>().single;
    expect(source.id, 'drama_slayer');
    expect(source.kind, 'drama');
    expect(source.handles('https://drslayer.com/drama/public/drama-details?drama_id=7'), isTrue);
  });

  test('quality type 995 follows the APK URL mapping', () {
    final qualities = dramaQualities995([
      'https://cdn.test/360/file.m3u8',
      'https://cdn.test/1080/file.m3u8',
      'https://cdn.test/720/file.m3u8',
      'https://cdn.test/480/file.m3u8',
      'https://cdn.test/unknown/file.m3u8',
    ]);
    expect(qualities.map((quality) => quality.label), ['منخفضة', 'عالية جدا', 'عالية', 'متوسطة']);
    expect(qualities.map((quality) => quality.url), contains('https://cdn.test/1080/file.m3u8'));
  });
}
