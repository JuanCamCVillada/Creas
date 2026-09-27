import 'package:flutter_test/flutter_test.dart';
import 'package:creative/models/node.dart';
import 'package:creative/ui/graph/graph_status.dart';
import 'package:creative/ui/theme/hud_tokens.dart';

Node _fuente(String id, {double? confidence}) => Node(
      id: id,
      type: NodeType.fuente,
      label: id,
      description: 'd',
      cluster: 'x',
      origin: NodeOrigin.usuario,
      confidence: confidence,
    );

void main() {
  group('lowConfidenceFuentes', () {
    test('only includes fuente nodes below the 0.5 threshold', () {
      final nodes = [
        _fuente('a', confidence: 0.3),
        _fuente('b', confidence: 0.8),
        _fuente('c'), // no confidence at all
        Node(
          id: 'd',
          type: NodeType.concepto,
          label: 'd',
          description: 'd',
          cluster: 'x',
          origin: NodeOrigin.usuario,
          confidence: 0.1, // concepto, should never count
        ),
      ];
      final result = lowConfidenceFuentes(nodes);
      expect(result.map((n) => n.id), ['a']);
    });
  });

  group('statusForLowConfidence', () {
    test('nominal when empty, precaución otherwise', () {
      expect(statusForLowConfidence([]), HudStatus.nominal);
      expect(statusForLowConfidence([_fuente('a', confidence: 0.2)]), HudStatus.precaucion);
    });
  });

  group('lowConfidenceBannerTitle', () {
    test('names the single fuente when there is only one', () {
      final title = lowConfidenceBannerTitle(
        [_fuente('a', confidence: 0.31)],
        {'a': 'F-01'},
      );
      expect(title, contains('F-01'));
      expect(title, contains('0.31'));
    });

    test('shows a count and every code when there are several — the '
        'previous version silently dropped all but the first', () {
      final title = lowConfidenceBannerTitle(
        [
          _fuente('a', confidence: 0.2),
          _fuente('b', confidence: 0.3),
          _fuente('c', confidence: 0.4),
        ],
        {'a': 'F-01', 'b': 'F-02', 'c': 'F-03'},
      );
      expect(title, contains('3'));
      expect(title, contains('F-01'));
      expect(title, contains('F-02'));
      expect(title, contains('F-03'));
    });
  });
}
