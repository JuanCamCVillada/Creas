import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/ui/input/guided_input_flow.dart';
import 'package:creative/ui/theme/hud_widgets.dart';

void main() {
  Future<void> answer(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
  }

  testWidgets('SIGUIENTE stays disabled until the current question is answered',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: GuidedInputFlow(onComplete: (_) {}, loading: false)),
    ));

    final button = tester.widget<HudButton>(find.byType(HudButton));
    expect(button.onPressed, isNull);

    await answer(tester, 'Un bug de renderizado en el jardín digital.');

    final buttonAfter = tester.widget<HudButton>(find.byType(HudButton));
    expect(buttonAfter.onPressed, isNotNull);
  });

  testWidgets('ANTERIOR is hidden on the first question and appears afterwards',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: GuidedInputFlow(onComplete: (_) {}, loading: false)),
    ));

    expect(find.text('ANTERIOR'), findsNothing);

    await answer(tester, 'Un bug de renderizado.');
    await tester.tap(find.widgetWithText(HudButton, 'SIGUIENTE'));
    await tester.pump();

    expect(find.text('ANTERIOR'), findsOneWidget);
  });

  testWidgets(
      'walking all five questions calls onComplete with every labeled answer',
      (tester) async {
    String? combined;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GuidedInputFlow(onComplete: (text) => combined = text, loading: false),
      ),
    ));

    final answers = [
      'Un bug de renderizado en el jardín digital.',
      'Una charla sobre Bauhaus y un hilo de Twitter.',
      'Probé un grid fijo y quedó muy disperso.',
      'Vi que los nodos sueltos necesitaban su propio anillo.',
      'Terminé usando columnas por cluster más anillos de órbita.',
    ];

    for (final answer in answers) {
      await tester.enterText(find.byType(TextField), answer);
      await tester.pump();
      final isLast = answer == answers.last;
      await tester.tap(find.widgetWithText(HudButton, isLast ? 'GENERAR' : 'SIGUIENTE'));
      await tester.pump();
    }

    expect(combined, isNotNull);
    for (final answer in answers) {
      expect(combined, contains(answer));
    }
    // Each answer is still labeled with what it is...
    expect(combined, contains('PROBLEMA: ${answers.first}'));
    expect(combined, contains('RESOLUCIÓN: ${answers.last}'));
    // ...but with a short tag, not the full on-screen question, which would
    // be paid for as input tokens on every generation.
    expect(combined, isNot(contains('¿QUÉ PROBLEMA U OBJETIVO')));
    expect(combined, isNot(contains('¿CÓMO TERMINASTE')));
  });

  testWidgets('shows a determinate step progress bar, not the indeterminate sweep',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: GuidedInputFlow(onComplete: (_) {}, loading: false)),
    ));

    final bar = tester.widget<HudBlockProgress>(find.byType(HudBlockProgress));
    expect(bar.progress, isNotNull);
    expect(bar.progress, closeTo(1 / 5, 0.001));

    expect(find.text('PASO 1 DE 5'), findsOneWidget);
  });
}
