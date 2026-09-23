import 'html_client.dart';

enum SourceAvailability { available, limited, unavailable }

extension SourceAvailabilityLabel on SourceAvailability {
  String get label => switch (this) {
        SourceAvailability.available => 'متاح',
        SourceAvailability.limited => 'متاح جزئياً',
        SourceAvailability.unavailable => 'معطل',
      };

  bool get isEnabled => this != SourceAvailability.unavailable;
}

class SourcePresentation {
  const SourcePresentation._();

  static const _icons = <String, String>{
    'anime_slayer': 'https://anslayer.com/favicon.ico',
    'animefy': 'https://animeify.net/favicon.ico',
    'drama_slayer': 'https://drslayer.com/favicon.ico',
    'swat': 'https://appswat.com/favicon.ico',
    'mangatime': 'https://mangatime.org/favicon.ico',
    'manga_mello': 'https://mangamello.com/favicon.ico',
    'anime_witcher': 'https://www.animewitcher.com/favicon.ico',
    'anime3rb': 'https://anime3rb.com/favicon.ico',
    'egydead': 'https://tv10.egydead.live/favicon.ico',
    'krmzy': 'https://www.qrmzi.tv/favicon.ico',
    'aflaam': 'https://aflaam.com/favicon.ico',
    'akwam': 'https://akwam.ss/favicon.ico',
    'faselhd': 'https://www.fasel-hd.co/favicon.ico',
    'youtube': 'https://www.youtube.com/s/desktop/28b1f4a1/img/favicon_32x32.png',
    'wecima': 'https://wecima.show/favicon.ico',
    'kormoz': 'https://www.qrmzi.tv/favicon.ico',
  };

  static const _limited = <String>{
    'anime3rb', 'egydead', 'krmzy', 'aflaam', 'akwam', 'faselhd', 'youtube', 'wecima', 'kormoz',
  };

  static String iconFor(String id, List<String> hosts) {
    final icon = _icons[id];
    if (icon != null) return icon;
    return hosts.isEmpty ? '' : 'https://${hosts.first.replaceFirst('www.', '')}/favicon.ico';
  }

  static String kindLabel(String kind) => switch (kind) {
        'anime' => 'أنمي',
        'manga' => 'مانجا',
        'drama' || 'movie' => 'أفلام ومسلسلات',
        'video' => 'فيديو',
        _ => 'محتوى',
      };

  static SourceAvailability availability(String id) =>
      _limited.contains(id) ? SourceAvailability.limited : SourceAvailability.available;

  static String statusMessage(String id, String kind) => _limited.contains(id)
      ? 'قد يتأثر بتغيّر الموقع أو الحماية.'
      : 'مصدر ${kindLabel(kind)} مباشر.';

  static String hostOf(String url) => HtmlParse.hostOf(url);
}
