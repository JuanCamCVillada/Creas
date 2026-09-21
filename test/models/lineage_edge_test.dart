// test/models/lineage_edge_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/models/lineage_edge.dart';

void main() {
  group('LineageEdge', () {
    test('fromJson parses all four relation verbs', () {
      final cases = {
        'desencadena': LineageRelation.desencadena,
        'deriva_de': LineageRelation.derivaDe,
        'inspira': LineageRelation.inspira,
        'transforma_en': LineageRelation.transformaEn,
      };

      for (final entry in cases.entries) {
        final edge = LineageEdge.fromJson({
          'id': 'e1',
          'source': 's1',
          'target': 'c1',
          'relation': entry.key,
        });
        expect(edge.relation, entry.value, reason: entry.key);
      }
    });

    test('fromJson throws FormatException on unknown relation', () {
      expect(
        () => LineageEdge.fromJson({
          'id': 'e1',
          'source': 's1',
          'target': 'c1',
          'relation': 'bogus',
        }),
        throwsFormatException,
      );
    });

    test('toJson round-trips', () {
      const original = LineageEdge(
        id: 'e2',
        source: 'c1',
        target: 'c2',
        relation: LineageRelation.transformaEn,
      );
      final roundTripped = LineageEdge.fromJson(original.toJson());
      expect(roundTripped, original);
    });
  });
}
