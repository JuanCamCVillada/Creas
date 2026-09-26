// test/ui/graph_view_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/models/creative_graph.dart';
import 'package:creative/models/lineage_edge.dart';
import 'package:creative/models/node.dart';
import 'package:creative/models/session.dart';
import 'package:creative/ui/graph/graph_view_screen.dart';

GraphSession _sessionWithNode() => GraphSession(
      id: '1',
      rawInput: 'input',
      graph: const CreativeGraph(
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
        ],
        edges: [
          LineageEdge(
            id: 'e1',
            source: 's1',
            target: 'c1',
            relation: LineageRelation.desencadena,
          ),
        ],
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

    expect(find.text('01 JARDÍN'), findsWidgets);
    expect(find.text('02 LINAJE'), findsWidgets);

    expect(find.text('Cache manual'), findsOneWidget);

    await tester.tap(find.text('02 LINAJE'));
    await tester.pumpAndSettle();

    expect(find.text('Cache manual'), findsOneWidget);
  });

  testWidgets('shows followup questions when the graph is thin', (tester) async {
    await tester.pumpWidget(MaterialApp(home: GraphViewScreen(session: _thinSession())));
    await tester.pumpAndSettle();

    expect(find.textContaining('¿Quién te enseñó esto?'), findsOneWidget);
  });

  group('wide (desktop/web) layout', () {
    Future<void> pumpWide(WidgetTester tester, GraphSession session) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(home: GraphViewScreen(session: session)));
      await tester.pumpAndSettle();
    }

    testWidgets('renders the persistent 3-column dashboard with real stats', (tester) async {
      await pumpWide(tester, _sessionWithNode());

      // Left stats panel: real counts from the graph, not placeholders.
      expect(find.text('NODOS'), findsOneWidget);
      expect(find.text('ARISTAS'), findsOneWidget);
      expect(find.text('2'), findsWidgets); // NODOS = 2
      expect(find.text('1'), findsWidgets); // ARISTAS / GENERACIONES = 1

      // Right panel starts empty until a node is selected.
      expect(find.text('SELECCIONA UN NODO'), findsOneWidget);
    });

    testWidgets('tapping a node fills the right panel instead of opening a modal',
        (tester) async {
      await pumpWide(tester, _sessionWithNode());

      await tester.tap(find.text('Cache manual').first);
      await tester.pumpAndSettle();

      expect(find.text('SELECCIONA UN NODO'), findsNothing);
      expect(find.textContaining('CONCEPTO'), findsWidgets);
    });
  });
}
