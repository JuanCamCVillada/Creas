abstract class GraphGenerationClient {
  Future<Map<String, dynamic>> requestToolCall({
    required String apiKey,
    required String systemPrompt,
    required String userInput,
  });
}

class AnthropicApiException implements Exception {
  const AnthropicApiException(this.message);
  final String message;

  @override
  String toString() => 'AnthropicApiException: $message';
}
