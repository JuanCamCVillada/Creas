import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/engine/graph_generator.dart';
import 'package:creative/models/creative_graph.dart';
import 'package:creative/models/session.dart';
import 'package:creative/ui/input/input_screen.dart';
import 'package:creative/ui/theme/hud_widgets.dart';

import '../helpers/fakes.dart';

void main() {
  testWidgets('generates a graph and pops with the new session', (tester) async {
    final sessionStore = FakeSessionStore();
    final generator = FakeGraphGenerator((rawInput) async => GraphSession(
          id: '1',
          rawInput: rawInput,
          graph: const CreativeGraph(
            nodes: [],
            edges: [],
            affinityEdges: [],
            turningPoints: [],
            followupQuestions: [],
          ),
          createdAt: DateTime.utc(2026, 9, 21),
        ));

    GraphSession? poppedSession;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            poppedSession = await Navigator.of(context).push<GraphSession>(
              MaterialPageRoute(
                builder: (_) => InputScreen(
                  generator: generator,
                  sessionStore: sessionStore,
                ),
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'hoy arreglé un bug');
    await tester.tap(find.widgetWithText(HudButton, 'GENERAR'));
    await tester.pumpAndSettle();

    expect(poppedSession?.rawInput, 'hoy arreglé un bug');
    expect(sessionStore.sessions, hasLength(1));
  });

  testWidgets('shows an error banner when generation fails', (tester) async {
    final sessionStore = FakeSessionStore();
    final generator = FakeGraphGenerator(
      (rawInput) async => throw const GenerationFailedException('sin clave de API'),
    );

    await tester.pumpWidget(MaterialApp(
      home: InputScreen(generator: generator, sessionStore: sessionStore),
    ));

    await tester.enterText(find.byType(TextField), 'algo');
    await tester.tap(find.widgetWithText(HudButton, 'GENERAR'));
    await tester.pumpAndSettle();

    expect(find.textContaining('sin clave de API'), findsOneWidget);
  });

  testWidgets('defaults to LIBRE and switches to the GUIADO wizard on demand',
      (tester) async {
    final sessionStore = FakeSessionStore();
    final generator = FakeGraphGenerator((rawInput) async => GraphSession(
          id: '1',
          rawInput: rawInput,
          graph: const CreativeGraph(
            nodes: [],
            edges: [],
            affinityEdges: [],
            turningPoints: [],
            followupQuestions: [],
          ),
          createdAt: DateTime.utc(2026, 9, 21),
        ));

    await tester.pumpWidget(MaterialApp(
      home: InputScreen(generator: generator, sessionStore: sessionStore),
    ));

    // LIBRE by default: the plain field is there, the wizard isn't.
    expect(find.text('ENTRADA:'), findsOneWidget);
    expect(find.textContaining('PASO 1 DE'), findsNothing);

    await tester.tap(find.text('GUIADO'));
    await tester.pump();

    expect(find.text('ENTRADA:'), findsNothing);
    expect(find.textContaining('PASO 1 DE'), findsOneWidget);
  });

  testWidgets('shows the prompt-quality disclaimer in both modes', (tester) async {
    final sessionStore = FakeSessionStore();
    final generator = FakeGraphGenerator((rawInput) async => GraphSession(
          id: '1',
          rawInput: rawInput,
          graph: const CreativeGraph(
            nodes: [],
            edges: [],
            affinityEdges: [],
            turningPoints: [],
            followupQuestions: [],
          ),
          createdAt: DateTime.utc(2026, 9, 21),
        ));

    await tester.pumpWidget(MaterialApp(
      home: InputScreen(generator: generator, sessionStore: sessionStore),
    ));

    expect(find.textContaining('la calidad del resultado depende'), findsOneWidget);

    await tester.tap(find.text('GUIADO'));
    await tester.pump();

    expect(find.textContaining('la calidad del resultado depende'), findsOneWidget);
  });
}
