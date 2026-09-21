// test/ui/graph_view_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/models/affinity_edge.dart';
import 'package:creative/models/creative_graph.dart';
import 'package:creative/models/node.dart';
import 'package:creative/models/session.dart';
import 'package:creative/ui/graph/graph_view_screen.dart';

GraphSession _sessionWithNode() => GraphSession(
      id: '1',
      rawInput: 'input',
      graph: const CreativeGraph(
        nodes: [
          Node(
            id: 'c1',
            type: NodeType.concepto,
            label: 'Cache manual',
            description: 'd',
            cluster: 'arquitectura-software',
            origin: NodeOrigin.usuario,
          ),
        ],
        edges: [],
        affinityEdges: [],
        turningPoints: [],
        followupQuestions: [],
      ),
      createdAt: DateTime.utc(2026, 9, 21),
    );

GraphSession _thinSession() => GraphSession(
      id: '2',
      rawInput: 'input corto',
      graph: const CreativeGraph(
        nodes: [],
        edges: [],
        affinityEdges: [],
        turningPoints: [],
        followupQuestions: ['¿Quién te enseñó esto?'],
      ),
      createdAt: DateTime.utc(2026, 9, 21),
    );

void main() {
  testWidgets('switches between Jardin Digital and Arbol Genealogico tabs', (tester) async {
    await tester.pumpWidget(MaterialApp(home: GraphViewScreen(session: _sessionWithNode())));
    await tester.pumpAndSettle();

    expect(find.text('Jardín Digital'), findsWidgets);
    expect(find.text('Árbol Genealógico'), findsWidgets);

    expect(find.text('Cache manual'), findsOneWidget);

    await tester.tap(find.text('Árbol Genealógico'));
    await tester.pumpAndSettle();

    expect(find.text('Cache manual'), findsOneWidget);
  });

  testWidgets('shows followup questions when the graph is thin', (tester) async {
    await tester.pumpWidget(MaterialApp(home: GraphViewScreen(session: _thinSession())));
    await tester.pumpAndSettle();

    expect(find.textContaining('¿Quién te enseñó esto?'), findsOneWidget);
  });
}
