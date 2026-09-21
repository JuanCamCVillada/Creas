// test/ui/session_list_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/models/creative_graph.dart';
import 'package:creative/models/session.dart';
import 'package:creative/ui/sessions/session_list_screen.dart';

import '../helpers/fakes.dart';

GraphSession _session(String id) => GraphSession(
      id: id,
      rawInput: 'un devlog sobre $id',
      graph: const CreativeGraph(
        nodes: [],
        edges: [],
        affinityEdges: [],
        turningPoints: [],
        followupQuestions: [],
      ),
      createdAt: DateTime.utc(2026, 9, 21),
    );

void main() {
  testWidgets('shows an empty state with no sessions', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SessionListScreen(
        sessionStore: FakeSessionStore(),
        apiKeyStore: FakeApiKeyStore(),
        generator: FakeGraphGenerator(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Aún no tienes sesiones'), findsOneWidget);
  });

  testWidgets('lists existing sessions by their input snippet', (tester) async {
    final store = FakeSessionStore([_session('1'), _session('2')]);

    await tester.pumpWidget(MaterialApp(
      home: SessionListScreen(
        sessionStore: store,
        apiKeyStore: FakeApiKeyStore(),
        generator: FakeGraphGenerator(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('un devlog sobre 1'), findsOneWidget);
    expect(find.textContaining('un devlog sobre 2'), findsOneWidget);
  });
}
