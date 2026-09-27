import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import 'graph_generation_client.dart';
import 'tool_schema.dart';

class GeminiClient implements GraphGenerationClient {
  GeminiClient({
    http.Client? httpClient,
    this.maxRetries = 3,
    this.baseRetryDelay = const Duration(seconds: 1),
  }) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// How many times to retry a transient failure (503 the model being
  /// overloaded, 429 rate limited) before giving up — Gemini's free tier
  /// hits these often enough that a single failed attempt shouldn't send
  /// the user straight to an error screen.
  final int maxRetries;

  /// Delay before the first retry; doubles each attempt after (1s, 2s, 4s
  /// with the default maxRetries of 3). Tests pass Duration.zero so the
  /// retry path doesn't actually slow the suite down.
  final Duration baseRetryDelay;

  static const _model = 'gemini-3.6-flash';
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';
  static const _functionName = 'emit_creative_graph';
  static const _retryableStatusCodes = {503, 429};

  @override
  Future<Map<String, dynamic>> requestToolCall({
    required String apiKey,
    required String systemPrompt,
    required String userInput,
  }) async {
    final body = jsonEncode({
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
    });

    var attempt = 0;
    late http.Response response;
    while (true) {
      response = await _httpClient.post(
        Uri.parse(_endpoint),
        headers: {
          'content-type': 'application/json',
          'x-goog-api-key': apiKey,
        },
        body: body,
      );

      if (!_retryableStatusCodes.contains(response.statusCode) ||
          attempt >= maxRetries) {
        break;
      }
      final delay = baseRetryDelay * math.pow(2, attempt).toInt();
      await Future.delayed(delay);
      attempt++;
    }

    if (response.statusCode != 200) {
      if (_retryableStatusCodes.contains(response.statusCode)) {
        throw GeminiApiException(
            'Gemini está sobrecargado (${response.statusCode}) tras '
            '${attempt + 1} intento${attempt == 0 ? '' : 's'}. Espera un '
            'momento y vuelve a intentar.');
      }
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
