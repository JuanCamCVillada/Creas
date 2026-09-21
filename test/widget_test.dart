import 'package:flutter_test/flutter_test.dart';
import 'package:creative/app.dart';

import 'helpers/fakes.dart';

void main() {
  testWidgets('CreativeApp renders its home screen', (tester) async {
    await tester.pumpWidget(CreativeApp(
      sessionStore: FakeSessionStore(),
      apiKeyStore: FakeApiKeyStore(),
      generator: FakeGraphGenerator(),
    ));

    expect(find.text('Genealogía Creativa'), findsWidgets);
  });
}
