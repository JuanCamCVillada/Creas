// test/ui/jardin_digital_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/models/creative_graph.dart';
import 'package:creative/models/node.dart';
import 'package:creative/models/affinity_edge.dart';
import 'package:creative/ui/graph/jardin_digital_view.dart';
import 'package:creative/ui/graph/node_icons.dart';

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
          icon: 'music_note',
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

    // The one node with a valid icon shows it; nodes without one fall back
    // to the type default rather than showing nothing.
    expect(find.byIcon(nodeIconByName['music_note']!), findsOneWidget);
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

  testWidgets('rejecting a sugerido node removes it from the garden', (tester) async {
    final graph = CreativeGraph(
      nodes: [
        ..._graph().nodes,
        const Node(
          id: 's3',
          type: NodeType.fuente,
          label: 'Sugerencia dudosa',
          description: 'd',
          cluster: 'musica',
          origin: NodeOrigin.sugerido,
          confidence: 0.9,
        ),
      ],
      edges: const [],
      affinityEdges: _graph().affinityEdges,
      turningPoints: const [],
      followupQuestions: const [],
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 800, height: 600, child: JardinDigitalView(graph: graph)),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Sugerencia dudosa'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(find.text('Sugerencia dudosa'), findsNothing);
  });

  testWidgets('shows every affected fuente when several have low confidence',
      (tester) async {
    final graph = CreativeGraph(
      nodes: [
        const Node(
          id: 'f1',
          type: NodeType.fuente,
          label: 'Fuente uno',
          description: 'd',
          cluster: 'x',
          origin: NodeOrigin.usuario,
          confidence: 0.2,
        ),
        const Node(
          id: 'f2',
          type: NodeType.fuente,
          label: 'Fuente dos',
          description: 'd',
          cluster: 'x',
          origin: NodeOrigin.usuario,
          confidence: 0.3,
        ),
      ],
      edges: const [],
      affinityEdges: const [],
      turningPoints: const [],
      followupQuestions: const [],
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 800, height: 600, child: JardinDigitalView(graph: graph)),
      ),
    ));
    await tester.pumpAndSettle();

    // Both codes must appear — the old banner silently named only the
    // first low-confidence fuente.
    expect(find.textContaining('F-01'), findsWidgets);
    expect(find.textContaining('F-02'), findsWidgets);
  });
}
