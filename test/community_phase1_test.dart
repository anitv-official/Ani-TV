import 'package:flutter_test/flutter_test.dart';
import 'package:anitv/community/mock/mock_community_repository.dart';
import 'package:anitv/community/models/community_models.dart';

void main() {
  late MockCommunityRepository repository;

  setUp(() => repository = MockCommunityRepository());

  test('mock feed supports pagination and search', () async {
    final first = await repository.fetchPosts(limit: 3);
    expect(first, hasLength(3));
    final search = await repository.fetchPosts(query: 'AniTV');
    expect(search, isNotEmpty);
    expect(
        search.every((post) => '${post.text} ${post.author.username}'
            .toLowerCase()
            .contains('anitv')),
        isTrue);
  });

  test('mock publishing rejects no media assumptions and creates typed post',
      () async {
    final post = await repository.publishPost(
        text: 'اختبار', link: 'https://example.com');
    expect(post.type, PostType.link);
    expect(post.link, 'https://example.com');
  });

  test('mock like and comment state changes are observable', () async {
    final post = (await repository.fetchPosts(limit: 1)).single;
    final liked = await repository.toggleLike(post);
    expect(liked.likedByMe, isTrue);
    final comment = await repository.addComment(post.id, 'تعليق تجريبي');
    expect(comment.text, 'تعليق تجريبي');
    expect(await repository.fetchComments(post.id), isNotEmpty);
  });
}
