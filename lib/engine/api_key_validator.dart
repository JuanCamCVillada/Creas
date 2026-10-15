import 'package:http/http.dart' as http;

import 'llm_provider.dart';

enum KeyCheckStatus {
  /// The provider accepted the key.
  valid,

  /// The provider rejected it (wrong, truncated, revoked, or for a
  /// different provider than the one chosen).
  invalid,

  /// A key of a provider the app doesn't support (Anthropic).
  unsupported,

  /// Nothing to go on: the key's shape matches no known provider and none
  /// was chosen by hand.
  undetected,

  /// Nothing was entered.
  empty,

  /// The provider couldn't be reached or answered unexpectedly, so the key
  /// is neither confirmed nor refused.
  unverified,
}

class KeyCheckResult {
  const KeyCheckResult(this.status, this.message, {this.provider});

  final KeyCheckStatus status;
  final String message;

  /// The provider that was checked, when one could be determined.
  final LlmProvider? provider;
}

abstract class ApiKeyValidator {
  /// Checks [key] against its provider's API. [provider] forces the choice;
  /// left null the provider is detected from the key's shape.
  Future<KeyCheckResult> validate(String key, {LlmProvider? provider});
}

/// Validates by making one cheap, read-only request (listing models) to the
/// key's own provider — the key only ever goes to that provider's API, over
/// HTTPS, which is the same place it's used to generate graphs.
class LiveApiKeyValidator implements ApiKeyValidator {
  LiveApiKeyValidator({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const _timeout = Duration(seconds: 10);

  @override
  Future<KeyCheckResult> validate(String key, {LlmProvider? provider}) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      return const KeyCheckResult(KeyCheckStatus.empty, 'Pega una clave primero.');
    }
    if (provider == null && isAnthropicKey(trimmed)) {
      return const KeyCheckResult(
        KeyCheckStatus.unsupported,
        'Las claves de Anthropic (sk-ant-…) no están soportadas. Usa una de '
        'Gemini (AIza…) o de OpenAI (sk-…).',
      );
    }

    final target = provider ?? detectProvider(trimmed);
    if (target == null) {
      return const KeyCheckResult(
        KeyCheckStatus.undetected,
        'No reconozco el formato de la clave. Elige el proveedor manualmente.',
      );
    }

    final http.Response response;
    try {
      response = await _httpClient
          .get(_endpointFor(target), headers: _headersFor(target, trimmed))
          .timeout(_timeout);
    } on Exception {
      return KeyCheckResult(
        KeyCheckStatus.unverified,
        'No pude conectar con ${target.label} para verificar la clave. '
        'Revisa tu conexión.',
        provider: target,
      );
    }

    switch (response.statusCode) {
      case 200:
        return KeyCheckResult(
          KeyCheckStatus.valid,
          'Clave de ${target.label} verificada.',
          provider: target,
        );
      case 400:
      case 401:
      case 403:
        return KeyCheckResult(
          KeyCheckStatus.invalid,
          '${target.label} rechazó la clave (${response.statusCode}). Revisa '
          'que esté completa y sea de ese proveedor.',
          provider: target,
        );
      default:
        return KeyCheckResult(
          KeyCheckStatus.unverified,
          '${target.label} respondió ${response.statusCode}; no pude '
          'confirmar la clave.',
          provider: target,
        );
    }
  }

  static Uri _endpointFor(LlmProvider provider) => switch (provider) {
        LlmProvider.gemini => Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models?pageSize=1'),
        LlmProvider.openai => Uri.parse('https://api.openai.com/v1/models'),
      };

  static Map<String, String> _headersFor(LlmProvider provider, String key) =>
      switch (provider) {
        LlmProvider.gemini => {'x-goog-api-key': key},
        LlmProvider.openai => {'authorization': 'Bearer $key'},
      };
}
