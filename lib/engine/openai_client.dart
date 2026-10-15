import 'dart:convert';

import 'package:http/http.dart' as http;

import 'graph_generation_client.dart';
import 'http_retry.dart';
import 'tool_schema.dart';

/// Generates the graph through OpenAI's Chat Completions API, forcing a call
/// to the same `emit_creative_graph` function the Gemini client forces —
/// the rest of the engine can't tell which provider answered.
class OpenAiClient implements GraphGenerationClient {
  OpenAiClient({
    http.Client? httpClient,
    this.model,
    this.maxRetries = 3,
    this.baseRetryDelay = const Duration(seconds: 1),
  }) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// Pin a specific model. Left null, the client picks the best one the
  /// key's account can actually use (see [_resolveModel]).
  final String? model;
  final int maxRetries;
  final Duration baseRetryDelay;

  static const _baseUrl = 'https://api.openai.com/v1';
  static const _functionName = 'emit_creative_graph';

  /// Best-fit first. Which models exist (and which an account can use)
  /// changes too often to hardcode one and trust it — an earlier Gemini
  /// model id that simply didn't exist cost three 404s — so the client asks
  /// the API what's available and takes the first of these it finds.
  static const _preferredModels = [
    'gpt-4.1-mini',
    'gpt-5-mini',
    'gpt-4o-mini',
    'gpt-4.1',
    'gpt-4o',
  ];
  static const _fallbackModel = 'gpt-4o-mini';

  String? _resolvedFor;
  String? _resolvedModel;

  Future<String> _resolveModel(String apiKey) async {
    if (model != null) return model!;
    if (_resolvedFor == apiKey && _resolvedModel != null) return _resolvedModel!;

    try {
      final response = await _httpClient.get(
        Uri.parse('$_baseUrl/models'),
        headers: {'authorization': 'Bearer $apiKey'},
      );
      if (response.statusCode == 200) {
        final data = (jsonDecode(response.body) as Map<String, dynamic>)['data'] as List<dynamic>;
        final available = {for (final m in data) (m as Map<String, dynamic>)['id'] as String};
        final picked = _preferredModels.firstWhere(available.contains, orElse: () => _fallbackModel);
        _resolvedFor = apiKey;
        _resolvedModel = picked;
        return picked;
      }
    } on Exception {
      // Listing is best effort: if it fails, the real request below will
      // surface the actual problem (a bad key, no network) with a proper
      // message instead of this lookup failing first.
    }
    return _fallbackModel;
  }

  static bool _isQuotaExhausted(http.Response r) =>
      r.statusCode == 429 && r.body.contains('insufficient_quota');

  // A 429 that says the account is out of quota won't clear by waiting, so
  // it's the one rate-limit response that isn't worth retrying.
  static bool _isTransient(http.Response r) =>
      const {500, 502, 503}.contains(r.statusCode) ||
      (r.statusCode == 429 && !_isQuotaExhausted(r));

  @override
  Future<Map<String, dynamic>> requestToolCall({
    required String apiKey,
    required String systemPrompt,
    required String userInput,
  }) async {
    final resolvedModel = await _resolveModel(apiKey);

    final body = jsonEncode({
      'model': resolvedModel,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userInput},
      ],
      'tools': [
        {
          'type': 'function',
          'function': {
            'name': emitCreativeGraphToolSchema['name'],
            'description': emitCreativeGraphToolSchema['description'],
            'parameters': toStandardJsonSchema(
              emitCreativeGraphToolSchema['input_schema'] as Map<String, dynamic>,
            ),
          },
        },
      ],
      'tool_choice': {
        'type': 'function',
        'function': {'name': _functionName},
      },
    });

    final retried = await postWithRetry(
      client: _httpClient,
      url: Uri.parse('$_baseUrl/chat/completions'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $apiKey',
      },
      body: body,
      maxRetries: maxRetries,
      baseDelay: baseRetryDelay,
      isTransient: _isTransient,
    );
    final response = retried.response;

    if (response.statusCode != 200) {
      if (_isQuotaExhausted(response)) {
        throw const LlmApiException(
            'OpenAI: sin cuota o crédito disponible (insufficient_quota). '
            'Revisa tu plan y facturación en platform.openai.com.');
      }
      if (_isTransient(response)) {
        throw LlmApiException(
            'OpenAI está sobrecargado o limitando solicitudes '
            '(${response.statusCode}) tras ${retried.attempts} '
            'intento${retried.attempts == 1 ? '' : 's'}. Espera un momento y '
            'vuelve a intentar.');
      }
      throw LlmApiException(
          'OpenAI API devolvió ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw const LlmApiException('respuesta sin choices');
    }

    final message = (choices.first as Map<String, dynamic>)['message'] as Map<String, dynamic>?;
    final toolCalls = message?['tool_calls'] as List<dynamic>?;
    if (toolCalls == null || toolCalls.isEmpty) {
      throw const LlmApiException('el modelo no llamó a emit_creative_graph');
    }

    final function = (toolCalls.first as Map<String, dynamic>)['function'] as Map<String, dynamic>;
    final arguments = function['arguments'];
    if (arguments is! String) {
      throw const LlmApiException('la llamada a la función no trae argumentos');
    }
    try {
      return jsonDecode(arguments) as Map<String, dynamic>;
    } on FormatException {
      throw const LlmApiException('los argumentos de la función no son JSON válido');
    }
  }
}
