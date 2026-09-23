import '../sources/source_base.dart';
import '../sources/source_presentation.dart';
import 'extension_base.dart';

class SourceExtensionAdapter extends AniExtension {
  final ContentSource delegate;
  SourceExtensionAdapter(this.delegate);

  @override String get id => delegate.id;
  @override String get name => delegate.name;
  @override String get kind => delegate.kind;
  @override List<String> get hosts => delegate.hosts;
  @override String get contentLabel => SourcePresentation.kindLabel(kind);
  @override String get iconUrl => SourcePresentation.iconFor(id, hosts);
  @override ExtensionStatus get status => switch (SourcePresentation.availability(id)) {
        SourceAvailability.available => ExtensionStatus.available,
        SourceAvailability.limited => ExtensionStatus.limited,
        SourceAvailability.unavailable => ExtensionStatus.unavailable,
      };
  @override String get statusMessage => SourcePresentation.statusMessage(id, kind);
  @override bool handles(String url) => delegate.handles(url);
  @override Future<List<Map<String, dynamic>>> search(String query) => delegate.search(query);
  @override Future<List<Map<String, dynamic>>> latest({int page = 1}) => delegate.latest(page: page);
  @override Future<List<Map<String, dynamic>>> nextPage({String query = '', int page = 2}) => delegate.nextPage(query: query, page: page);
  @override Future<Map<String, dynamic>> details(String url) => delegate.details(url);
  @override Future<Map<String, dynamic>?> streams(String url) => delegate.streams(url);
  @override Future<Map<String, dynamic>?> chapterImages(String url) => delegate.chapterImages(url);
}
