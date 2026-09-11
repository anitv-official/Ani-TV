import 'package:share_plus/share_plus.dart';

/// Builds stable AniTV web links while preserving the source URL needed to
/// resolve the content when the app is opened from a shared link.
class ContentLinkService {
  static const String websiteBase = 'https://anitv-manga-lord.vercel.app';

  static Uri forContent({required String type, required String sourceUrl}) =>
      Uri.parse('$websiteBase/$type').replace(queryParameters: {'url': sourceUrl});

  static Future<void> share({
    required String type,
    required String title,
    required String sourceUrl,
  }) async {
    final link = forContent(type: type, sourceUrl: sourceUrl);
    await Share.share('$title\n$link', subject: title);
  }
}
