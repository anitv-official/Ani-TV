import 'package:flutter_test/flutter_test.dart';
import 'package:anitv/sources/anime3rb_source.dart';

void main() {
  test('Anime3rb extracts native MP4 and M3U8 URLs from player HTML', () {
    const html = r'''
      <video src="https://cdn.example.com/episode.mp4?token=abc"></video>
      <script>const source = {file: "https://cdn.example.com/episode.m3u8?sig=xyz"};</script>
      <iframe src="https://anime3rb.com/embed/not-a-native-stream"></iframe>
    ''';

    final urls = Anime3rbSource.extractDirectMediaUrls(
      html,
      'https://anime3rb.com/episode/demo/1',
    );

    expect(urls, contains('https://cdn.example.com/episode.mp4?token=abc'));
    expect(urls, contains('https://cdn.example.com/episode.m3u8?sig=xyz'));
    expect(urls.any((url) => url.contains('/embed/')), isFalse);
  });

  test('Anime3rb ignores embed pages when no native media URL exists', () {
    const html = '<iframe src="https://vid3rb.com/embed/abc"></iframe>';
    final urls = Anime3rbSource.extractDirectMediaUrls(
      html,
      'https://anime3rb.com/episode/demo/1',
    );
    expect(urls, isEmpty);
  });
}
