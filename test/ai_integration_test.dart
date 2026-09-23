import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:anitv/ai/ai_context_manager.dart';
import 'package:anitv/ai/ai_models.dart';
import 'package:anitv/ai/ai_tool_registry.dart';
import 'package:anitv/ai/openrouter_service.dart';

void main() {
  test('OpenRouter parses assistant text and tool calls', () async {
    final client = MockClient((request) async {
      final payload = jsonDecode(request.body) as Map<String, dynamic>;
      expect(payload['model'], 'test-model');
      expect(payload['tools'], isNotEmpty);
      return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'content': '',
                  'tool_calls': [
                    {
                      'id': 'call-1',
                      'type': 'function',
                      'function': {
                        'name': 'search_content',
                        'arguments': '{"query":"Naruto"}'
                      },
                    }
                  ],
                }
              }
            ]
          }),
          200);
    });
    final service = OpenRouterService(
        config: const OpenRouterConfig(apiKey: 'test-key', model: 'test-model'),
        client: client);
    final message = await service.complete(
      messages: const [AiMessage(role: 'user', content: 'ابحث عن Naruto')],
      tools: const [
        {
          'type': 'function',
          'function': {'name': 'search_content'}
        }
      ],
    );
    expect(message.toolCalls.single.name, 'search_content');
    expect(message.toolCalls.single.arguments['query'], 'Naruto');
    service.dispose();
  });

  test('OpenRouter rejects malformed responses and non-success HTTP', () async {
    final malformed = OpenRouterService(
        config: const OpenRouterConfig(apiKey: 'test-key', model: 'test-model'),
        client: MockClient((_) async => http.Response('{}', 200)));
    expect(
        () => malformed.complete(
            messages: const [AiMessage(role: 'user', content: 'test')],
            tools: const []),
        throwsA(isA<AiServiceException>()));
    malformed.dispose();

    final rejected = OpenRouterService(
        config: const OpenRouterConfig(apiKey: 'test-key', model: 'test-model'),
        client: MockClient((_) async => http.Response('denied', 401)));
    expect(
        () => rejected.complete(
            messages: const [AiMessage(role: 'user', content: 'test')],
            tools: const []),
        throwsA(isA<AiServiceException>()));
    rejected.dispose();
  });

  test('tool registry exposes only approved real-data tools', () {
    final names = AiToolRegistry().tools.map((tool) => tool.name).toSet();
    expect(
        names,
        containsAll({
          'search_content',
          'search_anime',
          'search_manga',
          'search_movie',
          'search_series',
          'search_drama',
          'open_content',
          'get_content_details',
          'search_episodes',
          'get_episode',
          'search_chapters',
          'get_chapter',
          'get_continue_watching',
          'get_history',
          'play_content',
          'download_content',
          'download_episode',
          'download_chapter'
        }));
    expect(names, isNot(contains('execute_arbitrary_url')));
  });

  test('context manager keeps useful context and removes sensitive keys', () {
    final manager = AiContextManager();
    manager.update(
        screen: 'anime_details',
        content: {'id': 'real-id', 'title': 'Naruto', 'token': 'secret'});
    final json = manager.current.toJson();
    expect(json['screen'], 'anime_details');
    expect((json['content'] as Map).containsKey('id'), isTrue);
    expect((json['content'] as Map).containsKey('token'), isFalse);
  });

  test('tool call arguments tolerate malformed JSON safely', () {
    final call = AiToolCall.fromJson({
      'id': 'x',
      'function': {'name': 'search_content', 'arguments': '{bad'}
    });
    expect(call.name, 'search_content');
    expect(call.arguments, isEmpty);
  });
}
