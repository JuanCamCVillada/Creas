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

  testWidgets(
      'a long generation/cluster header label never overflows the fixed '
      'cell — regression: it had no maxLines/ellipsis, so a long cluster '
      'name or "PUNTO DE INFLEXIÓN"-style header wrapped to two lines and '
      'overflowed the cell by ~5px', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: kGraphNodeCellSize.width,
          height: kGraphNodeCellSize.height,
          child: GraphNodeCell(
            label: 'Patrón BLoC con manejo de estado reactivo y widgets desacoplados',
            cluster: 'arquitectura-de-software-avanzada',
            code: 'INF-01',
            shapeKind: NodeShapeKind.diamond,
            fill: Colors.blue,
            icon: Icons.bolt,
            onTap: () {},
            generationLabel: 'ARQUITECTURA-DE-SOFTWARE-AVANZADA',
            hasTurningPoint: true,
            onTurningPointTap: () {},
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
