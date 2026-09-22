import 'package:flutter_test/flutter_test.dart';
import 'package:creative/engine/generation_engine.dart';
import 'package:creative/engine/graph_generator.dart';

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
      final apiKeyStore = FakeApiKeyStore('sk-ant-test');
      final client = FakeGraphGenerationClient([_validArgs]);
      final GraphGenerator engine =
          GenerationEngine(client: client, apiKeyStore: apiKeyStore);

      final session = await engine.generate('input de prueba');

      expect(session.rawInput, 'input de prueba');
      expect(session.graph.nodes, hasLength(2));
      expect(client.callCount, 1);
    });

    test('retries once after a malformed response, then succeeds', () async {
      final apiKeyStore = FakeApiKeyStore('sk-ant-test');
      final client = FakeGraphGenerationClient([
        () => {'nodes': 'not-a-list'},
        _validArgs,
      ]);
      final GraphGenerator engine =
          GenerationEngine(client: client, apiKeyStore: apiKeyStore);

      final session = await engine.generate('input de prueba');

      expect(session.graph.nodes, hasLength(2));
      expect(client.callCount, 2);
    });

    test('throws GenerationFailedException after two malformed responses', () async {
      final apiKeyStore = FakeApiKeyStore('sk-ant-test');
      final client = FakeGraphGenerationClient([
        () => {'nodes': 'not-a-list'},
        () => {'nodes': 'still-not-a-list'},
      ]);
      final GraphGenerator engine =
          GenerationEngine(client: client, apiKeyStore: apiKeyStore);

      expect(
        () => engine.generate('input de prueba'),
        throwsA(isA<GenerationFailedException>()),
      );
    });

    test('retries once after a cyclic lineage, then succeeds', () async {
      final apiKeyStore = FakeApiKeyStore('sk-ant-test');
      final client = FakeGraphGenerationClient([_cyclicArgs, _validArgs]);
      final GraphGenerator engine =
          GenerationEngine(client: client, apiKeyStore: apiKeyStore);

      final session = await engine.generate('input de prueba');

      // The cycle is rejected and retried once, same as a parse failure.
      expect(session.graph.nodes, hasLength(2));
      expect(client.callCount, 2);
    });

    test('throws GenerationFailedException when no API key is configured', () async {
      final apiKeyStore = FakeApiKeyStore();
      final client = FakeGraphGenerationClient([_validArgs]);
      final GraphGenerator engine =
          GenerationEngine(client: client, apiKeyStore: apiKeyStore);

      expect(
        () => engine.generate('input de prueba'),
        throwsA(isA<GenerationFailedException>()),
      );
      expect(client.callCount, 0);
    });
  });
}
