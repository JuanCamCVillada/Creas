import 'package:flutter_test/flutter_test.dart';
import 'package:creative/engine/graph_parser.dart';

Map<String, dynamic> _validArgs() => {
      'nodes': [
        {
          'id': 's1',
          'type': 'fuente',
          'label': 'Charla de bases de datos',
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
      'affinity_edges': [
        {'source': 's1', 'target': 'c1', 'weight': 0.6},
      ],
      'turning_point_candidates': [
        {'node_id': 'c1', 'evidence': 'evidencia'},
      ],
      'followup_questions': <String>[],
    };

void main() {
  group('parseCreativeGraph', () {
    test('parses a valid, fully-linked response', () {
      final graph = parseCreativeGraph(_validArgs());

      expect(graph.nodes, hasLength(2));
      expect(graph.edges, hasLength(1));
      expect(graph.affinityEdges, hasLength(1));
      expect(graph.turningPoints, hasLength(1));
      expect(graph.turningPoints.single.isVerified, isFalse);
    });

    test('throws GraphParseException when nodes is missing', () {
      final args = _validArgs()..remove('nodes');
      expect(() => parseCreativeGraph(args), throwsA(isA<GraphParseException>()));
    });

    test('throws GraphParseException on a Fuente->Fuente lineage edge', () {
      final args = _validArgs();
      (args['nodes'] as List).add({
        'id': 's2',
        'type': 'fuente',
        'label': 'Otra fuente',
        'description': 'd',
        'cluster': 'musica',
        'origin': 'usuario',
      });
      (args['edges'] as List).add({
        'id': 'e2',
        'source': 's1',
        'target': 's2',
        'relation': 'inspira',
      });

      expect(() => parseCreativeGraph(args), throwsA(isA<GraphParseException>()));
    });

    test('throws GraphParseException when an edge references an unknown node id', () {
      final args = _validArgs();
      (args['edges'] as List).add({
        'id': 'e2',
        'source': 'nope',
        'target': 'c1',
        'relation': 'inspira',
      });

      expect(() => parseCreativeGraph(args), throwsA(isA<GraphParseException>()));
    });

    test('throws GraphParseException on a duplicate node id', () {
      final args = _validArgs();
      (args['nodes'] as List).add({
        'id': 's1',
        'type': 'fuente',
        'label': 'Duplicado',
        'description': 'd',
        'cluster': 'musica',
        'origin': 'usuario',
      });

      expect(() => parseCreativeGraph(args), throwsA(isA<GraphParseException>()));
    });

    test('throws GraphParseException when a turning point candidate targets a Fuente', () {
      final args = _validArgs();
      (args['turning_point_candidates'] as List).add({
        'node_id': 's1',
        'evidence': 'evidencia inválida',
      });

      expect(() => parseCreativeGraph(args), throwsA(isA<GraphParseException>()));
    });

    test('defaults followup_questions to an empty list when absent', () {
      final args = _validArgs()..remove('followup_questions');
      final graph = parseCreativeGraph(args);
      expect(graph.followupQuestions, isEmpty);
    });
  });
}
