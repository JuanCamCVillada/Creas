import 'package:flutter_test/flutter_test.dart';
import 'package:creative/ui/graph/canvas/lineage_layout.dart';

void main() {
  group('computeGenerations', () {
    test('a node with no incoming edges is generation 0', () {
      final result = computeGenerations(nodeIds: ['a'], edges: []);
      expect(result['a'], 0);
    });

    test('a simple chain increases generation by one per edge', () {
      final result = computeGenerations(
        nodeIds: ['a', 'b', 'c'],
        edges: [('a', 'b'), ('b', 'c')],
      );
      expect(result['a'], 0);
      expect(result['b'], 1);
      expect(result['c'], 2);
    });

    test('a node fed by two sources takes the longest incoming path', () {
      // a -> c, a -> b -> c: c must be generation 2 (via b), not 1 (via a).
      final result = computeGenerations(
        nodeIds: ['a', 'b', 'c'],
        edges: [('a', 'c'), ('a', 'b'), ('b', 'c')],
      );
      expect(result['a'], 0);
      expect(result['b'], 1);
      expect(result['c'], 2);
    });

    test('ignores edges referencing an id outside nodeIds', () {
      final result = computeGenerations(
        nodeIds: ['a', 'b'],
        edges: [('a', 'b'), ('ghost', 'b'), ('a', 'ghost')],
      );
      expect(result['a'], 0);
      expect(result['b'], 1);
    });

    test('disconnected nodes all default to generation 0', () {
      final result = computeGenerations(nodeIds: ['a', 'b', 'c'], edges: []);
      expect(result, {'a': 0, 'b': 0, 'c': 0});
    });
  });
}
