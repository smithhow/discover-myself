import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show sqfliteFfiInit, databaseFactoryFfi;

import 'package:discover_self/src/app.dart';
import 'package:discover_self/src/db/database.dart';
import 'package:discover_self/src/services/app_coordinator.dart';

AppCoordinator _coordinator() => AppCoordinator(
      database: Database(inMemory: true, factory: databaseFactoryFfi),
    );

/// Drains real async work (SQLite FFI, asset loading) then rebuilds, repeated
/// so continuations scheduled by earlier frames also get a real zone to run in.
///
/// `testWidgets` uses a fake-async zone where real I/O never completes on its
/// own, so DB-backed interactions must go through [WidgetTester.runAsync].
Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pumpAndSettle();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
  }
  await tester.pumpAndSettle();
}

/// Runs [action] in the real async zone and lets pending real work finish
/// before pumping the resulting frame.
Future<void> _act(WidgetTester tester, Future<void> Function() action) async {
  await tester.runAsync(() async {
    await action();
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await _flush(tester);
}

Future<void> _unlock(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('pin_field')), '1234');
  await _act(tester, () => tester.tap(find.byKey(const Key('pin_submit'))));
}

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('full flow: PIN → profile → assessment → result → export',
      (tester) async {
    var exported = false;
    await tester.pumpWidget(MaterialApp(
      home: RootFlow(
        coordinator: _coordinator(),
        onExport: () async => exported = true,
      ),
    ));

    // PIN stage.
    expect(find.byKey(const Key('pin_field')), findsOneWidget);
    await _unlock(tester);

    // Profile stage; create and select a profile.
    expect(find.text('选择档案'), findsOneWidget);
    await tester.tap(find.byKey(const Key('profile_create')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('profile_name_field')), '孩子A');
    await _act(
        tester, () => tester.tap(find.byKey(const Key('profile_create_confirm'))));
    expect(find.text('孩子A'), findsOneWidget);
    await tester.tap(find.text('孩子A'));
    await tester.pumpAndSettle();

    // Assessment stage; answer the single bundled question.
    expect(find.textContaining('测评'), findsOneWidget);
    await _act(tester, () => tester.tap(find.text('同意')));

    // Result stage with a working export control.
    expect(find.byKey(const Key('export_pdf')), findsOneWidget);
    expect(find.byKey(const Key('lottery')), findsOneWidget);
    await _act(tester, () => tester.tap(find.byKey(const Key('export_pdf'))));
    expect(exported, isTrue);
  });

  testWidgets('auto-lock returns to PIN after 5 minutes in background',
      (tester) async {
    var clock = DateTime(2026, 1, 1, 12, 0, 0);
    await tester.pumpWidget(MaterialApp(
      home: RootFlow(
        coordinator: _coordinator(),
        onExport: () async {},
        now: () => clock,
      ),
    ));
    await _unlock(tester);
    expect(find.text('选择档案'), findsOneWidget);

    await tester.runAsync(() async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      clock = clock.add(const Duration(minutes: 6));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pin_field')), findsOneWidget);
  });
}
