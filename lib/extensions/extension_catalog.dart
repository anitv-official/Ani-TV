import 'extension_base.dart';
import 'providers/anime_witcher_extension.dart';
import 'providers/egydead_extension.dart';
import 'providers/youtube_extension.dart';

class ExtensionCatalog {
  static final List<AniExtension> all = <AniExtension>[
    AnimeWitcherExtension(),
    EgyDeadExtension(),
    YouTubeExtension(),
  ];
}
