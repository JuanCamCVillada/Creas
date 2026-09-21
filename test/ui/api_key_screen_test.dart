import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/ui/settings/api_key_screen.dart';

import '../helpers/fakes.dart';

void main() {
  testWidgets('prefills the existing key and saves a new one', (tester) async {
    final store = FakeApiKeyStore('sk-ant-old');

    await tester.pumpWidget(MaterialApp(
      home: ApiKeyScreen(apiKeyStore: store),
    ));
    await tester.pumpAndSettle();

    expect(find.text('sk-ant-old'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'sk-ant-new');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(await store.getApiKey(), 'sk-ant-new');
  });
}
