import 'package:flutter_test/flutter_test.dart';
import 'package:creative/ui/graph/canvas/cluster_layout.dart';

void main() {
  group('computeClusterOrbitLayout', () {
    test('returns an empty map for no nodes', () {
      final result = computeClusterOrbitLayout(nodeIds: [], clusterOf: {}, affinityEdges: []);
      expect(result.positions, isEmpty);
      expect(result.ringRadii, isEmpty);
    });

    test('positions every node id', () {
      final result = computeClusterOrbitLayout(
        nodeIds: ['a', 'b', 'c'],
        clusterOf: {'a': 'x', 'b': 'x', 'c': 'y'},
        affinityEdges: [('a', 'b', 0.8)],
      );
      expect(result.positions.keys.toSet(), {'a', 'b', 'c'});
    });

    test('is deterministic across runs with the same input', () {
      final nodeIds = ['a', 'b', 'c', 'd'];
      final clusterOf = {'a': 'x', 'b': 'x', 'c': 'y', 'd': 'y'};
      final edges = [('a', 'b', 0.9)];
      final first = computeClusterOrbitLayout(
          nodeIds: nodeIds, clusterOf: clusterOf, affinityEdges: edges);
      final second = computeClusterOrbitLayout(
          nodeIds: nodeIds, clusterOf: clusterOf, affinityEdges: edges);
      expect(first.positions, second.positions);
    });

    test('connected nodes in the same cluster share a column (same x)', () {
      final result = computeClusterOrbitLayout(
        nodeIds: ['a', 'b', 'c'],
        clusterOf: {'a': 'arquitectura', 'b': 'arquitectura', 'c': 'arte'},
        affinityEdges: [('a', 'b', 0.9), ('b', 'c', 0.5)],
      );
      expect(result.positions['a']!.dx, result.positions['b']!.dx);
    });

    test('connected nodes in the same cluster stack at different rows (distinct y)', () {
      final result = computeClusterOrbitLayout(
        nodeIds: ['a', 'b'],
        clusterOf: {'a': 'arquitectura', 'b': 'arquitectura'},
        affinityEdges: [('a', 'b', 0.9), ('a', 'c', 0.2)],
      );
      expect(result.positions['a']!.dy, isNot(result.positions['b']!.dy));
    });

    test('a node with no affinity edge at all orbits farther out than the '
        'connected mass', () {
      final result = computeClusterOrbitLayout(
        nodeIds: ['a', 'b', 'loose'],
        clusterOf: {'a': 'x', 'b': 'x', 'loose': 'y'},
        affinityEdges: [('a', 'b', 0.9)],
      );
      final positions = result.positions;
      final center = (positions['a']! + positions['b']!) / 2;
      final massRadius = [positions['a']!, positions['b']!]
          .map((o) => (o - center).distance)
          .reduce((v, e) => v > e ? v : e);
      final looseRadius = (positions['loose']! - center).distance;
      expect(looseRadius, greaterThan(massRadius));
    });

    test('many loose nodes spread across rings instead of overlapping', () {
      final ids = [for (var i = 0; i < 30; i++) 'loose-$i'];
      final result = computeClusterOrbitLayout(
        nodeIds: ids,
        clusterOf: {for (final id in ids) id: 'solo'},
        affinityEdges: [],
      );
      final positions = result.positions;
      var minDist = double.infinity;
      for (var i = 0; i < ids.length; i++) {
        for (var j = i + 1; j < ids.length; j++) {
          final d = (positions[ids[i]]! - positions[ids[j]]!).distance;
          if (d < minDist) minDist = d;
        }
      }
      expect(minDist, greaterThan(100));
      expect(result.ringRadii, isNotEmpty);
    });

    test('a small number of loose nodes on one ring spread evenly instead of '
        'bunching at one side', () {
      // Regression: angle used to be `2π·i / ringCapacity` (the ring's
      // *theoretical* capacity), so 2 loose nodes on an 8-capacity ring
      // landed at 0° and 45° — bunched together instead of spread across
      // the ring. It must divide by how many nodes are actually on that
      // ring.
      final result = computeClusterOrbitLayout(
        nodeIds: ['loose-a', 'loose-b'],
        clusterOf: {'loose-a': 'x', 'loose-b': 'y'},
        affinityEdges: [],
      );
      final positions = result.positions;
      final center = result.center;
      final a = positions['loose-a']! - center;
      final b = positions['loose-b']! - center;
      final angleBetween = (a.direction - b.direction).abs();
      final normalized = angleBetween > 3.14159265 ? 6.2831853 - angleBetween : angleBetween;
      // Two nodes sharing one ring should land roughly opposite each
      // other (~180°), not squeezed into a 45° wedge.
      expect(normalized, greaterThan(3.0));
    });

    test('loose nodes from the same cluster stay adjacent on the ring', () {
      // Regression: loose ids used to sort purely by id, discarding
      // cluster identity entirely, so two nodes from the same cluster
      // could land on opposite sides of the ring from each other.
      final ids = ['z-solo1', 'a-solo2', 'm-other1', 'b-other2'];
      final result = computeClusterOrbitLayout(
        nodeIds: ids,
        clusterOf: {
          'z-solo1': 'solo',
          'a-solo2': 'solo',
          'm-other1': 'other',
          'b-other2': 'other',
        },
        affinityEdges: [],
      );
      final positions = result.positions;
      final center = result.center;
      final byCluster = <String, List<double>>{
        'solo': [
          (positions['z-solo1']! - center).direction,
          (positions['a-solo2']! - center).direction,
        ],
        'other': [
          (positions['m-other1']! - center).direction,
          (positions['b-other2']! - center).direction,
        ],
      };
      for (final angles in byCluster.values) {
        final diff = (angles[0] - angles[1]).abs();
        final normalized = diff > 3.14159265 ? 6.2831853 - diff : diff;
        // Same-cluster nodes should be adjacent (small angle apart), not
        // spread arbitrarily across the ring by raw id sort order.
        expect(normalized, lessThan(2.0));
      }
    });

    test('rejects a non-positive spacing parameter', () {
      expect(
        () => computeClusterOrbitLayout(
          nodeIds: ['a'],
          clusterOf: {'a': 'x'},
          affinityEdges: [],
          orbitNodeSpacing: 0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
