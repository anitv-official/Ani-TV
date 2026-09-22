import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:anitv/community/services/community_backend_config.dart';
import 'package:anitv/community/services/community_media_storage.dart';

void main() {
  test('default build remains in Mock mode without Supabase dart-defines', () {
    expect(CommunityBackend.dataSource, CommunityDataSource.mock);
    expect(CommunityBackend.supabaseUrl, isEmpty);
    expect(CommunityBackend.supabasePublishableKey, isEmpty);
  });

  test('backend errors expose safe user-facing categories', () {
    expect(mapSupabaseError(const PermissionError('permission')),
        isA<PermissionError>());
    expect(
        mapSupabaseError(const NotFoundError('missing')), isA<NotFoundError>());
    expect(mapSupabaseError(StateError('network')), isA<NetworkError>());
  });

  test('B2 placeholder never performs a client-side upload', () async {
    const repository = BackblazeMediaRepository();
    expect(repository.config.secureServerUploadRequired, isTrue);
    await expectLater(repository.uploadImage('/tmp/fictional.png'),
        throwsA(isA<StorageNotConfiguredError>()));
  });

  test(
      'migration contains no credential material and preserves notification tables',
      () {
    final migration =
        File('supabase/migrations/20260922112000_create_community_backend.sql')
            .readAsStringSync();
    expect(migration, contains('community_notifications'));
    expect(migration, contains('community_current_user_id'));
    expect(migration, contains('appwrite_user_id'));
    expect(migration, isNot(contains('service_role')));
    expect(migration, isNot(contains('application key')));
    expect(migration, isNot(contains('secret_key')));
  });
}
