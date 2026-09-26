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
