import 'package:flutter_test/flutter_test.dart';
import 'package:creative/app.dart';

import 'helpers/fakes.dart';

void main() {
  testWidgets('CreativeApp shows the session list as its home screen', (tester) async {
    await tester.pumpWidget(CreativeApp(
      sessionStore: FakeSessionStore(),
      apiKeyStore: FakeApiKeyStore(),
      generator: FakeGraphGenerator(),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Aún no tienes sesiones'), findsOneWidget);
  });
}
