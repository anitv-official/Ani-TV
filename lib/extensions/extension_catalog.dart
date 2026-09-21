import 'extension_base.dart';
import 'providers/anime_witcher_extension.dart';
import 'providers/anime3rb_extension.dart';
import 'providers/arabic_html_extensions.dart';
import 'providers/egydead_extension.dart';
import 'providers/youtube_extension.dart';

class ExtensionCatalog {
  static final List<AniExtension> all = <AniExtension>[
    AnimeWitcherExtension(),
    Anime3rbExtension(),
    EgyDeadExtension(),
    KrmzyExtension(),
    AflaamExtension(),
    AkwamExtension(),
    FaselhdExtension(),
    YouTubeExtension(),
  ];
}
