import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/ui/theme/hud_widgets.dart';

void main() {
  group('HudBlockProgress / HudSyncIndicator', () {
    testWidgets('never renders a CircularProgressIndicator — hud-tactico '
        'replaces spinners with a block sync bar', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: HudSyncIndicator())),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(HudBlockProgress), findsOneWidget);
      expect(find.textContaining('SINCRONIZANDO'), findsOneWidget);
    });

    testWidgets('animates the sweep over time without throwing', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: HudBlockProgress())),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));

      expect(tester.takeException(), isNull);
    });

    testWidgets('freezes at a static position under reduced motion instead '
        'of animating (hud-tactico §8 / WCAG 2.3.1)', (tester) async {
      final binding = tester.binding;
      binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(binding.platformDispatcher.clearAccessibilityFeaturesTestValue);

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: HudBlockProgress())),
      ));
      await tester.pump();
      final before = tester.widget<CustomPaint>(find.byType(CustomPaint).last);
      await tester.pump(const Duration(milliseconds: 700));
      final after = tester.widget<CustomPaint>(find.byType(CustomPaint).last);

      // Same painter instance/state each frame — nothing is animating.
      expect(before.painter.toString(), after.painter.toString());
    });
  });

  group('HudSegmentedTabs', () {
    testWidgets('three tabs do not overflow a 320px-wide phone', (tester) async {
      // 288px is what's left of a 320px screen after the 16px side padding.
      // In the test font the three labels are wider than that, which is the
      // case that used to overflow a Row.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 288,
              child: HudSegmentedTabs(
                labels: const ['AUTO', 'GEMINI', 'OPENAI'],
                selectedIndex: 0,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(find.text('OPENAI'), findsOneWidget);
    });

    testWidgets('tabs that fit stay on one line', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: HudSegmentedTabs(
              labels: const ['A', 'B'],
              selectedIndex: 0,
              onSelected: (_) {},
            ),
          ),
        ),
      ));

      final a = tester.getTopLeft(find.text('A')).dy;
      final b = tester.getTopLeft(find.text('B')).dy;
      expect(a, b);
    });

    testWidgets('works inside a Row next to other widgets, where its width is '
        'unbounded (the desktop dashboard header)', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              const Text('SESIÓN'),
              const SizedBox(width: 20),
              HudSegmentedTabs(
                labels: const ['01 JARDÍN', '02 LINAJE'],
                selectedIndex: 1,
                onSelected: (_) {},
              ),
              const Spacer(),
              const Text('CONECTAR'),
            ],
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a tab reports its index', (tester) async {
      int? tapped;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HudSegmentedTabs(
            labels: const ['AUTO', 'GEMINI', 'OPENAI'],
            selectedIndex: 0,
            onSelected: (i) => tapped = i,
          ),
        ),
      ));

      await tester.tap(find.text('GEMINI'));

      expect(tapped, 1);
    });
  });

  group('HudButton', () {
    testWidgets('a long label shrinks instead of overflowing a narrow button',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: HudButton(label: 'VALIDAR Y AGREGAR CLAVE', onPressed: () {}),
            ),
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
    });

    testWidgets('still sizes to its label when given unbounded width, as a '
        'floating action button is', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          floatingActionButton: HudButton(label: 'NUEVA OPERACIÓN', onPressed: () {}),
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(find.text('NUEVA OPERACIÓN'), findsOneWidget);
    });

    testWidgets('the label stays findable by its exact text', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: HudButton(label: 'GENERAR', onPressed: () {})),
      ));

      expect(find.widgetWithText(HudButton, 'GENERAR'), findsOneWidget);
    });
  });

  group('HudButton loading state', () {
    testWidgets('shows the block bar, not a spinner, while loading', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HudButton(label: 'GENERAR', onPressed: () {}, loading: true),
        ),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(HudBlockProgress), findsOneWidget);
    });
  });
}
