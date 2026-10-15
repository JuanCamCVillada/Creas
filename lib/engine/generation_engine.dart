import '../models/creative_graph.dart';
import '../models/session.dart';
import '../storage/api_key_store.dart';
import 'graph_generation_client.dart';
import 'graph_generator.dart';
import 'graph_parser.dart';
import 'graph_verifier.dart';
import 'input_compaction.dart';
import 'llm_provider.dart';
import 'system_prompt.dart';

/// Why one provider didn't produce the graph.
class ProviderFailure {
  const ProviderFailure(this.provider, this.reason);

  final LlmProvider provider;
  final String reason;
}

/// Reported when a generation had to fall back: [used] produced the graph
/// after every provider in [failed] was tried first.
class FailoverNotice {
  const FailoverNotice({required this.used, required this.failed});

  final LlmProvider used;
  final List<ProviderFailure> failed;
}

typedef FailoverListener = void Function(FailoverNotice notice);

class GenerationEngine implements GraphGenerator {
  GenerationEngine({
    required Map<LlmProvider, GraphGenerationClient> clients,
    required ApiKeyStore apiKeyStore,
    this.onFailover,
  })  : _clients = clients,
        _apiKeyStore = apiKeyStore;

  final Map<LlmProvider, GraphGenerationClient> _clients;
  final ApiKeyStore _apiKeyStore;

  /// Called when a provider other than the first choice ended up serving the
  /// request, so the user is told their primary failed instead of finding
  /// out from the bill.
  final FailoverListener? onFailover;

  static const _maxAttempts = 2;

  /// Retries a provider gets for a transient failure (overloaded, rate
  /// limited) when another provider is waiting to take over. Without a
  /// fallback the client's own, larger default applies: there's nowhere
  /// else to go, so waiting it out is the right call.
  static const _retriesWhenFallbackExists = 1;

  @override
  Future<GraphSession> generate(String rawInput) async {
    // Nothing to analyze: don't pay for a request that can only come back
    // as "please give me something".
    final userInput = compactInput(rawInput);
    if (userInput.isEmpty) {
      throw const GenerationFailedException('escribe algo para analizar');
    }

    final credentials = await _apiKeyStore.credentialsInOrder();
    if (credentials.isEmpty) {
      throw const GenerationFailedException(
          'no hay una clave de API configurada');
    }

    // The primary first, then each remaining provider that has a key: the
    // first one to deliver a verified graph wins, so a provider that is
    // overloaded, out of quota, hung, or that keeps returning unusable
    // output doesn't stop the user from getting a result.
    final failures = <ProviderFailure>[];
    for (var i = 0; i < credentials.length; i++) {
      final credential = credentials[i];
      final client = _clients[credential.provider];
      if (client == null) {
        failures.add(ProviderFailure(
            credential.provider, 'no hay un cliente configurado para ${credential.provider.label}'));
        continue;
      }

      final hasFallback = i < credentials.length - 1;
      try {
        final graph = await _generateWith(
          client,
          credential.key,
          userInput,
          maxRetries: hasFallback ? _retriesWhenFallbackExists : null,
        );
        if (failures.isNotEmpty) {
          onFailover?.call(FailoverNotice(used: credential.provider, failed: failures));
        }
        return GraphSession(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          rawInput: rawInput,
          graph: graph,
          createdAt: DateTime.now(),
        );
      } on LlmApiException catch (e) {
        failures.add(ProviderFailure(credential.provider, e.message));
      } on _UnusableOutput catch (e) {
        failures.add(ProviderFailure(credential.provider, e.message));
      }
    }

    throw GenerationFailedException(_describe(failures));
  }

  /// Asks one provider for a graph, asking again once if what came back was
  /// malformed or had a cycle. Throws [LlmApiException] if the provider
  /// itself fails and [_UnusableOutput] if it never produces a valid graph.
  Future<CreativeGraph> _generateWith(
    GraphGenerationClient client,
    String apiKey,
    String userInput, {
    int? maxRetries,
  }) async {
    CreativeGraph? verifiedGraph;
    Object? lastError;

    for (var attempt = 0; attempt < _maxAttempts && verifiedGraph == null; attempt++) {
      try {
        final rawArgs = await client.requestToolCall(
          apiKey: apiKey,
          systemPrompt: creativeGraphSystemPrompt,
          userInput: userInput,
          maxRetries: maxRetries,
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
      throw _UnusableOutput('no se pudo generar el grafo: $lastError');
    }
    return verifiedGraph;
  }

  /// With one provider the reason is shown as is; with several, each one's
  /// is named so it's clear nothing was left untried.
  static String _describe(List<ProviderFailure> failures) {
    if (failures.length == 1) return failures.single.reason;
    final each = failures.map((f) => '${f.provider.label}: ${f.reason}').join(' · ');
    return 'ningún proveedor pudo generar el grafo — $each';
  }
}

class _UnusableOutput implements Exception {
  const _UnusableOutput(this.message);
  final String message;
}
