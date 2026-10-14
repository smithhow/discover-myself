import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/ui/onboarding/pin_screen.dart';

void main() {
  testWidgets('3-char pin shows an error and does not unlock', (tester) async {
    List<int>? got;
    await tester.pumpWidget(MaterialApp(
      home: PinScreen(onUnlocked: (k) async => got = k),
    ));
    await tester.enterText(find.byKey(const Key('pin_field')), '123');
    await tester.tap(find.byKey(const Key('pin_submit')));
    await tester.pump();
    expect(got, isNull);
    expect(find.text('请输入 4-6 位数字 PIN'), findsOneWidget);
  });

  testWidgets('non-digit pin shows an error and does not unlock',
      (tester) async {
    List<int>? got;
    await tester.pumpWidget(MaterialApp(
      home: PinScreen(onUnlocked: (k) async => got = k),
    ));
    await tester.enterText(find.byKey(const Key('pin_field')), 'abcd');
    await tester.tap(find.byKey(const Key('pin_submit')));
    await tester.pump();
    expect(got, isNull);
    expect(find.text('请输入 4-6 位数字 PIN'), findsOneWidget);
  });

  testWidgets('locks out after maxAttempts failures', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PinScreen(
        onUnlocked: (_) async => throw Exception('bad pin'),
        maxAttempts: 2,
        cooldown: const Duration(milliseconds: 100),
      ),
    ));
    await tester.enterText(find.byKey(const Key('pin_field')), '1234');
    await tester.tap(find.byKey(const Key('pin_submit')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('pin_submit')));
    await tester.pump();

    final button =
        tester.widget<ElevatedButton>(find.byKey(const Key('pin_submit')));
    expect(button.onPressed, isNull);
    expect(find.textContaining('请等待'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 150));
  });
}
