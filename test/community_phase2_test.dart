import 'package:flutter_test/flutter_test.dart';
import 'package:anitv/community/mock/mock_community_repository.dart';
import 'package:anitv/community/models/community_models.dart';

void main() {
  test('mock profiles expose bio, favorites, and posts', () async {
    final source = MockCommunityRepository();
    final profiles = MockProfileRepository(source);
    final profile = await profiles.getProfile('sora');
    final posts = await profiles.postsByUser('sora');
    expect(profile.bio, isNotEmpty);
    expect(profile.favoriteTitles, isNotEmpty);
    expect(posts, isNotEmpty);
  });

  test('friend requests use explicit status values', () async {
    final friends = MockFriendRepository();
    expect(await friends.statusFor('sora'), FriendStatus.none);
    expect(await friends.sendRequest('sora'), FriendStatus.pending);
  });

  test('mock chat loads conversations and appends sent messages', () async {
    final chat = MockChatRepository();
    final conversations = await chat.conversations();
    expect(conversations, isNotEmpty);
    final before = await chat.messages(conversations.first.id);
    final sent = await chat.sendMessage(conversations.first.id, 'رسالة اختبار');
    final after = await chat.messages(conversations.first.id);
    expect(sent.status, MessageStatus.sent);
    expect(after.length, before.length + 1);
    expect(after.last.text, 'رسالة اختبار');
  });
}
