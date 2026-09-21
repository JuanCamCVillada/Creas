// test/models/affinity_edge_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/models/affinity_edge.dart';

void main() {
  group('AffinityEdge', () {
    test('fromJson parses source, target and weight', () {
      final edge = AffinityEdge.fromJson({
        'source': 'a',
        'target': 'b',
        'weight': 0.8,
      });
      expect(edge.source, 'a');
      expect(edge.target, 'b');
      expect(edge.weight, 0.8);
    });

    test('toJson round-trips', () {
      const original = AffinityEdge(source: 'x', target: 'y', weight: 0.3);
      final roundTripped = AffinityEdge.fromJson(original.toJson());
      expect(roundTripped, original);
    });
  });
}
