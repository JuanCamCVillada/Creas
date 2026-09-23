import '../models/creative_graph.dart';
import '../models/session.dart';
import '../storage/api_key_store.dart';
import 'graph_generation_client.dart';
import 'graph_generator.dart';
import 'graph_parser.dart';
import 'graph_verifier.dart';
import 'system_prompt.dart';

class GenerationEngine implements GraphGenerator {
  GenerationEngine({
    required GraphGenerationClient client,
    required ApiKeyStore apiKeyStore,
  })  : _client = client,
        _apiKeyStore = apiKeyStore;

  final GraphGenerationClient _client;
  final ApiKeyStore _apiKeyStore;

  static const _maxAttempts = 2;

  @override
  Future<GraphSession> generate(String rawInput) async {
    final apiKey = await _apiKeyStore.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw const GenerationFailedException(
          'no hay una clave de API de Gemini configurada');
    }

    CreativeGraph? verifiedGraph;
    Object? lastError;

    for (var attempt = 0; attempt < _maxAttempts && verifiedGraph == null; attempt++) {
      try {
        final rawArgs = await _client.requestToolCall(
          apiKey: apiKey,
          systemPrompt: creativeGraphSystemPrompt,
          userInput: rawInput,
        );
        final parsed = parseCreativeGraph(rawArgs);
        verifiedGraph = verifyGraph(parsed);
      } on GraphParseException catch (e) {
        lastError = e;
      } on CyclicGraphException catch (e) {
        lastError = e;
      }
    }

    if (verifiedGraph == null) {
      throw GenerationFailedException('no se pudo generar el grafo: $lastError');
    }

    return GraphSession(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      rawInput: rawInput,
      graph: verifiedGraph,
      createdAt: DateTime.now(),
    );
  }
}
