// test/ui/arbol_genealogico_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/models/creative_graph.dart';
import 'package:creative/models/node.dart';
import 'package:creative/models/lineage_edge.dart';
import 'package:creative/models/turning_point.dart';
import 'package:creative/ui/graph/arbol_genealogico_view.dart';
import 'package:creative/ui/graph/node_icons.dart';

CreativeGraph _graph() => const CreativeGraph(
      nodes: [
        Node(
          id: 'f1',
          type: NodeType.fuente,
          label: 'Robert C. Martin',
          description: 'd',
          cluster: 'arquitectura-software',
          origin: NodeOrigin.usuario,
          level: 1,
        ),
        Node(
          id: 'f2',
          type: NodeType.fuente,
          label: 'Kent Beck',
          description: 'd',
          cluster: 'arquitectura-software',
          origin: NodeOrigin.sugerido,
          confidence: 0.5,
          level: 2,
          referenteOf: 'f1',
        ),
        Node(
          id: 'c1',
          type: NodeType.concepto,
          label: 'Cache manual',
          description: 'd',
          cluster: 'arquitectura-software',
          origin: NodeOrigin.usuario,
          icon: 'code',
        ),
      ],
      edges: [
        LineageEdge(id: 'e1', source: 'f1', target: 'c1', relation: LineageRelation.inspira),
      ],
      affinityEdges: [],
      turningPoints: [
        TurningPoint(
          nodeId: 'c1',
          evidence: 'convergencia real',
          convergence: true,
          directionChange: true,
        ),
      ],
      followupQuestions: [],
    );

void main() {
  testWidgets('renders the synthetic TU root and the referente tree', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: ArbolGenealogicoView(graph: _graph()),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('TÚ'), findsOneWidget);
    expect(find.text('Robert C. Martin'), findsOneWidget);
    expect(find.text('Kent Beck'), findsOneWidget);
    expect(find.text('Cache manual'), findsOneWidget);

    // Cache manual has a valid icon and should render it.
    expect(find.byIcon(nodeIconByName['code']!), findsOneWidget);
  });

  testWidgets('rejecting a sugerido node removes it from the tree', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: ArbolGenealogicoView(graph: _graph()),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Kent Beck'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    expect(find.text('Kent Beck'), findsNothing);
  });

  testWidgets('tapping the turning point badge shows its evidence', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: ArbolGenealogicoView(graph: _graph()),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.auto_awesome));
    await tester.pumpAndSettle();

    expect(find.text('convergencia real'), findsOneWidget);
  });

  testWidgets('renders TU root even with no visible level-1 referente', (tester) async {
    const graph = CreativeGraph(
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
        LineageEdge(id: 'e1', source: 's1', target: 'c1', relation: LineageRelation.desencadena),
      ],
      affinityEdges: [],
      turningPoints: [],
      followupQuestions: [],
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: ArbolGenealogicoView(graph: graph),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('TÚ'), findsOneWidget);
    expect(find.text('Charla de bases de datos'), findsOneWidget);
    expect(find.text('Cache manual'), findsOneWidget);
  });
}
