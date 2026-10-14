import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/ui/onboarding/pin_screen.dart';

void main() {
  testWidgets('submitting 4-digit pin calls onUnlocked with 32-byte key', (tester) async {
    List<int>? got;
    await tester.pumpWidget(MaterialApp(
      home: PinScreen(onUnlocked: (k) async => got = k),
    ));
    await tester.enterText(find.byKey(const Key('pin_field')), '1234');
    await tester.tap(find.byKey(const Key('pin_submit')));
    await tester.pumpAndSettle();
    expect(got, isNotNull);
    expect(got!.length, 32);
  });
}
