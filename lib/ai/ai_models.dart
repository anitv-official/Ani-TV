import 'dart:convert';

class AiMessage {
  final String role;
  final String content;
  final List<AiToolCall> toolCalls;
  final String? toolCallId;
  final String? name;

  const AiMessage({
    required this.role,
    this.content = '',
    this.toolCalls = const [],
    this.toolCallId,
    this.name,
  });

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{'role': role, 'content': content};
    if (toolCalls.isNotEmpty) {
      result['tool_calls'] = toolCalls.map((call) => call.toJson()).toList();
    }
    if (toolCallId != null) result['tool_call_id'] = toolCallId;
    if (name != null) result['name'] = name;
    return result;
  }
}

class AiToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  const AiToolCall(
      {required this.id, required this.name, required this.arguments});

  factory AiToolCall.fromJson(Map<String, dynamic> json) {
    final function =
        Map<String, dynamic>.from((json['function'] as Map?) ?? const {});
    final rawArguments = function['arguments'];
    Map<String, dynamic> arguments = {};
    if (rawArguments is Map) {
      arguments = Map<String, dynamic>.from(rawArguments);
    } else if (rawArguments is String && rawArguments.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawArguments);
        if (decoded is Map) arguments = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return AiToolCall(
      id: json['id']?.toString() ?? '',
      name: function['name']?.toString() ?? '',
      arguments: arguments,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': 'function',
        'function': {'name': name, 'arguments': jsonEncode(arguments)},
      };
}

class AiAction {
  final String type;
  final Map<String, dynamic> payload;

  const AiAction({required this.type, this.payload = const {}});

  Map<String, dynamic> toJson() => {'type': type, 'payload': payload};
}

class AiToolResult {
  final bool success;
  final String message;
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic>? data;
  final AiAction? action;

  const AiToolResult({
    required this.success,
    required this.message,
    this.items = const [],
    this.data,
    this.action,
  });

  Map<String, dynamic> toJson() => {
        'success': success,
        'message': message,
        if (items.isNotEmpty) 'items': items,
        if (data != null) 'data': data,
        if (action != null) 'action': action!.toJson(),
      };
}

class AiReply {
  final String text;
  final List<Map<String, dynamic>> items;
  final AiAction? action;
  final bool isError;

  const AiReply(
      {required this.text,
      this.items = const [],
      this.action,
      this.isError = false});
}

class OpenRouterConfig {
  final String apiKey;
  final String model;
  final String baseUrl;
  final Duration timeout;

  const OpenRouterConfig({
    required this.apiKey,
    required this.model,
    this.baseUrl = 'https://openrouter.ai/api/v1',
    this.timeout = const Duration(seconds: 45),
  });

  factory OpenRouterConfig.fromEnvironment() => const OpenRouterConfig(
        apiKey: String.fromEnvironment('OPENROUTER_API_KEY'),
        model: String.fromEnvironment('OPENROUTER_MODEL',
            defaultValue: 'openrouter/free'),
        baseUrl: String.fromEnvironment('OPENROUTER_BASE_URL',
            defaultValue: 'https://openrouter.ai/api/v1'),
      );

  bool get isConfigured => apiKey.trim().isNotEmpty;
}

class AiServiceException implements Exception {
  final String message;
  final int? statusCode;
  const AiServiceException(this.message, {this.statusCode});
  @override
  String toString() => message;
}
