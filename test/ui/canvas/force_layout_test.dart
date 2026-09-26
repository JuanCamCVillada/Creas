import 'package:flutter_test/flutter_test.dart';
import 'package:creative/ui/graph/canvas/force_layout.dart';

void main() {
  group('computeForceLayout', () {
    test('returns an empty map for no nodes', () {
      expect(computeForceLayout(nodeIds: [], edges: []), isEmpty);
    });

    test('positions every node id, even with no edges', () {
      final result = computeForceLayout(nodeIds: ['a', 'b', 'c'], edges: []);
      expect(result.keys.toSet(), {'a', 'b', 'c'});
    });

    test('is deterministic across runs with the same input', () {
      final edges = [('a', 'b', 0.8), ('b', 'c', 0.2)];
      final first = computeForceLayout(nodeIds: ['a', 'b', 'c'], edges: edges);
      final second = computeForceLayout(nodeIds: ['a', 'b', 'c'], edges: edges);
      expect(first, second);
    });

    test('two nodes joined by a strong affinity end up closer than two unconnected nodes', () {
      // a-b strongly connected; c is isolated. After relaxing, a and b
      // should be nearer each other than either is to c.
      final result = computeForceLayout(
        nodeIds: ['a', 'b', 'c'],
        edges: [('a', 'b', 0.95)],
      );
      final distAB = (result['a']! - result['b']!).distance;
      final distAC = (result['a']! - result['c']!).distance;
      final distBC = (result['b']! - result['c']!).distance;
      expect(distAB, lessThan(distAC));
      expect(distAB, lessThan(distBC));
    });

    test('never leaves two distinct unconnected nodes exactly coincident', () {
      // Regression test: seeding initial positions from id.hashCode let two
      // ids whose hash collided (mod the seed grid) start at the exact same
      // point — repulsion between two coincident points has an undefined
      // direction, so they never separated and rendered stacked on top of
      // each other. A larger node set makes such a collision likely under
      // the old hash-based seeding; it must never survive layout regardless.
      final ids = [for (var i = 0; i < 40; i++) 'node-$i'];
      final result = computeForceLayout(nodeIds: ids, edges: []);

      for (var i = 0; i < ids.length; i++) {
        for (var j = i + 1; j < ids.length; j++) {
          final dist = (result[ids[i]]! - result[ids[j]]!).distance;
          expect(
            dist,
            greaterThan(1.0),
            reason: '${ids[i]} and ${ids[j]} ended up coincident (dist=$dist)',
          );
        }
      }
    });

    test('minSeparation keeps unconnected nodes at least that far apart', () {
      // A tiny width/height would otherwise derive an equilibrium spacing
      // (k) smaller than a node's own rendered footprint, so boxes would
      // visually overlap even though their centers aren't coincident.
      final result = computeForceLayout(
        nodeIds: ['a', 'b', 'c', 'd'],
        edges: [],
        width: 100,
        height: 100,
        minSeparation: 225,
      );
      final ids = result.keys.toList();
      for (var i = 0; i < ids.length; i++) {
        for (var j = i + 1; j < ids.length; j++) {
          final dist = (result[ids[i]]! - result[ids[j]]!).distance;
          expect(dist, greaterThan(150));
        }
      }
    });

    test('ignores edges referencing an id outside nodeIds', () {
      expect(
        () => computeForceLayout(
          nodeIds: ['a', 'b'],
          edges: [('a', 'ghost', 0.5)],
        ),
        returnsNormally,
      );
    });
  });
}
