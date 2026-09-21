import 'package:flutter_test/flutter_test.dart';
import 'package:creative/engine/graph_verifier.dart';
import 'package:creative/models/creative_graph.dart';
import 'package:creative/models/node.dart';
import 'package:creative/models/lineage_edge.dart';
import 'package:creative/models/turning_point.dart';

Node _fuente(String id, String cluster) => Node(
      id: id,
      type: NodeType.fuente,
      label: id,
      description: id,
      cluster: cluster,
      origin: NodeOrigin.usuario,
    );

Node _concepto(String id, String cluster) => Node(
      id: id,
      type: NodeType.concepto,
      label: id,
      description: id,
      cluster: cluster,
      origin: NodeOrigin.usuario,
    );

LineageEdge _edge(String id, String source, String target,
        [LineageRelation relation = LineageRelation.desencadena]) =>
    LineageEdge(id: id, source: source, target: target, relation: relation);

void main() {
  group('verifyGraph', () {
    test('throws CyclicGraphException when the lineage has a cycle', () {
      final graph = CreativeGraph(
        nodes: [_concepto('c1', 'a'), _concepto('c2', 'a')],
        edges: [
          _edge('e1', 'c1', 'c2', LineageRelation.derivaDe),
          _edge('e2', 'c2', 'c1', LineageRelation.derivaDe),
        ],
        affinityEdges: const [],
        turningPoints: const [],
        followupQuestions: const [],
      );

      expect(() => verifyGraph(graph), throwsA(isA<CyclicGraphException>()));
    });

    test('keeps a turning point candidate that converges and changes direction', () {
      final graph = CreativeGraph(
        nodes: [
          _fuente('s1', 'bases-de-datos'),
          _fuente('s2', 'musica'),
          _concepto('c1', 'arquitectura-software'),
          _concepto('c2', 'infraestructura-eventos'),
        ],
        edges: [
          _edge('e1', 's1', 'c1'),
          _edge('e2', 's2', 'c1'),
          _edge('e3', 'c1', 'c2', LineageRelation.transformaEn),
        ],
        affinityEdges: const [],
        turningPoints: [const TurningPoint(nodeId: 'c1', evidence: 'evidencia')],
        followupQuestions: const [],
      );

      final verified = verifyGraph(graph);

      expect(verified.turningPoints, hasLength(1));
      expect(verified.turningPoints.single.convergence, isTrue);
      expect(verified.turningPoints.single.directionChange, isTrue);
      expect(verified.turningPoints.single.isVerified, isTrue);
    });

    test('drops a candidate with only one incoming Fuente cluster (no convergence)', () {
      final graph = CreativeGraph(
        nodes: [
          _fuente('s1', 'bases-de-datos'),
          _concepto('c1', 'arquitectura-software'),
          _concepto('c2', 'infraestructura-eventos'),
        ],
        edges: [
          _edge('e1', 's1', 'c1'),
          _edge('e2', 'c1', 'c2', LineageRelation.transformaEn),
        ],
        affinityEdges: const [],
        turningPoints: [const TurningPoint(nodeId: 'c1', evidence: 'evidencia')],
        followupQuestions: const [],
      );

      final verified = verifyGraph(graph);
      expect(verified.turningPoints, isEmpty);
    });

    test('drops a candidate whose downstream cluster matches upstream (no direction change)', () {
      final graph = CreativeGraph(
        nodes: [
          _fuente('s1', 'bases-de-datos'),
          _fuente('s2', 'musica'),
          _concepto('c1', 'arquitectura-software'),
          _concepto('c2', 'arquitectura-software'),
        ],
        edges: [
          _edge('e1', 's1', 'c1'),
          _edge('e2', 's2', 'c1'),
          _edge('e3', 'c1', 'c2', LineageRelation.derivaDe),
        ],
        affinityEdges: const [],
        turningPoints: [const TurningPoint(nodeId: 'c1', evidence: 'evidencia')],
        followupQuestions: const [],
      );

      final verified = verifyGraph(graph);
      expect(verified.turningPoints, isEmpty);
    });
  });
}
