import 'package:flutter_test/flutter_test.dart';
import 'package:creative/ui/graph/canvas/cluster_layout.dart';

void main() {
  group('computeClusterOrbitLayout', () {
    test('returns an empty map for no nodes', () {
      expect(
        computeClusterOrbitLayout(nodeIds: [], clusterOf: {}, affinityEdges: []),
        isEmpty,
      );
    });

    test('positions every node id', () {
      final result = computeClusterOrbitLayout(
        nodeIds: ['a', 'b', 'c'],
        clusterOf: {'a': 'x', 'b': 'x', 'c': 'y'},
        affinityEdges: [('a', 'b', 0.8)],
      );
      expect(result.keys.toSet(), {'a', 'b', 'c'});
    });

    test('is deterministic across runs with the same input', () {
      final nodeIds = ['a', 'b', 'c', 'd'];
      final clusterOf = {'a': 'x', 'b': 'x', 'c': 'y', 'd': 'y'};
      final edges = [('a', 'b', 0.9)];
      final first = computeClusterOrbitLayout(
          nodeIds: nodeIds, clusterOf: clusterOf, affinityEdges: edges);
      final second = computeClusterOrbitLayout(
          nodeIds: nodeIds, clusterOf: clusterOf, affinityEdges: edges);
      expect(first, second);
    });

    test('connected nodes in the same cluster share a column (same x)', () {
      final result = computeClusterOrbitLayout(
        nodeIds: ['a', 'b', 'c'],
        clusterOf: {'a': 'arquitectura', 'b': 'arquitectura', 'c': 'arte'},
        affinityEdges: [('a', 'b', 0.9), ('b', 'c', 0.5)],
      );
      expect(result['a']!.dx, result['b']!.dx);
    });

    test('connected nodes in the same cluster stack at different rows (distinct y)', () {
      final result = computeClusterOrbitLayout(
        nodeIds: ['a', 'b'],
        clusterOf: {'a': 'arquitectura', 'b': 'arquitectura'},
        affinityEdges: [('a', 'b', 0.9), ('a', 'c', 0.2)],
      );
      expect(result['a']!.dy, isNot(result['b']!.dy));
    });

    test('a node with no affinity edge at all orbits farther out than the '
        'connected mass', () {
      final result = computeClusterOrbitLayout(
        nodeIds: ['a', 'b', 'loose'],
        clusterOf: {'a': 'x', 'b': 'x', 'loose': 'y'},
        affinityEdges: [('a', 'b', 0.9)],
      );
      final center = (result['a']! + result['b']!) / 2;
      final massRadius = [result['a']!, result['b']!]
          .map((o) => (o - center).distance)
          .reduce((v, e) => v > e ? v : e);
      final looseRadius = (result['loose']! - center).distance;
      expect(looseRadius, greaterThan(massRadius));
    });

    test('many loose nodes spread across rings instead of overlapping', () {
      final ids = [for (var i = 0; i < 30; i++) 'loose-$i'];
      final result = computeClusterOrbitLayout(
        nodeIds: ids,
        clusterOf: {for (final id in ids) id: 'solo'},
        affinityEdges: [],
      );
      var minDist = double.infinity;
      for (var i = 0; i < ids.length; i++) {
        for (var j = i + 1; j < ids.length; j++) {
          final d = (result[ids[i]]! - result[ids[j]]!).distance;
          if (d < minDist) minDist = d;
        }
      }
      expect(minDist, greaterThan(100));
    });
  });
}
