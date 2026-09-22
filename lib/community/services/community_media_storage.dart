import '../models/community_models.dart';
import '../repositories/community_repositories.dart';
import 'community_backend_config.dart';

enum StorageProvider { backblazeB2, pending }

class StorageConfig {
  final StorageProvider provider;
  final bool secureServerUploadRequired;
  const StorageConfig(
      {this.provider = StorageProvider.backblazeB2,
      this.secureServerUploadRequired = true});
}

class MediaUploadRequest {
  final String path;
  final MediaType type;
  final String? mimeType;
  final int? fileSize;
  final Duration duration;
  const MediaUploadRequest(
      {required this.path,
      required this.type,
      this.mimeType,
      this.fileSize,
      this.duration = Duration.zero});
}

class MediaUploadResult {
  final String storageKey;
  final StorageProvider provider;
  final String? secureUrl;
  const MediaUploadResult(
      {required this.storageKey, required this.provider, this.secureUrl});
}

class MediaDeleteRequest {
  final String storageKey;
  final StorageProvider provider;
  const MediaDeleteRequest({required this.storageKey, required this.provider});
}

/// Placeholder until a trusted Supabase Edge Function/server signs B2 uploads.
class BackblazeMediaRepository implements MediaRepository {
  const BackblazeMediaRepository({this.config = const StorageConfig()});
  final StorageConfig config;
  CommunityBackendError get _notConfigured => const StorageNotConfiguredError(
      'Backblaze B2 is not connected. Use a secure server-side upload flow.');
  @override
  Future<PostMedia> uploadImage(String path) => Future.error(_notConfigured);
  @override
  Future<PostMedia> uploadAudio(String path,
          {Duration duration = Duration.zero}) =>
      Future.error(_notConfigured);
  @override
  Future<void> deleteMedia(String mediaId) => Future.error(_notConfigured);
  @override
  Future<String> getMediaUrl(PostMedia media) => Future.error(_notConfigured);
}
