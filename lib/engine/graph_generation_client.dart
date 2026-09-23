abstract class GraphGenerationClient {
  Future<Map<String, dynamic>> requestToolCall({
    required String apiKey,
    required String systemPrompt,
    required String userInput,
  });
}

class GeminiApiException implements Exception {
  const GeminiApiException(this.message);
  final String message;

  @override
  String toString() => 'GeminiApiException: $message';
}
