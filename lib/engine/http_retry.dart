import 'dart:async';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import 'graph_generation_client.dart';

class RetriedResponse {
  const RetriedResponse(this.response, this.attempts);

  final http.Response response;

  /// How many requests were actually sent (1 means it never had to retry).
  final int attempts;
}

/// POSTs [body] and retries while [isTransient] says the failure is worth
/// another try (an overloaded model, a rate limit), waiting [baseDelay],
/// then double that, and so on between attempts. Returns the last response
/// either way — the caller decides what a still-failing response means.
///
/// A request that can't be made at all (no network) or that doesn't answer
/// within [timeout] is not retried: it throws an [LlmApiException] naming
/// [providerName] right away. A hung provider must fail quickly, not hold
/// the whole generation up, so that a fallback provider can take over.
Future<RetriedResponse> postWithRetry({
  required http.Client client,
  required Uri url,
  required Map<String, String> headers,
  required String body,
  required String providerName,
  required int maxRetries,
  required Duration baseDelay,
  required Duration timeout,
  required bool Function(http.Response response) isTransient,
}) async {
  var attempt = 0;
  while (true) {
    final http.Response response;
    try {
      response = await client.post(url, headers: headers, body: body).timeout(timeout);
    } on TimeoutException {
      throw LlmApiException(
          '$providerName no respondió en ${timeout.inSeconds} segundos.');
    } on http.ClientException catch (e) {
      throw LlmApiException('No pude conectar con $providerName: ${e.message}');
    }

    if (!isTransient(response) || attempt >= maxRetries) {
      return RetriedResponse(response, attempt + 1);
    }
    await Future<void>.delayed(baseDelay * math.pow(2, attempt).toInt());
    attempt++;
  }
}
