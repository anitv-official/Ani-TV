import 'dart:convert';

import '../providers/app_state_provider.dart';
import 'ai_context_manager.dart';
import 'ai_models.dart';
import 'ai_tool_registry.dart';
import 'openrouter_service.dart';

class AiController {
  final OpenRouterService service;
  final AiToolRegistry registry;
  final AiContextManager contextManager;
  final AppStateProvider appState;
  final List<AiMessage> _history = [];

  AiController(
      {required this.service,
      required this.registry,
      required this.contextManager,
      required this.appState});

  List<AiMessage> get history => List.unmodifiable(_history);

  Future<AiReply> ask(String userText) async {
    final query = userText.trim();
    if (query.isEmpty) return const AiReply(text: 'اكتب طلبًا لأساعدك.');
    _history.add(AiMessage(role: 'user', content: query));
    final messages = <AiMessage>[
      const AiMessage(
          role: 'system',
          content:
              'أنت مساعد AniTV العربي. استخدم الأدوات للبحث في البيانات الحقيقية فقط. لا تخترع معرفات أو روابط أو نتائج. إذا ظهرت عدة نتائج، اعرضها ولا تخمن. لا تنفذ التشغيل أو التنزيل دون نتيجة أداة حقيقية. أجب بإيجاز وبالعربية.'),
      AiMessage(
          role: 'system',
          content: 'السياق الحالي: ${contextManager.current.toJson()}'),
      ..._history,
    ];
    try {
      var assistant = await service.complete(
          messages: messages, tools: registry.definitions);
      for (var round = 0;
          round < 3 && assistant.toolCalls.isNotEmpty;
          round++) {
        _history.add(assistant);
        AiAction? action;
        final collectedItems = <Map<String, dynamic>>[];
        for (final call in assistant.toolCalls) {
          final result = await registry.execute(
              call.name,
              call.arguments,
              AiToolContext(
                  appState: appState, context: contextManager.current));
          collectedItems.addAll(result.items);
          action ??= result.action;
          _history.add(AiMessage(
              role: 'tool',
              name: call.name,
              toolCallId: call.id,
              content: _encode(result)));
          if (!result.success && result.message.isNotEmpty)
            collectedItems.add({'_ai_message': result.message});
        }
        assistant = await service.complete(messages: [
          ...messages,
          ..._history.skip(1),
        ], tools: registry.definitions);
        if (assistant.toolCalls.isEmpty) {
          final reply = AiReply(
              text: assistant.content.trim().isEmpty
                  ? 'تم تنفيذ الطلب.'
                  : assistant.content.trim(),
              items: collectedItems,
              action: action);
          _history.add(assistant);
          return reply;
        }
      }
      final text = assistant.content.trim();
      _history.add(assistant);
      return AiReply(text: text.isEmpty ? 'لم أستطع إكمال الطلب.' : text);
    } catch (error) {
      return AiReply(text: error.toString(), isError: true);
    }
  }

  String _encode(AiToolResult result) => jsonEncode(result.toJson());

  void clear() => _history.clear();

  void dispose() => service.dispose();
}
