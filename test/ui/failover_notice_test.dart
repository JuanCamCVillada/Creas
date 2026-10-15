import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/engine/generation_engine.dart';
import 'package:creative/engine/llm_provider.dart';
import 'package:creative/ui/failover_notice.dart';

void main() {
  Future<GlobalKey<ScaffoldMessengerState>> pumpApp(WidgetTester tester) async {
    final key = GlobalKey<ScaffoldMessengerState>();
    await tester.pumpWidget(MaterialApp(
      scaffoldMessengerKey: key,
      home: const Scaffold(body: SizedBox.expand()),
    ));
    return key;
  }

  testWidgets('says which provider failed, why, and which one was used',
      (tester) async {
    final key = await pumpApp(tester);

    showFailoverNotice(
      key,
      const FailoverNotice(
        used: LlmProvider.openai,
        failed: [ProviderFailure(LlmProvider.gemini, 'Gemini está sobrecargado (503).')],
      ),
    );
    await tester.pump();

    expect(find.text('GEMINI NO RESPONDIÓ · SE USÓ OPENAI'), findsOneWidget);
    expect(find.text('Gemini está sobrecargado (503).'), findsOneWidget);
  });

  testWidgets('uses the plural when more than one provider failed first',
      (tester) async {
    final key = await pumpApp(tester);

    showFailoverNotice(
      key,
      const FailoverNotice(
        used: LlmProvider.gemini,
        failed: [
          ProviderFailure(LlmProvider.openai, 'sin cuota'),
          ProviderFailure(LlmProvider.gemini, 'x'),
        ],
      ),
    );
    await tester.pump();

    expect(find.textContaining('NO RESPONDIERON'), findsOneWidget);
  });

  testWidgets('is shown on whichever screen is current, even after the one '
      'that triggered it closes', (tester) async {
    final key = GlobalKey<ScaffoldMessengerState>();
    await tester.pumpWidget(MaterialApp(
      scaffoldMessengerKey: key,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('segunda pantalla')),
            )),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    showFailoverNotice(
      key,
      const FailoverNotice(
        used: LlmProvider.openai,
        failed: [ProviderFailure(LlmProvider.gemini, 'caído')],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('segunda pantalla'), findsOneWidget);
    expect(find.textContaining('SE USÓ OPENAI'), findsOneWidget);
  });

  testWidgets('does nothing, rather than crash, if the app has no messenger yet',
      (tester) async {
    final key = GlobalKey<ScaffoldMessengerState>(); // never attached

    expect(
      () => showFailoverNotice(
        key,
        const FailoverNotice(
          used: LlmProvider.openai,
          failed: [ProviderFailure(LlmProvider.gemini, 'caído')],
        ),
      ),
      returnsNormally,
    );
  });
}
