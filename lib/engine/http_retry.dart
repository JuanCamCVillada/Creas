import 'dart:math' as math;

import 'package:http/http.dart' as http;

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
Future<RetriedResponse> postWithRetry({
  required http.Client client,
  required Uri url,
  required Map<String, String> headers,
  required String body,
  required int maxRetries,
  required Duration baseDelay,
  required bool Function(http.Response response) isTransient,
}) async {
  var attempt = 0;
  while (true) {
    final response = await client.post(url, headers: headers, body: body);
    if (!isTransient(response) || attempt >= maxRetries) {
      return RetriedResponse(response, attempt + 1);
    }
    await Future<void>.delayed(baseDelay * math.pow(2, attempt).toInt());
    attempt++;
  }
}
