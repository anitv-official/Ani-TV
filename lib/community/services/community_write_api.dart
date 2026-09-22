import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/community_models.dart';
import 'appwrite_community_identity.dart';
import 'community_backend_config.dart';

class CommunityWriteApi {
  CommunityWriteApi({AppwriteCommunityIdentity? identity})
      : identity = identity ?? const AppwriteCommunityIdentity();
  final AppwriteCommunityIdentity identity;

  Future<Map<String, dynamic>> invoke(String action,
      [Map<String, dynamic> body = const {}]) async {
    try {
      final jwt = await identity.createJwt();
      final response = await Supabase.instance.client.functions.invoke(
        'community-write',
        body: {'action': action, ...body},
        headers: {'x-appwrite-jwt': jwt},
      );
      final value = response.data;
      if (response.status < 200 || response.status >= 300) {
        throw _mapError(value);
      }
      if (value is! Map) {
        throw const NetworkError('The community service returned an invalid response.');
      }
      return Map<String, dynamic>.from(value);
    } on CommunityBackendError {
      rethrow;
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  CommunityBackendError _mapError(dynamic value) {
    final code = value is Map ? value['error']?.toString() : null;
    return switch (code) {
      'authentication_required' =>
        const AuthenticationError('Sign in to use Community.'),
      'forbidden' => const PermissionError('You do not have permission for this action.'),
      'not_found' => const NotFoundError('The requested Community item was not found.'),
      'invalid_input' => const ValidationError('Please check the entered content.'),
      'storage_cleanup_required' =>
        const CommunityWriteError('Media cleanup must finish before deleting the post.'),
      'database_error' => const DatabaseError('The Community database is unavailable.'),
      _ => const NetworkError('The Community service is temporarily unavailable.'),
    };
  }
}

class CommunityWriteError extends CommunityBackendError {
  const CommunityWriteError(super.message);
}
