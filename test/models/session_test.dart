// test/models/session_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/models/session.dart';
import 'package:creative/models/creative_graph.dart';

void main() {
  group('GraphSession', () {
    test('toJson/fromJson round-trips id, rawInput, graph and createdAt', () {
      final session = GraphSession(
        id: '123',
        rawInput: 'hoy arreglé un bug de memoria y pensé en el kingfisher',
        graph: const CreativeGraph(
          nodes: [],
          edges: [],
          affinityEdges: [],
          turningPoints: [],
          followupQuestions: [],
        ),
        createdAt: DateTime.utc(2026, 9, 21, 10, 30),
      );

      final roundTripped = GraphSession.fromJson(session.toJson());

      expect(roundTripped.id, '123');
      expect(roundTripped.rawInput, session.rawInput);
      expect(roundTripped.createdAt, session.createdAt);
      expect(roundTripped.graph.nodes, isEmpty);
    });
  });
}
