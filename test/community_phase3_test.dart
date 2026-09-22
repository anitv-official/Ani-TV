import 'package:flutter_test/flutter_test.dart';
import 'package:anitv/community/mock/mock_community_repository.dart';
import 'package:anitv/community/models/community_models.dart';

void main() {
  test('verification is controlled by the repository and not the username',
      () async {
    final repository = MockVerificationRepository();
    expect((await repository.statusFor('anitv')).verified, isTrue);
    expect((await repository.statusFor('sora')).verified, isFalse);
  });

  test('share repository exposes external and in-app share contracts',
      () async {
    final source = MockCommunityRepository();
    final post = (await source.fetchPosts(limit: 1)).single;
    final repository = MockShareRepository();
    final external = await repository.shareExternally(post);
    final internal = await repository.shareToUser(post, 'sora');
    expect(external, const TypeMatcher<ShareReceipt>());
    expect(external.external, isTrue);
    expect(internal.external, isFalse);
    expect(internal.recipientId, 'sora');
  });

  test('notification mock includes unread and read states', () async {
    final repository = MockNotificationRepository();
    final items = await repository.fetchNotifications();
    expect(items, isNotEmpty);
    expect(items.any((item) => !item.isRead), isTrue);
    expect(await repository.unreadCount(), greaterThan(0));
  });
}
