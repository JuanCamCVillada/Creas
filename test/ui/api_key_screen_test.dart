import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/engine/api_key_validator.dart';
import 'package:creative/engine/llm_provider.dart';
import 'package:creative/ui/settings/api_key_screen.dart';
import 'package:creative/ui/theme/hud_widgets.dart';

import '../helpers/fakes.dart';

KeyCheckResult _valid([LlmProvider? provider]) =>
    KeyCheckResult(KeyCheckStatus.valid, 'ok', provider: provider);

Future<void> _pump(
  WidgetTester tester, {
  required FakeApiKeyStore store,
  required FakeApiKeyValidator validator,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: ApiKeyScreen(apiKeyStore: store, validator: validator),
  ));
  await tester.pumpAndSettle();
}

Future<void> _enterKeyAndSave(WidgetTester tester, String key) async {
  await tester.enterText(find.byType(TextField), key);
  await tester.tap(find.widgetWithText(HudButton, 'VALIDAR Y GUARDAR'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('prefills the saved key and the provider that was pinned',
      (tester) async {
    final store = FakeApiKeyStore('AIzaOld', LlmProvider.gemini);
    await _pump(tester, store: store, validator: FakeApiKeyValidator(_valid()));

    expect(find.text('AIzaOld'), findsOneWidget);
    expect(find.text('GEMINI · MANUAL'), findsOneWidget);
  });

  group('the provider readout follows what is typed in AUTO', () {
    Future<void> typeKey(WidgetTester tester, String key) async {
      await _pump(tester,
          store: FakeApiKeyStore(), validator: FakeApiKeyValidator(_valid()));
      await tester.enterText(find.byType(TextField), key);
      await tester.pump();
    }

    testWidgets('an OpenAI key', (tester) async {
      await typeKey(tester, 'sk-proj-abc');
      expect(find.text('OPENAI · AUTO'), findsOneWidget);
    });

    testWidgets('a Gemini key', (tester) async {
      await typeKey(tester, 'AIzaSyExample');
      expect(find.text('GEMINI · AUTO'), findsOneWidget);
    });

    testWidgets('an Anthropic key is called out as unsupported', (tester) async {
      await typeKey(tester, 'sk-ant-api03-abc');
      expect(find.text('ANTHROPIC · NO SOPORTADO'), findsOneWidget);
    });

    testWidgets('an unfamiliar key asks the user to pick', (tester) async {
      await typeKey(tester, 'mystery');
      expect(find.text('NO RECONOCIDO · ELIGE UNO'), findsOneWidget);
    });

    testWidgets('nothing typed shows a dash', (tester) async {
      await _pump(tester,
          store: FakeApiKeyStore(), validator: FakeApiKeyValidator(_valid()));
      expect(find.text('—'), findsOneWidget);
    });
  });

  testWidgets('a verified key is saved, with AUTO stored as no provider',
      (tester) async {
    final store = FakeApiKeyStore(null, LlmProvider.gemini); // stale manual pick
    final validator = FakeApiKeyValidator(_valid(LlmProvider.openai));
    await _pump(tester, store: store, validator: validator);

    // Back to AUTO, then save an OpenAI key.
    await tester.tap(find.text('AUTO'));
    await tester.pump();
    await _enterKeyAndSave(tester, 'sk-proj-new');

    expect(await store.getApiKey(), 'sk-proj-new');
    expect(await store.getProvider(), isNull);
    expect(validator.lastProvider, isNull);
  });

  testWidgets('a manually chosen provider is validated against and saved',
      (tester) async {
    final store = FakeApiKeyStore();
    final validator = FakeApiKeyValidator(_valid(LlmProvider.openai));
    await _pump(tester, store: store, validator: validator);

    await tester.tap(find.text('OPENAI'));
    await tester.pump();
    await _enterKeyAndSave(tester, 'custom-format-key');

    expect(validator.lastProvider, LlmProvider.openai);
    expect(await store.getApiKey(), 'custom-format-key');
    expect(await store.getProvider(), LlmProvider.openai);
  });

  testWidgets('the key is trimmed before it is saved', (tester) async {
    final store = FakeApiKeyStore();
    await _pump(tester, store: store, validator: FakeApiKeyValidator(_valid()));

    await _enterKeyAndSave(tester, '  AIzaSyExample \n');

    expect(await store.getApiKey(), 'AIzaSyExample');
  });

  testWidgets('a rejected key shows why and is NOT saved', (tester) async {
    final store = FakeApiKeyStore('AIzaKeepMe');
    final validator = FakeApiKeyValidator(const KeyCheckResult(
      KeyCheckStatus.invalid,
      'OPENAI rechazó la clave (401).',
      provider: LlmProvider.openai,
    ));
    await _pump(tester, store: store, validator: validator);

    await _enterKeyAndSave(tester, 'sk-wrong');

    expect(find.text('CLAVE NO ACEPTADA'), findsOneWidget);
    expect(find.textContaining('rechazó la clave'), findsOneWidget);
    // The previously saved key survives a failed attempt.
    expect(await store.getApiKey(), 'AIzaKeepMe');
    expect(find.text('GUARDAR IGUAL'), findsNothing);
  });

  testWidgets('an unsupported key is refused, not saved', (tester) async {
    final store = FakeApiKeyStore();
    final validator = FakeApiKeyValidator(const KeyCheckResult(
      KeyCheckStatus.unsupported,
      'Las claves de Anthropic (sk-ant-…) no están soportadas.',
    ));
    await _pump(tester, store: store, validator: validator);

    await _enterKeyAndSave(tester, 'sk-ant-api03-abc');

    expect(find.textContaining('Anthropic'), findsWidgets);
    expect(await store.getApiKey(), isNull);
  });

  testWidgets(
      'an unreachable provider warns but lets the user save anyway — the key '
      'is not known to be wrong', (tester) async {
    final store = FakeApiKeyStore();
    final validator = FakeApiKeyValidator(const KeyCheckResult(
      KeyCheckStatus.unverified,
      'No pude conectar con GEMINI para verificar la clave.',
      provider: LlmProvider.gemini,
    ));
    await _pump(tester, store: store, validator: validator);

    await _enterKeyAndSave(tester, 'AIzaSyExample');

    expect(find.text('NO SE PUDO VERIFICAR'), findsOneWidget);
    expect(await store.getApiKey(), isNull); // nothing saved yet

    await tester.tap(find.text('GUARDAR IGUAL'));
    await tester.pumpAndSettle();

    expect(await store.getApiKey(), 'AIzaSyExample');
  });

  testWidgets('editing the key clears a previous rejection', (tester) async {
    final validator = FakeApiKeyValidator(const KeyCheckResult(
      KeyCheckStatus.invalid,
      'rechazada',
    ));
    await _pump(tester, store: FakeApiKeyStore(), validator: validator);

    await _enterKeyAndSave(tester, 'sk-wrong');
    expect(find.text('CLAVE NO ACEPTADA'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'sk-wrong2');
    await tester.pump();

    expect(find.text('CLAVE NO ACEPTADA'), findsNothing);
  });

  testWidgets('shows a progress bar, not the button, while verifying',
      (tester) async {
    final validator = FakeApiKeyValidator(_valid());
    await _pump(tester, store: FakeApiKeyStore(), validator: validator);

    await tester.enterText(find.byType(TextField), 'AIzaSyExample');
    await tester.tap(find.widgetWithText(HudButton, 'VALIDAR Y GUARDAR'));
    await tester.pump(); // validation started, not yet resolved

    expect(find.byType(HudBlockProgress), findsOneWidget);
    expect(find.widgetWithText(HudButton, 'VALIDAR Y GUARDAR'), findsNothing);

    await tester.pumpAndSettle();
  });
}
