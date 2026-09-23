import 'dart:convert';

import 'package:http/http.dart' as http;

import 'graph_generation_client.dart';
import 'tool_schema.dart';

class GeminiClient implements GraphGenerationClient {
  GeminiClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const _model = 'gemini-3.6-flash';
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';
  static const _functionName = 'emit_creative_graph';

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
        'x-goog-api-key': apiKey,
      },
      body: jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': userInput},
            ],
          },
        ],
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt},
          ],
        },
        'tools': [
          {
            'functionDeclarations': [
              {
                'name': emitCreativeGraphToolSchema['name'],
                'description': emitCreativeGraphToolSchema['description'],
                'parameters': emitCreativeGraphToolSchema['input_schema'],
              },
            ],
          },
        ],
        'toolConfig': {
          'functionCallingConfig': {
            'mode': 'ANY',
            'allowedFunctionNames': [_functionName],
          },
        },
      }),
    );

    if (response.statusCode != 200) {
      throw GeminiApiException(
          'Gemini API devolvió ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw const GeminiApiException('respuesta sin candidatos');
    }

    final firstCandidate = candidates.first as Map<String, dynamic>;
    final content = firstCandidate['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null) {
      throw const GeminiApiException('respuesta sin contenido');
    }

    final functionCallPart = parts
        .map((part) => part as Map<String, dynamic>)
        .where((part) => part.containsKey('functionCall'))
        .cast<Map<String, dynamic>?>()
        .firstWhere((_) => true, orElse: () => null);

    if (functionCallPart == null) {
      throw const GeminiApiException(
          'el modelo no llamó a emit_creative_graph');
    }

    final functionCall =
        functionCallPart['functionCall'] as Map<String, dynamic>;
    return functionCall['args'] as Map<String, dynamic>;
  }
}
