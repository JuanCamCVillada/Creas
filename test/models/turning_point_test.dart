// test/models/turning_point_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/models/turning_point.dart';

void main() {
  group('TurningPoint', () {
    test('fromCandidateJson parses node_id and evidence, unverified by default', () {
      final tp = TurningPoint.fromCandidateJson({
        'node_id': 'c3',
        'evidence': 'El bug de memoria y la charla de bases de datos convergieron aquí',
      });
      expect(tp.nodeId, 'c3');
      expect(tp.convergence, isFalse);
      expect(tp.directionChange, isFalse);
      expect(tp.isVerified, isFalse);
    });

    test('isVerified is true only when both flags are true', () {
      const tp = TurningPoint(
        nodeId: 'c3',
        evidence: 'e',
        convergence: true,
        directionChange: true,
      );
      expect(tp.isVerified, isTrue);
    });

    test('copyWith updates only the given flags', () {
      const tp = TurningPoint(nodeId: 'c3', evidence: 'e');
      final updated = tp.copyWith(convergence: true);
      expect(updated.convergence, isTrue);
      expect(updated.directionChange, isFalse);
      expect(updated.nodeId, 'c3');
    });

    test('toJson/fromJson round-trips including flags', () {
      const tp = TurningPoint(
        nodeId: 'c3',
        evidence: 'e',
        convergence: true,
        directionChange: true,
      );
      final roundTripped = TurningPoint.fromJson(tp.toJson());
      expect(roundTripped, tp);
    });
  });
}
