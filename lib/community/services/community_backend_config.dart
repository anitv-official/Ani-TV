import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Community identity is Appwrite-backed; Supabase Auth is intentionally not used.
abstract class CommunityIdentityProvider {
  Future<String?> currentUserId();
}

abstract class CommunityBackend {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL',
      defaultValue: 'https://wmzeydetzfndkpgqwfjd.supabase.co');
  static const supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY',
          defaultValue: 'sb_publishable_qu45fDy7kiXAW-n_Ox1mjA_BfMHZN5K');
  static const modeName =
      String.fromEnvironment('COMMUNITY_DATA_SOURCE', defaultValue: 'supabase');

  static CommunityDataSource get dataSource =>
      modeName.toLowerCase() == 'supabase'
          ? CommunityDataSource.supabase
          : CommunityDataSource.mock;
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty &&
      supabasePublishableKey.isNotEmpty &&
      Supabase.instance.isInitialized;
  static SupabaseClient get client {
    if (!isSupabaseConfigured)
      throw const StorageNotConfiguredError(
          'Supabase is not configured for this build.');
    return Supabase.instance.client;
  }
}

enum CommunityDataSource { mock, supabase }

class CommunityBackendError implements Exception {
  final String message;
  const CommunityBackendError(this.message);
  @override
  String toString() => message;
}

class NetworkError extends CommunityBackendError {
  const NetworkError(super.message);
}

class AuthenticationError extends CommunityBackendError {
  const AuthenticationError(super.message);
}

class PermissionError extends CommunityBackendError {
  const PermissionError(super.message);
}

class NotFoundError extends CommunityBackendError {
  const NotFoundError(super.message);
}

class ValidationError extends CommunityBackendError {
  const ValidationError(super.message);
}

class DatabaseError extends CommunityBackendError {
  const DatabaseError(super.message);
}

class StorageNotConfiguredError extends CommunityBackendError {
  const StorageNotConfiguredError(super.message);
}

CommunityBackendError mapSupabaseError(Object error) {
  if (error is CommunityBackendError) return error;
  if (error is AuthException)
    return AuthenticationError('Authentication is required.');
  if (error is PostgrestException) {
    if (error.code == '42501')
      return PermissionError('You do not have permission for this action.');
    if (error.code == 'PGRST116')
      return NotFoundError('The requested item was not found.');
    return DatabaseError(
        'The community service could not complete the request.');
  }
  if (error is StorageException)
    return StorageNotConfiguredError(
        'Community media storage is not configured yet.');
  debugPrint('Community backend error: ${error.runtimeType}');
  return NetworkError('The community service is temporarily unavailable.');
}
