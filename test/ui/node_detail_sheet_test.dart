// test/ui/node_detail_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/models/node.dart';
import 'package:creative/ui/graph/node_detail_sheet.dart';

void main() {
  testWidgets('shows label, description, cluster and origin', (tester) async {
    const node = Node(
      id: 'c1',
      type: NodeType.concepto,
      label: 'Arquitectura hexagonal',
      description: 'Separar el dominio de la infraestructura',
      cluster: 'arquitectura-software',
      origin: NodeOrigin.usuario,
    );

    await tester.pumpWidget(const MaterialApp(
      home: NodeDetailSheet(node: node),
    ));

    expect(find.text('Arquitectura hexagonal'), findsOneWidget);
    expect(find.text('Separar el dominio de la infraestructura'), findsOneWidget);
    expect(find.textContaining('arquitectura-software'), findsOneWidget);
  });

  testWidgets('shows confidence for a suggested node', (tester) async {
    const node = Node(
      id: 's2',
      type: NodeType.fuente,
      label: 'Christopher Alexander',
      description: 'Patrones de diseño arquitectónico',
      cluster: 'arquitectura-software',
      origin: NodeOrigin.sugerido,
      confidence: 0.6,
      level: 2,
    );

    await tester.pumpWidget(const MaterialApp(
      home: NodeDetailSheet(node: node),
    ));

    expect(find.textContaining('sugerido'), findsOneWidget);
    expect(find.textContaining('60%'), findsOneWidget);
  });
}
