import 'dart:async';

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
  // Tall enough that the provider cards below the form are on screen.
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    home: ApiKeyScreen(apiKeyStore: store, validator: validator),
  ));
  await tester.pumpAndSettle();
}

Future<void> _enterKeyAndAdd(WidgetTester tester, String key) async {
  await tester.enterText(find.byType(TextField), key);
  await tester.tap(find.widgetWithText(HudButton, 'VALIDAR Y AGREGAR'));
  await tester.pumpAndSettle();
}

/// The AUTO / GEMINI / OPENAI tab, as opposed to the provider card of the
/// same name.
Finder _tab(String label) =>
    find.descendant(of: find.byType(HudSegmentedTabs), matching: find.text(label));

final _both = {
  LlmProvider.gemini: 'AIzaSyGeminiKey1234',
  LlmProvider.openai: 'sk-proj-openaiKey5678',
};

void main() {
  testWidgets('does not overflow on the narrowest common phone, with every '
      'section filled in', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final validator = FakeApiKeyValidator(const KeyCheckResult(
      KeyCheckStatus.invalid,
      'OPENAI rechazó la clave (401). Revisa que esté completa y sea de ese proveedor.',
    ));
    await tester.pumpWidget(MaterialApp(
      home: ApiKeyScreen(
        apiKeyStore: FakeApiKeyStore(keys: _both, primary: LlmProvider.openai),
        validator: validator,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'sk-wrong');
    await tester.ensureVisible(find.text('VALIDAR Y AGREGAR'));
    await tester.tap(find.text('VALIDAR Y AGREGAR'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  group('the provider list', () {
    testWidgets('shows every provider as having no key at first', (tester) async {
      await _pump(tester, store: FakeApiKeyStore(), validator: FakeApiKeyValidator(_valid()));

      expect(find.text('SIN CLAVE'), findsNWidgets(2));
      expect(find.textContaining('SIN CLAVES'), findsOneWidget);
    });

    testWidgets('shows a saved key masked, never in full', (tester) async {
      await _pump(
        tester,
        store: FakeApiKeyStore(keys: _both),
        validator: FakeApiKeyValidator(_valid()),
      );

      expect(find.text('····1234'), findsOneWidget);
      expect(find.text('····5678'), findsOneWidget);
      expect(find.textContaining('AIzaSyGeminiKey'), findsNothing);
      expect(find.textContaining('sk-proj-openaiKey'), findsNothing);
    });

    testWidgets('one key means no backup, and says what to do about it',
        (tester) async {
      await _pump(
        tester,
        store: FakeApiKeyStore(keys: {LlmProvider.gemini: 'AIzaSyGeminiKey1234'}),
        validator: FakeApiKeyValidator(_valid()),
      );

      expect(find.textContaining('SIN RESPALDO'), findsOneWidget);
      expect(find.textContaining('clave de OPENAI'), findsOneWidget);
    });

    testWidgets('two keys mean an active backup, in the order it will be used',
        (tester) async {
      await _pump(
        tester,
        store: FakeApiKeyStore(keys: _both),
        validator: FakeApiKeyValidator(_valid()),
      );

      expect(
        find.textContaining('RESPALDO ACTIVO · si GEMINI falla, se usa OPENAI'),
        findsOneWidget,
      );
    });
  });

  group('the primary provider', () {
    testWidgets('is Gemini by default when both are configured', (tester) async {
      await _pump(
        tester,
        store: FakeApiKeyStore(keys: _both),
        validator: FakeApiKeyValidator(_valid()),
      );

      expect(find.text('PRINCIPAL'), findsOneWidget);
      // Only the provider that isn't primary offers to become it.
      expect(find.text('HACER PRINCIPAL'), findsOneWidget);
    });

    testWidgets('can be switched, and the backup order follows', (tester) async {
      final store = FakeApiKeyStore(keys: _both);
      await _pump(tester, store: store, validator: FakeApiKeyValidator(_valid()));

      await tester.tap(find.text('HACER PRINCIPAL'));
      await tester.pumpAndSettle();

      expect(await store.getPrimary(), LlmProvider.openai);
      expect(
        find.textContaining('RESPALDO ACTIVO · si OPENAI falla, se usa GEMINI'),
        findsOneWidget,
      );
    });

    testWidgets('a lone provider has nothing to switch to', (tester) async {
      await _pump(
        tester,
        store: FakeApiKeyStore(keys: {LlmProvider.openai: 'sk-proj-openaiKey5678'}),
        validator: FakeApiKeyValidator(_valid()),
      );

      expect(find.text('PRINCIPAL'), findsOneWidget);
      expect(find.text('HACER PRINCIPAL'), findsNothing);
    });
  });

  group('removing a key', () {
    testWidgets('asks first, and keeps the key if cancelled', (tester) async {
      final store = FakeApiKeyStore(keys: _both);
      await _pump(tester, store: store, validator: FakeApiKeyValidator(_valid()));

      await tester.tap(find.text('QUITAR').first);
      await tester.pumpAndSettle();
      expect(find.text('QUITAR CLAVE DE GEMINI'), findsOneWidget);

      await tester.tap(find.text('CANCELAR'));
      await tester.pumpAndSettle();

      expect(await store.getKey(LlmProvider.gemini), isNotNull);
    });

    testWidgets('removes only that provider\'s key once confirmed', (tester) async {
      final store = FakeApiKeyStore(keys: _both);
      await _pump(tester, store: store, validator: FakeApiKeyValidator(_valid()));

      await tester.tap(find.text('QUITAR').first); // Gemini's card
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('QUITAR'),
      ));
      await tester.pumpAndSettle();

      expect(await store.getKey(LlmProvider.gemini), isNull);
      expect(await store.getKey(LlmProvider.openai), isNotNull);
      expect(find.text('SIN CLAVE'), findsOneWidget);
      expect(find.textContaining('SIN RESPALDO'), findsOneWidget);
    });
  });

  group('the provider readout follows what is typed in AUTO', () {
    Future<void> typeKey(WidgetTester tester, String key) async {
      await _pump(tester, store: FakeApiKeyStore(), validator: FakeApiKeyValidator(_valid()));
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
      await _pump(tester, store: FakeApiKeyStore(), validator: FakeApiKeyValidator(_valid()));
      expect(find.text('—'), findsOneWidget);
    });
  });

  group('adding a key', () {
    testWidgets('a verified key goes into its own provider\'s slot and the '
        'field is cleared', (tester) async {
      final store = FakeApiKeyStore(keys: {LlmProvider.gemini: 'AIzaSyGeminiKey1234'});
      final validator = FakeApiKeyValidator(_valid(LlmProvider.openai));
      await _pump(tester, store: store, validator: validator);

      await _enterKeyAndAdd(tester, 'sk-proj-newOpenAi9999');

      expect(await store.getKey(LlmProvider.openai), 'sk-proj-newOpenAi9999');
      // The existing Gemini key is untouched — that is the point of having
      // a slot per provider.
      expect(await store.getKey(LlmProvider.gemini), 'AIzaSyGeminiKey1234');
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
      expect(find.textContaining('CLAVE DE OPENAI GUARDADA'), findsOneWidget);
      expect(find.text('····9999'), findsOneWidget);
      // Adding the second key is what turns the backup on.
      expect(find.textContaining('RESPALDO ACTIVO'), findsOneWidget);
    });

    testWidgets('a manually chosen provider is validated against and used',
        (tester) async {
      final store = FakeApiKeyStore();
      final validator = FakeApiKeyValidator(_valid(LlmProvider.openai));
      await _pump(tester, store: store, validator: validator);

      await tester.tap(_tab('OPENAI'));
      await tester.pump();
      await _enterKeyAndAdd(tester, 'custom-format-key');

      expect(validator.lastProvider, LlmProvider.openai);
      expect(await store.getKey(LlmProvider.openai), 'custom-format-key');
      expect(await store.getKey(LlmProvider.gemini), isNull);
    });

    testWidgets('AUTO sends no provider to the validator, so it detects',
        (tester) async {
      final validator = FakeApiKeyValidator(_valid(LlmProvider.gemini));
      await _pump(tester, store: FakeApiKeyStore(), validator: validator);

      await _enterKeyAndAdd(tester, 'AIzaSyExample');

      expect(validator.lastProvider, isNull);
    });

    testWidgets('the key is trimmed before it is saved', (tester) async {
      final store = FakeApiKeyStore();
      await _pump(tester, store: store, validator: FakeApiKeyValidator(_valid(LlmProvider.gemini)));

      await _enterKeyAndAdd(tester, '  AIzaSyExample \n');

      expect(await store.getKey(LlmProvider.gemini), 'AIzaSyExample');
    });

    testWidgets('adding a second key for the same provider replaces the first',
        (tester) async {
      final store = FakeApiKeyStore(keys: {LlmProvider.gemini: 'AIzaSyOldOldOld1111'});
      await _pump(tester, store: store, validator: FakeApiKeyValidator(_valid(LlmProvider.gemini)));

      await _enterKeyAndAdd(tester, 'AIzaSyNewNewNew2222');

      expect(await store.getKey(LlmProvider.gemini), 'AIzaSyNewNewNew2222');
      expect(find.text('····2222'), findsOneWidget);
      expect(find.text('····1111'), findsNothing);
    });

    testWidgets('a rejected key shows why and is NOT saved', (tester) async {
      final store = FakeApiKeyStore(keys: {LlmProvider.gemini: 'AIzaKeepMe0000'});
      final validator = FakeApiKeyValidator(const KeyCheckResult(
        KeyCheckStatus.invalid,
        'OPENAI rechazó la clave (401).',
        provider: LlmProvider.openai,
      ));
      await _pump(tester, store: store, validator: validator);

      await _enterKeyAndAdd(tester, 'sk-wrong');

      expect(find.text('CLAVE NO ACEPTADA'), findsOneWidget);
      expect(find.textContaining('rechazó la clave'), findsOneWidget);
      expect(await store.getKey(LlmProvider.openai), isNull);
      expect(await store.getKey(LlmProvider.gemini), 'AIzaKeepMe0000');
      expect(find.text('GUARDAR IGUAL'), findsNothing);
    });

    testWidgets('an unsupported key is refused, not saved', (tester) async {
      final store = FakeApiKeyStore();
      final validator = FakeApiKeyValidator(const KeyCheckResult(
        KeyCheckStatus.unsupported,
        'Las claves de Anthropic (sk-ant-…) no están soportadas.',
      ));
      await _pump(tester, store: store, validator: validator);

      await _enterKeyAndAdd(tester, 'sk-ant-api03-abc');

      expect(find.textContaining('Anthropic'), findsWidgets);
      for (final provider in LlmProvider.values) {
        expect(await store.getKey(provider), isNull);
      }
    });

    testWidgets(
        'an unreachable provider warns but lets the user save anyway — the '
        'key is not known to be wrong', (tester) async {
      final store = FakeApiKeyStore();
      final validator = FakeApiKeyValidator(const KeyCheckResult(
        KeyCheckStatus.unverified,
        'No pude conectar con GEMINI para verificar la clave.',
        provider: LlmProvider.gemini,
      ));
      await _pump(tester, store: store, validator: validator);

      await _enterKeyAndAdd(tester, 'AIzaSyExample');

      expect(find.text('NO SE PUDO VERIFICAR'), findsOneWidget);
      expect(await store.getKey(LlmProvider.gemini), isNull); // nothing saved yet

      await tester.tap(find.text('GUARDAR IGUAL'));
      await tester.pumpAndSettle();

      expect(await store.getKey(LlmProvider.gemini), 'AIzaSyExample');
    });

    testWidgets('editing the key clears a previous rejection', (tester) async {
      final validator = FakeApiKeyValidator(const KeyCheckResult(
        KeyCheckStatus.invalid,
        'rechazada',
      ));
      await _pump(tester, store: FakeApiKeyStore(), validator: validator);

      await _enterKeyAndAdd(tester, 'sk-wrong');
      expect(find.text('CLAVE NO ACEPTADA'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'sk-wrong2');
      await tester.pump();

      expect(find.text('CLAVE NO ACEPTADA'), findsNothing);
    });

    testWidgets('shows a progress bar, not the button, while verifying',
        (tester) async {
      final gate = Completer<void>();
      final validator = FakeApiKeyValidator(_valid(LlmProvider.gemini))..gate = gate;
      await _pump(tester, store: FakeApiKeyStore(), validator: validator);

      await tester.enterText(find.byType(TextField), 'AIzaSyExample');
      await tester.tap(find.widgetWithText(HudButton, 'VALIDAR Y AGREGAR'));
      await tester.pump(); // verification started and is still pending

      expect(find.byType(HudBlockProgress), findsOneWidget);
      expect(find.widgetWithText(HudButton, 'VALIDAR Y AGREGAR'), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byType(HudBlockProgress), findsNothing);
      expect(find.widgetWithText(HudButton, 'VALIDAR Y AGREGAR'), findsOneWidget);
    });
  });
}
