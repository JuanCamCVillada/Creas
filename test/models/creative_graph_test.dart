import 'package:flutter_test/flutter_test.dart';
import 'package:creative/models/creative_graph.dart';
import 'package:creative/models/node.dart';
import 'package:creative/models/lineage_edge.dart';
import 'package:creative/models/affinity_edge.dart';
import 'package:creative/models/turning_point.dart';

CreativeGraph _sampleGraph() => const CreativeGraph(
      nodes: [
        Node(
          id: 's1',
          type: NodeType.fuente,
          label: 'Bug de memoria',
          description: 'Un leak en producción',
          cluster: 'infraestructura',
          origin: NodeOrigin.usuario,
        ),
        Node(
          id: 'c1',
          type: NodeType.concepto,
          label: 'Cache manual',
          description: 'Primer intento',
          cluster: 'arquitectura-software',
          origin: NodeOrigin.usuario,
        ),
      ],
      edges: [
        LineageEdge(
          id: 'e1',
          source: 's1',
          target: 'c1',
          relation: LineageRelation.desencadena,
        ),
      ],
      affinityEdges: [AffinityEdge(source: 's1', target: 'c1', weight: 0.5)],
      turningPoints: [TurningPoint(nodeId: 'c1', evidence: 'evidencia')],
      followupQuestions: ['¿Quién te enseñó esto?'],
    );

void main() {
  group('CreativeGraph', () {
    test('toJson/fromJson round-trips the whole graph', () {
      final graph = _sampleGraph();
      final roundTripped = CreativeGraph.fromJson(graph.toJson());

      expect(roundTripped.nodes, graph.nodes);
      expect(roundTripped.edges, graph.edges);
      expect(roundTripped.affinityEdges, graph.affinityEdges);
      expect(roundTripped.turningPoints, graph.turningPoints);
      expect(roundTripped.followupQuestions, graph.followupQuestions);
    });

    test('copyWith replaces only turningPoints', () {
      final graph = _sampleGraph();
      final updated = graph.copyWith(turningPoints: const []);

      expect(updated.turningPoints, isEmpty);
      expect(updated.nodes, graph.nodes);
      expect(updated.edges, graph.edges);
    });
  });
}
