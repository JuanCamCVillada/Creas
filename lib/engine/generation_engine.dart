import '../models/creative_graph.dart';
import '../models/session.dart';
import '../storage/api_key_store.dart';
import 'graph_generation_client.dart';
import 'graph_generator.dart';
import 'graph_parser.dart';
import 'graph_verifier.dart';
import 'llm_provider.dart';
import 'system_prompt.dart';

class GenerationEngine implements GraphGenerator {
  GenerationEngine({
    required Map<LlmProvider, GraphGenerationClient> clients,
    required ApiKeyStore apiKeyStore,
  })  : _clients = clients,
        _apiKeyStore = apiKeyStore;

  final Map<LlmProvider, GraphGenerationClient> _clients;
  final ApiKeyStore _apiKeyStore;

  static const _maxAttempts = 2;

  @override
  Future<GraphSession> generate(String rawInput) async {
    final apiKey = await _apiKeyStore.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw const GenerationFailedException(
          'no hay una clave de API configurada');
    }

    // Whichever provider the key belongs to serves the request — chosen by
    // hand in settings, else detected from the key's shape.
    final provider = resolveProvider(
      apiKey,
      explicit: await _apiKeyStore.getProvider(),
    );
    final client = _clients[provider];
    if (client == null) {
      throw GenerationFailedException(
          'no hay un cliente configurado para ${provider.label}');
    }

    CreativeGraph? verifiedGraph;
    Object? lastError;

    for (var attempt = 0; attempt < _maxAttempts && verifiedGraph == null; attempt++) {
      try {
        final rawArgs = await client.requestToolCall(
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
