import 'package:flutter_test/flutter_test.dart';
import 'package:creative/engine/generation_engine.dart';
import 'package:creative/engine/graph_generation_client.dart';
import 'package:creative/engine/graph_generator.dart';
import 'package:creative/engine/llm_provider.dart';
import 'package:creative/storage/api_key_store.dart';

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

final _geminiKey = {LlmProvider.gemini: 'AIzaGeminiKey'};
final _bothKeys = {
  LlmProvider.gemini: 'AIzaGeminiKey',
  LlmProvider.openai: 'sk-proj-openaiKey',
};

/// A response that fails the way a provider does when it is down.
Map<String, dynamic> _down([String reason = 'está sobrecargado (503)']) =>
    throw LlmApiException(reason);

GenerationEngine _engine(
  Map<LlmProvider, GraphGenerationClient> clients,
  FakeApiKeyStore store, {
  FailoverListener? onFailover,
}) =>
    GenerationEngine(clients: clients, apiKeyStore: store, onFailover: onFailover);

void main() {
  group('GenerationEngine', () {
    test('returns a saved GraphSession on the first successful attempt', () async {
      final client = FakeGraphGenerationClient([_validArgs]);
      final GraphGenerator engine =
          _engine({LlmProvider.gemini: client}, FakeApiKeyStore(keys: _geminiKey));

      final session = await engine.generate('input de prueba');

      expect(session.rawInput, 'input de prueba');
      expect(session.graph.nodes, hasLength(2));
      expect(client.callCount, 1);
    });

    test('retries once after a malformed response, then succeeds', () async {
      final client = FakeGraphGenerationClient([
        () => {'nodes': 'not-a-list'},
        _validArgs,
      ]);
      final GraphGenerator engine =
          _engine({LlmProvider.gemini: client}, FakeApiKeyStore(keys: _geminiKey));

      final session = await engine.generate('input de prueba');

      expect(session.graph.nodes, hasLength(2));
      expect(client.callCount, 2);
    });

    test('throws GenerationFailedException after two malformed responses', () async {
      final client = FakeGraphGenerationClient([
        () => {'nodes': 'not-a-list'},
        () => {'nodes': 'still-not-a-list'},
      ]);
      final GraphGenerator engine =
          _engine({LlmProvider.gemini: client}, FakeApiKeyStore(keys: _geminiKey));

      expect(
        () => engine.generate('input de prueba'),
        throwsA(isA<GenerationFailedException>()),
      );
    });

    test('retries once after a cyclic lineage, then succeeds', () async {
      final client = FakeGraphGenerationClient([_cyclicArgs, _validArgs]);
      final GraphGenerator engine =
          _engine({LlmProvider.gemini: client}, FakeApiKeyStore(keys: _geminiKey));

      final session = await engine.generate('input de prueba');

      // The cycle is rejected and retried once, same as a parse failure.
      expect(session.graph.nodes, hasLength(2));
      expect(client.callCount, 2);
    });

    test('throws GenerationFailedException when no API key is configured', () async {
      final client = FakeGraphGenerationClient([_validArgs]);
      final GraphGenerator engine = _engine({LlmProvider.gemini: client}, FakeApiKeyStore());

      expect(
        () => engine.generate('input de prueba'),
        throwsA(isA<GenerationFailedException>()),
      );
      expect(client.callCount, 0);
    });

    test('sends the compacted input to the model but keeps the original in '
        'the session', () async {
      final seen = <String>[];
      final client = _RecordingClient(_validArgs, seen);
      final GraphGenerator engine =
          _engine({LlmProvider.gemini: client}, FakeApiKeyStore(keys: _geminiKey));

      final session = await engine.generate('hola   \n\n\n\nmundo  ');

      expect(seen.single, 'hola\n\nmundo');
      expect(session.rawInput, 'hola   \n\n\n\nmundo  ');
    });

    test('does not call the model at all for empty input — nothing to pay '
        'for', () async {
      final client = FakeGraphGenerationClient([_validArgs]);
      final GraphGenerator engine =
          _engine({LlmProvider.gemini: client}, FakeApiKeyStore(keys: _geminiKey));

      await expectLater(
        engine.generate('  \n\n  '),
        throwsA(isA<GenerationFailedException>()),
      );
      expect(client.callCount, 0);
    });
  });

  group('which provider is tried', () {
    test('a Gemini key goes to the Gemini client with that key', () async {
      final gemini = FakeGraphGenerationClient([_validArgs]);
      final openai = FakeGraphGenerationClient([_validArgs]);
      final engine = _engine(
        {LlmProvider.gemini: gemini, LlmProvider.openai: openai},
        FakeApiKeyStore(keys: _geminiKey),
      );

      await engine.generate('input de prueba');

      expect(gemini.apiKeysSeen, ['AIzaGeminiKey']);
      expect(openai.callCount, 0);
    });

    test('an OpenAI-only setup goes to the OpenAI client', () async {
      final gemini = FakeGraphGenerationClient([_validArgs]);
      final openai = FakeGraphGenerationClient([_validArgs]);
      final engine = _engine(
        {LlmProvider.gemini: gemini, LlmProvider.openai: openai},
        FakeApiKeyStore(keys: {LlmProvider.openai: 'sk-proj-openaiKey'}),
      );

      await engine.generate('input de prueba');

      expect(openai.apiKeysSeen, ['sk-proj-openaiKey']);
      expect(gemini.callCount, 0);
    });

    test('with both configured, Gemini goes first by default', () async {
      final gemini = FakeGraphGenerationClient([_validArgs]);
      final openai = FakeGraphGenerationClient([_validArgs]);
      final engine = _engine(
        {LlmProvider.gemini: gemini, LlmProvider.openai: openai},
        FakeApiKeyStore(keys: _bothKeys),
      );

      await engine.generate('input de prueba');

      expect(gemini.callCount, 1);
      expect(openai.callCount, 0);
    });

    test('the chosen primary is tried first, each client getting its own key',
        () async {
      final gemini = FakeGraphGenerationClient([_validArgs]);
      final openai = FakeGraphGenerationClient([_validArgs]);
      final engine = _engine(
        {LlmProvider.gemini: gemini, LlmProvider.openai: openai},
        FakeApiKeyStore(keys: _bothKeys, primary: LlmProvider.openai),
      );

      await engine.generate('input de prueba');

      expect(openai.apiKeysSeen, ['sk-proj-openaiKey']);
      expect(gemini.callCount, 0);
    });

    test('a primary with no key is ignored', () async {
      final gemini = FakeGraphGenerationClient([_validArgs]);
      final openai = FakeGraphGenerationClient([_validArgs]);
      final engine = _engine(
        {LlmProvider.gemini: gemini, LlmProvider.openai: openai},
        FakeApiKeyStore(keys: _geminiKey, primary: LlmProvider.openai),
      );

      await engine.generate('input de prueba');

      expect(gemini.callCount, 1);
      expect(openai.callCount, 0);
    });
  });

  group('failover', () {
    test('a provider that is down hands the job to the next one', () async {
      final gemini = FakeGraphGenerationClient([_down]);
      final openai = FakeGraphGenerationClient([_validArgs]);
      final engine = _engine(
        {LlmProvider.gemini: gemini, LlmProvider.openai: openai},
        FakeApiKeyStore(keys: _bothKeys),
      );

      final session = await engine.generate('input de prueba');

      expect(session.graph.nodes, hasLength(2));
      expect(gemini.callCount, 1);
      expect(openai.apiKeysSeen, ['sk-proj-openaiKey']);
    });

    test('tells the listener which provider failed, why, and who served it',
        () async {
      FailoverNotice? notice;
      final engine = _engine(
        {
          LlmProvider.gemini: FakeGraphGenerationClient([() => _down('Gemini está sobrecargado')]),
          LlmProvider.openai: FakeGraphGenerationClient([_validArgs]),
        },
        FakeApiKeyStore(keys: _bothKeys),
        onFailover: (n) => notice = n,
      );

      await engine.generate('input de prueba');

      expect(notice, isNotNull);
      expect(notice!.used, LlmProvider.openai);
      expect(notice!.failed.single.provider, LlmProvider.gemini);
      expect(notice!.failed.single.reason, 'Gemini está sobrecargado');
    });

    test('stays silent when the first provider simply works', () async {
      var notices = 0;
      final engine = _engine(
        {
          LlmProvider.gemini: FakeGraphGenerationClient([_validArgs]),
          LlmProvider.openai: FakeGraphGenerationClient([_validArgs]),
        },
        FakeApiKeyStore(keys: _bothKeys),
        onFailover: (_) => notices++,
      );

      await engine.generate('input de prueba');

      expect(notices, 0);
    });

    test('falls over when a provider keeps returning unusable graphs, too',
        () async {
      final gemini = FakeGraphGenerationClient([
        () => {'nodes': 'not-a-list'},
        () => {'nodes': 'still-not-a-list'},
      ]);
      final openai = FakeGraphGenerationClient([_validArgs]);
      FailoverNotice? notice;
      final engine = _engine(
        {LlmProvider.gemini: gemini, LlmProvider.openai: openai},
        FakeApiKeyStore(keys: _bothKeys),
        onFailover: (n) => notice = n,
      );

      await engine.generate('input de prueba');

      expect(gemini.callCount, 2); // its own retry first
      expect(openai.callCount, 1);
      expect(notice!.failed.single.reason, contains('no se pudo generar el grafo'));
    });

    test('a bad key on the primary is skipped over, not fatal', () async {
      final engine = _engine(
        {
          LlmProvider.gemini: FakeGraphGenerationClient(
              [() => throw const LlmApiException('Gemini API devolvió 400: API key not valid')]),
          LlmProvider.openai: FakeGraphGenerationClient([_validArgs]),
        },
        FakeApiKeyStore(keys: _bothKeys),
      );

      final session = await engine.generate('input de prueba');

      expect(session.graph.nodes, hasLength(2));
    });

    test('with a fallback standing by the primary gets only one quick retry',
        () async {
      final gemini = FakeGraphGenerationClient([_down]);
      final openai = FakeGraphGenerationClient([_validArgs]);
      final engine = _engine(
        {LlmProvider.gemini: gemini, LlmProvider.openai: openai},
        FakeApiKeyStore(keys: _bothKeys),
      );

      await engine.generate('input de prueba');

      expect(gemini.maxRetriesSeen, [1]);
      // The last provider has nowhere to hand off to, so it keeps the
      // client's own, larger default.
      expect(openai.maxRetriesSeen, [null]);
    });

    test('a lone provider keeps its full retry budget', () async {
      final gemini = FakeGraphGenerationClient([_validArgs]);
      final engine = _engine({LlmProvider.gemini: gemini}, FakeApiKeyStore(keys: _geminiKey));

      await engine.generate('input de prueba');

      expect(gemini.maxRetriesSeen, [null]);
    });

    test('when every provider fails the error names each of them', () async {
      final engine = _engine(
        {
          LlmProvider.gemini: FakeGraphGenerationClient([() => _down('Gemini está sobrecargado')]),
          LlmProvider.openai: FakeGraphGenerationClient([() => _down('OpenAI sin cuota')]),
        },
        FakeApiKeyStore(keys: _bothKeys),
      );

      await expectLater(
        engine.generate('input de prueba'),
        throwsA(isA<GenerationFailedException>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('GEMINI: Gemini está sobrecargado'),
            contains('OPENAI: OpenAI sin cuota'),
          ),
        )),
      );
    });

    test('with a single provider the error is just the reason, as before',
        () async {
      final engine = _engine(
        {LlmProvider.gemini: FakeGraphGenerationClient([() => _down('Gemini está sobrecargado')])},
        FakeApiKeyStore(keys: _geminiKey),
      );

      await expectLater(
        engine.generate('input de prueba'),
        throwsA(isA<GenerationFailedException>().having(
          (e) => e.message,
          'message',
          'Gemini está sobrecargado',
        )),
      );
    });

    test('no listener call when everything failed — there is no provider that '
        'served it', () async {
      var notices = 0;
      final engine = _engine(
        {
          LlmProvider.gemini: FakeGraphGenerationClient([_down]),
          LlmProvider.openai: FakeGraphGenerationClient([_down]),
        },
        FakeApiKeyStore(keys: _bothKeys),
        onFailover: (_) => notices++,
      );

      await expectLater(
          engine.generate('input de prueba'), throwsA(isA<GenerationFailedException>()));
      expect(notices, 0);
    });

    test('a provider with a key but no client counts as failed, not a crash',
        () async {
      final openai = FakeGraphGenerationClient([_validArgs]);
      final engine = _engine(
        {LlmProvider.openai: openai}, // no Gemini client registered
        FakeApiKeyStore(keys: _bothKeys),
      );

      final session = await engine.generate('input de prueba');

      expect(session.graph.nodes, hasLength(2));
    });

    test('the credential order is exactly what the store reports', () async {
      final store = FakeApiKeyStore(keys: _bothKeys, primary: LlmProvider.openai);
      final order = await store.credentialsInOrder();

      expect(order.map((c) => c.provider), [LlmProvider.openai, LlmProvider.gemini]);
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
    int? maxRetries,
  }) async {
    inputs.add(userInput);
    return _args();
  }
}
