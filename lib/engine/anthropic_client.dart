import 'dart:convert';

import 'package:http/http.dart' as http;

import 'graph_generation_client.dart';
import 'tool_schema.dart';

class AnthropicClient implements GraphGenerationClient {
  AnthropicClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-sonnet-5';
  static const _anthropicVersion = '2023-06-01';
  static const _maxTokens = 8192;

  @override
  Future<Map<String, dynamic>> requestToolCall({
    required String apiKey,
    required String systemPrompt,
    required String userInput,
  }) async {
    final response = await _httpClient.post(
      Uri.parse(_endpoint),
      headers: {
        'content-type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': _anthropicVersion,
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': _maxTokens,
        'system': systemPrompt,
        'messages': [
          {'role': 'user', 'content': userInput},
        ],
        'tools': [emitCreativeGraphToolSchema],
        'tool_choice': {'type': 'tool', 'name': 'emit_creative_graph'},
      }),
    );

    if (response.statusCode != 200) {
      throw AnthropicApiException(
          'Anthropic API devolvió ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final content = decoded['content'] as List<dynamic>?;
    if (content == null) {
      throw const AnthropicApiException('respuesta sin contenido');
    }

    final toolUse = content
        .map((block) => block as Map<String, dynamic>)
        .where((block) => block['type'] == 'tool_use')
        .cast<Map<String, dynamic>?>()
        .firstWhere((_) => true, orElse: () => null);

    if (toolUse == null) {
      throw const AnthropicApiException(
          'el modelo no llamó a emit_creative_graph');
    }

    return toolUse['input'] as Map<String, dynamic>;
  }
}
