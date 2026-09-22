import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/appwrite_service.dart';
import '../models/community_models.dart';
import 'appwrite_community_identity.dart';
import 'community_backend_config.dart';

class MediaUploadTicket {
  final String mediaId;
  final String storageKey;
  final Uri uploadUrl;
  final String contentType;
  final int fileSize;
  const MediaUploadTicket(
      {required this.mediaId,
      required this.storageKey,
      required this.uploadUrl,
      required this.contentType,
      required this.fileSize});
}

class CommunityMediaApi {
  CommunityMediaApi(
      {AppwriteCommunityIdentity? identity, http.Client? httpClient})
      : identity = identity ?? const AppwriteCommunityIdentity(),
        httpClient = httpClient ?? http.Client();
  final AppwriteCommunityIdentity identity;
  final http.Client httpClient;

  Future<Map<String, dynamic>> _invoke(
      String function, Map<String, dynamic> body) async {
    try {
      final jwt = await identity.createJwt();
      final response = await Supabase.instance.client.functions
          .invoke(function, body: body, headers: {'x-appwrite-jwt': jwt});
      if (response.status < 200 || response.status >= 300)
        throw _error(response.data);
      final data = response.data;
      if (data is! Map)
        throw const NetworkError(
            'The media service returned an invalid response.');
      return Map<String, dynamic>.from(data);
    } on CommunityBackendError {
      rethrow;
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<MediaUploadTicket> requestUpload(
      {required String postId,
      required MediaType mediaType,
      required String mimeType,
      required int fileSize,
      String? fileName,
      Duration duration = Duration.zero}) async {
    final data = await _invoke('community-media-upload', {
      'post_id': postId,
      'media_type': mediaType == MediaType.image ? 'image' : 'audio',
      'mime_type': mimeType,
      'file_size': fileSize,
      if (fileName != null) 'file_name': fileName,
      if (mediaType == MediaType.audio) 'duration_ms': duration.inMilliseconds
    });
    final url = Uri.tryParse(data['upload_url']?.toString() ?? '');
    if (url == null || !url.hasScheme)
      throw const NetworkError('The media upload URL is invalid.');
    return MediaUploadTicket(
        mediaId: data['media_id'].toString(),
        storageKey: data['storage_key'].toString(),
        uploadUrl: url,
        contentType: data['content_type'].toString(),
        fileSize: (data['file_size'] as num).toInt());
  }

  Future<PostMedia> uploadFile(
      {required String postId,
      required String path,
      required MediaType mediaType,
      required String mimeType,
      Duration duration = Duration.zero}) async {
    final file = File(path);
    if (!await file.exists())
      throw const ValidationError('The selected media file no longer exists.');
    final bytes = await file.readAsBytes();
    final ticket = await requestUpload(
        postId: postId,
        mediaType: mediaType,
        mimeType: mimeType,
        fileSize: bytes.length,
        fileName:
            file.uri.pathSegments.isEmpty ? null : file.uri.pathSegments.last,
        duration: duration);
    final upload = await httpClient.put(ticket.uploadUrl,
        headers: {
          'Content-Type': ticket.contentType,
          'Content-Length': '${bytes.length}'
        },
        body: bytes);
    if (upload.statusCode < 200 || upload.statusCode >= 300)
      throw const StorageError('The media could not be uploaded.');
    final completed =
        await _invoke('community-media-complete', {'media_id': ticket.mediaId});
    if (completed['status'] != 'ready')
      throw const StorageError('The media upload could not be confirmed.');
    return PostMedia(
        id: ticket.mediaId,
        type: mediaType,
        path: ticket.storageKey,
        duration: duration);
  }

  Future<String> secureUrl(PostMedia media) async {
    final data = await _invoke('community-media-url', {'media_id': media.id});
    final url = data['url']?.toString() ?? '';
    if (url.isEmpty)
      throw const StorageError('The media access URL is unavailable.');
    return url;
  }

  Future<void> delete(PostMedia media) =>
      _invoke('community-media-delete', {'media_id': media.id}).then((_) {});

  CommunityBackendError _error(dynamic data) {
    final code = data is Map ? data['error']?.toString() : null;
    return switch (code) {
      'authentication_required' =>
        const AuthenticationError('Sign in to use Community media.'),
      'forbidden' =>
        const PermissionError('You do not have permission for this media.'),
      'invalid_mime' ||
      'invalid_file_size' ||
      'invalid_media_type' ||
      'invalid_input' =>
        const ValidationError('The selected media is not valid.'),
      'storage_error' ||
      'upload_missing' ||
      'upload_size_mismatch' =>
        const StorageError('The media storage operation failed.'),
      'database_error' =>
        const DatabaseError('The media metadata service is unavailable.'),
      _ => const NetworkError('The media service is temporarily unavailable.'),
    };
  }
}

class StorageError extends CommunityBackendError {
  const StorageError(super.message);
}
