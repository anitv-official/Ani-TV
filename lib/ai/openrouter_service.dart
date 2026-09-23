import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_models.dart';

class OpenRouterService {
  final OpenRouterConfig config;
  final http.Client client;

  OpenRouterService({OpenRouterConfig? config, http.Client? client})
      : config = config ?? OpenRouterConfig.fromEnvironment(),
        client = client ?? http.Client();

  Future<AiMessage> complete({
    required List<AiMessage> messages,
    required List<Map<String, dynamic>> tools,
    int maxAttempts = 2,
  }) async {
    if (!config.isConfigured) {
      throw const AiServiceException(
          'لم يتم إعداد مفتاح OpenRouter. أضفه عبر --dart-define=OPENROUTER_API_KEY=...');
    }
    final uri = Uri.parse(
        '${config.baseUrl.replaceFirst(RegExp(r'/$'), '')}/chat/completions');
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await client
            .post(
              uri,
              headers: {
                'Authorization': 'Bearer ${config.apiKey}',
                'Content-Type': 'application/json',
                'HTTP-Referer': 'https://anitv-tau.vercel.app',
                'X-Title': 'AniTV',
              },
              body: jsonEncode({
                'model': config.model,
                'messages':
                    messages.map((message) => message.toJson()).toList(),
                if (tools.isNotEmpty) 'tools': tools,
                'tool_choice': 'auto',
                'temperature': 0.2,
              }),
            )
            .timeout(config.timeout);
        if (response.statusCode == 429 || response.statusCode >= 500) {
          throw AiServiceException('خدمة AI مشغولة حاليًا. حاول مرة أخرى.',
              statusCode: response.statusCode);
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw AiServiceException(
              'تعذر الاتصال بخدمة AI (${response.statusCode}).',
              statusCode: response.statusCode);
        }
        final decoded = jsonDecode(response.body);
        if (decoded is! Map)
          throw const AiServiceException('استجابة AI غير صالحة.');
        final choices = decoded['choices'];
        if (choices is! List || choices.isEmpty || choices.first is! Map) {
          throw const AiServiceException('لم تُرجع خدمة AI رسالة.');
        }
        final message = (choices.first as Map)['message'];
        if (message is! Map)
          throw const AiServiceException('تنسيق رسالة AI غير صالح.');
        final rawCalls = message['tool_calls'];
        final calls = rawCalls is List
            ? rawCalls
                .whereType<Map>()
                .map((call) =>
                    AiToolCall.fromJson(Map<String, dynamic>.from(call)))
                .toList()
            : <AiToolCall>[];
        return AiMessage(
            role: 'assistant',
            content: message['content']?.toString() ?? '',
            toolCalls: calls);
      } catch (error) {
        lastError = error;
        final retryable = error is TimeoutException ||
            error is http.ClientException ||
            (error is AiServiceException &&
                (error.statusCode == 429 || (error.statusCode ?? 0) >= 500));
        if (!retryable || attempt == maxAttempts) break;
        await Future<void>.delayed(Duration(milliseconds: 350 * attempt));
      }
    }
    if (lastError is AiServiceException) throw lastError;
    throw AiServiceException('تعذر إكمال طلب AI: $lastError');
  }

  void dispose() => client.close();
}
