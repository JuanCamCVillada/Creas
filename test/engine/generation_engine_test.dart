import 'package:flutter_test/flutter_test.dart';
import 'package:creative/engine/generation_engine.dart';
import 'package:creative/engine/graph_generation_client.dart';
import 'package:creative/engine/graph_generator.dart';
import 'package:creative/engine/llm_provider.dart';

import '../helpers/fakes.dart';

Map<String, dynamic> _validArgs() => {
      'nodes': [
        {
          'id': 's1',
          'type': 'fuente',
          'label': 'Charla',
          'description': 'd',
          'cluster': 'bases-de-datos',
          'origin': 'usuario',
        },
        {
          'id': 'c1',
          'type': 'concepto',
          'label': 'Cache manual',
          'description': 'd',
          'cluster': 'arquitectura-software',
          'origin': 'usuario',
        },
      ],
      'edges': [
        {'id': 'e1', 'source': 's1', 'target': 'c1', 'relation': 'desencadena'},
      ],
      'affinity_edges': <Map<String, dynamic>>[],
      'turning_point_candidates': <Map<String, dynamic>>[],
      'followup_questions': <String>[],
    };

Map<String, dynamic> _cyclicArgs() => {
      'nodes': [
        {
          'id': 'c1',
          'type': 'concepto',
          'label': 'a',
          'description': 'd',
          'cluster': 'x',
          'origin': 'usuario',
        },
        {
          'id': 'c2',
          'type': 'concepto',
          'label': 'b',
          'description': 'd',
          'cluster': 'x',
          'origin': 'usuario',
        },
      ],
      'edges': [
        {'id': 'e1', 'source': 'c1', 'target': 'c2', 'relation': 'deriva_de'},
        {'id': 'e2', 'source': 'c2', 'target': 'c1', 'relation': 'deriva_de'},
      ],
      'affinity_edges': <Map<String, dynamic>>[],
      'turning_point_candidates': <Map<String, dynamic>>[],
      'followup_questions': <String>[],
    };

void main() {
  group('GenerationEngine', () {
    test('returns a saved GraphSession on the first successful attempt', () async {
      final apiKeyStore = FakeApiKeyStore('AIzaTest');
      final client = FakeGraphGenerationClient([_validArgs]);
      final GraphGenerator engine =
          GenerationEngine(clients: {LlmProvider.gemini: client}, apiKeyStore: apiKeyStore);

      final session = await engine.generate('input de prueba');

      expect(session.rawInput, 'input de prueba');
      expect(session.graph.nodes, hasLength(2));
      expect(client.callCount, 1);
    });

    test('retries once after a malformed response, then succeeds', () async {
      final apiKeyStore = FakeApiKeyStore('AIzaTest');
      final client = FakeGraphGenerationClient([
        () => {'nodes': 'not-a-list'},
        _validArgs,
      ]);
      final GraphGenerator engine =
          GenerationEngine(clients: {LlmProvider.gemini: client}, apiKeyStore: apiKeyStore);

      final session = await engine.generate('input de prueba');

      expect(session.graph.nodes, hasLength(2));
      expect(client.callCount, 2);
    });

    test('throws GenerationFailedException after two malformed responses', () async {
      final apiKeyStore = FakeApiKeyStore('AIzaTest');
      final client = FakeGraphGenerationClient([
        () => {'nodes': 'not-a-list'},
        () => {'nodes': 'still-not-a-list'},
      ]);
      final GraphGenerator engine =
          GenerationEngine(clients: {LlmProvider.gemini: client}, apiKeyStore: apiKeyStore);

      expect(
        () => engine.generate('input de prueba'),
        throwsA(isA<GenerationFailedException>()),
      );
    });

    test('retries once after a cyclic lineage, then succeeds', () async {
      final apiKeyStore = FakeApiKeyStore('AIzaTest');
      final client = FakeGraphGenerationClient([_cyclicArgs, _validArgs]);
      final GraphGenerator engine =
          GenerationEngine(clients: {LlmProvider.gemini: client}, apiKeyStore: apiKeyStore);

      final session = await engine.generate('input de prueba');

      // The cycle is rejected and retried once, same as a parse failure.
      expect(session.graph.nodes, hasLength(2));
      expect(client.callCount, 2);
    });

    test('throws GenerationFailedException when no API key is configured', () async {
      final apiKeyStore = FakeApiKeyStore();
      final client = FakeGraphGenerationClient([_validArgs]);
      final GraphGenerator engine =
          GenerationEngine(clients: {LlmProvider.gemini: client}, apiKeyStore: apiKeyStore);

      expect(
        () => engine.generate('input de prueba'),
        throwsA(isA<GenerationFailedException>()),
      );
      expect(client.callCount, 0);
    });
    test('routes to the OpenAI client when the key is an OpenAI key', () async {
      final apiKeyStore = FakeApiKeyStore('sk-proj-abc123');
      final gemini = FakeGraphGenerationClient([_validArgs]);
      final openai = FakeGraphGenerationClient([_validArgs]);
      final GraphGenerator engine = GenerationEngine(
        clients: {LlmProvider.gemini: gemini, LlmProvider.openai: openai},
        apiKeyStore: apiKeyStore,
      );

      await engine.generate('input de prueba');

      expect(openai.callCount, 1);
      expect(gemini.callCount, 0);
    });

    test('routes to the Gemini client when the key is a Gemini key', () async {
      final apiKeyStore = FakeApiKeyStore('AIzaSyExample');
      final gemini = FakeGraphGenerationClient([_validArgs]);
      final openai = FakeGraphGenerationClient([_validArgs]);
      final GraphGenerator engine = GenerationEngine(
        clients: {LlmProvider.gemini: gemini, LlmProvider.openai: openai},
        apiKeyStore: apiKeyStore,
      );

      await engine.generate('input de prueba');

      expect(gemini.callCount, 1);
      expect(openai.callCount, 0);
    });

    test('an explicit provider choice overrides what the key looks like', () async {
      // A key whose shape says OpenAI, but the user pinned Gemini.
      final apiKeyStore = FakeApiKeyStore('sk-proj-abc123', LlmProvider.gemini);
      final gemini = FakeGraphGenerationClient([_validArgs]);
      final openai = FakeGraphGenerationClient([_validArgs]);
      final GraphGenerator engine = GenerationEngine(
        clients: {LlmProvider.gemini: gemini, LlmProvider.openai: openai},
        apiKeyStore: apiKeyStore,
      );

      await engine.generate('input de prueba');

      expect(gemini.callCount, 1);
      expect(openai.callCount, 0);
    });

    test('falls back to Gemini for a key whose shape is unrecognized', () async {
      // Keeps keys saved before provider selection existed working.
      final apiKeyStore = FakeApiKeyStore('some-unknown-format');
      final gemini = FakeGraphGenerationClient([_validArgs]);
      final GraphGenerator engine = GenerationEngine(
        clients: {LlmProvider.gemini: gemini},
        apiKeyStore: apiKeyStore,
      );

      await engine.generate('input de prueba');

      expect(gemini.callCount, 1);
    });

    test('throws when the resolved provider has no client registered', () async {
      final apiKeyStore = FakeApiKeyStore('sk-proj-abc123');
      final GraphGenerator engine = GenerationEngine(
        clients: {LlmProvider.gemini: FakeGraphGenerationClient([_validArgs])},
        apiKeyStore: apiKeyStore,
      );

      expect(
        () => engine.generate('input de prueba'),
        throwsA(isA<GenerationFailedException>()),
      );
    });
    test('sends the compacted input to the model but keeps the original in '
        'the session', () async {
      final seen = <String>[];
      final client = _RecordingClient(_validArgs, seen);
      final GraphGenerator engine = GenerationEngine(
        clients: {LlmProvider.gemini: client},
        apiKeyStore: FakeApiKeyStore('AIzaTest'),
      );

      final session = await engine.generate('hola   \n\n\n\nmundo  ');

      expect(seen.single, 'hola\n\nmundo');
      expect(session.rawInput, 'hola   \n\n\n\nmundo  ');
    });

    test('does not call the model at all for empty input — nothing to pay '
        'for', () async {
      final client = FakeGraphGenerationClient([_validArgs]);
      final GraphGenerator engine = GenerationEngine(
        clients: {LlmProvider.gemini: client},
        apiKeyStore: FakeApiKeyStore('AIzaTest'),
      );

      await expectLater(
        engine.generate('  \n\n  '),
        throwsA(isA<GenerationFailedException>()),
      );
      expect(client.callCount, 0);
    });
  });
}

class _RecordingClient implements GraphGenerationClient {
  _RecordingClient(this._args, this.inputs);

  final Map<String, dynamic> Function() _args;
  final List<String> inputs;

  @override
  Future<Map<String, dynamic>> requestToolCall({
    required String apiKey,
    required String systemPrompt,
    required String userInput,
  }) async {
    inputs.add(userInput);
    return _args();
  }
}
