abstract class GraphGenerationClient {
  Future<Map<String, dynamic>> requestToolCall({
    required String apiKey,
    required String systemPrompt,
    required String userInput,
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
