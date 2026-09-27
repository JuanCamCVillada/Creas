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
