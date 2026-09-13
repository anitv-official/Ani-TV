import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anitv/services/local_cache_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('profile and favorites are isolated by user id', () async {
    final cache = LocalCacheService.instance;
    await cache.writeProfile('user-a', {'username': 'alpha', 'displayName': 'Alpha'});
    await cache.writeFavorites('user-a', 'anime', [{'id': 'a1', 'title': 'A'}]);
    expect((await cache.readProfile('user-a'))!['username'], 'alpha');
    expect(await cache.readProfile('user-b'), isNull);
    expect(await cache.readFavorites('user-b', 'anime'), isEmpty);
  });

  test('failed sync operations remain queued', () async {
    final cache = LocalCacheService.instance;
    await cache.enqueueFavorite('user-a', {'op': 'create', 'data': {'itemId': 'x'}});
    final pending = await cache.pendingFavorites('user-a');
    expect(pending, hasLength(1));
    expect(pending.single['op'], 'create');
  });

  test('cache does not store credentials', () async {
    final cache = LocalCacheService.instance;
    await cache.writeProfile('user-a', {'username': 'alpha'});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().any((key) => key.contains('password') || key.contains('secret') || key.contains('api_key')), isFalse);
  });
}
