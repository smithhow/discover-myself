import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/services/pin_service.dart';
import 'package:discover_self/src/ui/onboarding/pin_screen.dart';

/// A [PinService] whose key derivation blocks until [release] completes, so a
/// submission can be observed mid-flight.
class _BlockingPinService extends PinService {
  _BlockingPinService(this.release) : super(useSecureStorage: false);

  final Future<List<int>> release;
  int calls = 0;

  @override
  Future<List<int>> deriveKeyFor(String pin) {
    calls++;
    return release;
  }
}

void main() {
  testWidgets('3-char pin shows an error and does not unlock', (tester) async {
    List<int>? got;
    await tester.pumpWidget(MaterialApp(
      home: PinScreen(
        pinService: PinService(useSecureStorage: false),
        onUnlocked: (k) async => got = k,
      ),
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
      home: PinScreen(
        pinService: PinService(useSecureStorage: false),
        onUnlocked: (k) async => got = k,
      ),
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
        pinService: PinService(useSecureStorage: false),
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

  testWidgets('a SaltPersistenceException shows the storage error and does not '
      'count as a failed attempt', (tester) async {
    var persistenceFailure = true;
    await tester.pumpWidget(MaterialApp(
      home: PinScreen(
        pinService: PinService(useSecureStorage: false),
        onUnlocked: (_) async {
          if (persistenceFailure) {
            throw const SaltPersistenceException('无法安全保存密钥，请检查设备存储设置');
          }
          throw Exception('bad pin');
        },
        maxAttempts: 2,
      ),
    ));

    await tester.enterText(find.byKey(const Key('pin_field')), '1234');
    await tester.tap(find.byKey(const Key('pin_submit')));
    await tester.pump();
    expect(find.text('无法安全保存密钥，请检查设备存储设置'), findsOneWidget);

    // A subsequent genuine wrong-PIN failure must be the *first* failure, so the
    // button stays enabled rather than immediately locking out.
    persistenceFailure = false;
    await tester.tap(find.byKey(const Key('pin_submit')));
    await tester.pump();
    expect(find.text('PIN 错误，请重试'), findsOneWidget);
    final button =
        tester.widget<ElevatedButton>(find.byKey(const Key('pin_submit')));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('a second tap while unlock is in flight is ignored', (tester) async {
    final completer = Completer<List<int>>();
    final service = _BlockingPinService(completer.future);
    var unlocks = 0;
    await tester.pumpWidget(MaterialApp(
      home: PinScreen(
        pinService: service,
        onUnlocked: (_) async => unlocks++,
      ),
    ));

    await tester.enterText(find.byKey(const Key('pin_field')), '1234');
    await tester.tap(find.byKey(const Key('pin_submit')));
    await tester.pump();

    final button =
        tester.widget<ElevatedButton>(find.byKey(const Key('pin_submit')));
    expect(button.onPressed, isNull);

    await tester.tap(find.byKey(const Key('pin_submit')));
    await tester.pump();
    expect(service.calls, 1);

    completer.complete(List<int>.filled(32, 7));
    await tester.pumpAndSettle();
    expect(unlocks, 1);
  });
}
