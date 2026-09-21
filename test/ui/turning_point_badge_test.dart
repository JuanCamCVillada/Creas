// test/ui/turning_point_badge_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/ui/graph/turning_point_badge.dart';

void main() {
  testWidgets('calls onTap when pressed', (tester) async {
    var tapped = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TurningPointBadge(onTap: () => tapped = true),
      ),
    ));

    await tester.tap(find.byType(TurningPointBadge));
    expect(tapped, isTrue);
  });
}
