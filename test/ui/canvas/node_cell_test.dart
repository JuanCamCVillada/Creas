import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/ui/graph/canvas/node_cell.dart';
import 'package:creative/ui/graph/canvas/node_shapes.dart';

void main() {
  Widget harness({
    required VoidCallback onTap,
    required VoidCallback onReject,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: GraphNodeCell(
          label: 'Nodo',
          cluster: 'cluster',
          code: 'F-01',
          shapeKind: NodeShapeKind.hexagon,
          fill: Colors.purple,
          icon: Icons.book,
          onTap: onTap,
          isSugerido: true,
          onAccept: () {},
          onReject: onReject,
        ),
      ),
    );
  }

  testWidgets('tapping the shape/label opens the detail (onTap fires)', (tester) async {
    var tapped = false;
    await tester.pumpWidget(harness(onTap: () => tapped = true, onReject: () {}));

    await tester.tap(find.text('Nodo'));
    expect(tapped, isTrue);
  });

  testWidgets(
      'tapping reject fires only onReject, not the detail-sheet onTap — '
      'regression: nesting the badge row inside the cell-wide GestureDetector '
      'let a single tap on reject also open the detail sheet', (tester) async {
    var tapped = false;
    var rejected = false;
    await tester.pumpWidget(harness(
      onTap: () => tapped = true,
      onReject: () => rejected = true,
    ));

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(rejected, isTrue);
    expect(tapped, isFalse);
  });
}
