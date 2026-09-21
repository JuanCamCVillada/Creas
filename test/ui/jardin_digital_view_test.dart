// test/ui/jardin_digital_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/models/creative_graph.dart';
import 'package:creative/models/node.dart';
import 'package:creative/models/affinity_edge.dart';
import 'package:creative/ui/graph/jardin_digital_view.dart';

CreativeGraph _graph() => const CreativeGraph(
      nodes: [
        Node(
          id: 's1',
          type: NodeType.fuente,
          label: 'Charla de bases de datos',
          description: 'd',
          cluster: 'bases-de-datos',
          origin: NodeOrigin.usuario,
        ),
        Node(
          id: 'c1',
          type: NodeType.concepto,
          label: 'Cache manual',
          description: 'd',
          cluster: 'arquitectura-software',
          origin: NodeOrigin.usuario,
        ),
        Node(
          id: 's2',
          type: NodeType.fuente,
          label: 'Fragmento suelto',
          description: 'd',
          cluster: 'musica',
          origin: NodeOrigin.usuario,
        ),
      ],
      edges: [],
      affinityEdges: [AffinityEdge(source: 's1', target: 'c1', weight: 0.5)],
      turningPoints: [],
      followupQuestions: [],
    );

void main() {
  testWidgets('renders every node label, including loose fragments', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: JardinDigitalView(graph: _graph()),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Charla de bases de datos'), findsOneWidget);
    expect(find.text('Cache manual'), findsOneWidget);
    expect(find.text('Fragmento suelto'), findsOneWidget);
  });

  testWidgets('tapping a node opens its detail sheet', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: JardinDigitalView(graph: _graph()),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cache manual'));
    await tester.pumpAndSettle();

    expect(find.text('d'), findsWidgets);
  });
}
