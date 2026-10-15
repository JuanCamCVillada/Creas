/// Receives a one-line summary of a request's token usage, so what a
/// generation actually cost can be seen (and the prompt tuned against it)
/// instead of guessed. Null in production; main.dart wires it up in debug.
typedef UsageLogger = void Function(String line);

/// A ceiling on what a single generation may write. A graph is ~2k tokens, so
/// this never binds in normal use; it exists to stop a runaway or looping
/// response from burning the user's money. Kept generous because for a
/// reasoning model the cap also counts its hidden thinking tokens, and
/// cutting a response off mid-graph would fail the generation outright.
const int kMaxOutputTokens = 16000;

/// How long one request may take. A graph is ~2k output tokens, which comes
/// back in well under a minute, so this only fires on a provider that has
/// hung — and then fails the attempt fast enough for a fallback to be useful.
const Duration kRequestTimeout = Duration(seconds: 90);

abstract class GraphGenerationClient {
  /// [maxRetries] overrides how many times a transient failure (an overloaded
  /// model, a rate limit) is retried before giving up. The engine lowers it
  /// when another provider is standing by: waiting through several backoffs
  /// on a struggling provider is worse than switching to the fallback.
  Future<Map<String, dynamic>> requestToolCall({
    required String apiKey,
    required String systemPrompt,
    required String userInput,
    int? maxRetries,
  });
}

/// A failure talking to an LLM provider (HTTP error, an empty or malformed
/// response). Provider-neutral: the message itself names which provider.
class LlmApiException implements Exception {
  const LlmApiException(this.message);
  final String message;

  @override
  String toString() => 'LlmApiException: $message';
}
