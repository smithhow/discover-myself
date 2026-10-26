import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show sqfliteFfiInit, databaseFactoryFfi;

import 'package:discover_self/src/app.dart';
import 'package:discover_self/src/db/database.dart';
import 'package:discover_self/src/services/app_coordinator.dart';
import 'package:discover_self/src/services/audio_service.dart';
import 'package:discover_self/src/services/pin_service.dart';
import 'package:discover_self/src/ui/assessment/assessment_screen.dart';

AudioService _silentAudio() => AudioService(silent: true);

AppCoordinator _coordinator() => AppCoordinator(
      database: Database(inMemory: true, factory: databaseFactoryFfi),
    );

PinService _pinService() => PinService(useSecureStorage: false);

/// A coordinator whose scoring step always fails, to exercise the assessment
/// error path.
class _FailingSubmitCoordinator extends AppCoordinator {
  _FailingSubmitCoordinator()
      : super(database: Database(inMemory: true, factory: databaseFactoryFfi));

  @override
  Future<Map<String, double>> submitAnswers(Map<String, int> answers) async =>
      throw Exception('submit failed');
}

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

/// Answers every question in the assessment, tapping the first option each
/// time. The final tap triggers the (async) submit, so it runs via [_act].
Future<void> _answerAll(WidgetTester tester) async {
  final count = tester
      .widget<AssessmentScreen>(find.byType(AssessmentScreen))
      .questions
      .length;
  for (var i = 0; i < count - 1; i++) {
    await tester.tap(find.byType(ListTile).first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 250));

    final celebration = find.byKey(const Key('stage_celebration'));
    if (celebration.evaluate().isNotEmpty) {
      await tester.tap(celebration);
      await tester.pump(const Duration(milliseconds: 250));
    }
  }
  await _act(tester,
      () => tester.tap(find.byType(ListTile).first, warnIfMissed: false));
}

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('full flow: PIN → profile → assessment → result → export',
      (tester) async {
    var exported = false;
    await tester.pumpWidget(MaterialApp(
      home: RootFlow(
        coordinator: _coordinator(),
        pinService: _pinService(),
        audio: _silentAudio(),
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

    // Assessment stage; answer every bundled question.
    expect(find.textContaining('测评'), findsOneWidget);
    await _answerAll(tester);

    // Result stage with a working export control.
    expect(find.byKey(const Key('export_pdf')), findsOneWidget);
    expect(find.byKey(const Key('lottery')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('export_pdf')));
    await tester.pumpAndSettle();
    await _act(tester, () => tester.tap(find.byKey(const Key('export_pdf'))));
    expect(exported, isTrue);
  });

  testWidgets('auto-lock returns to PIN after 5 minutes in background',
      (tester) async {
    var clock = DateTime(2026, 1, 1, 12, 0, 0);
    await tester.pumpWidget(MaterialApp(
      home: RootFlow(
        coordinator: _coordinator(),
        pinService: _pinService(),
        audio: _silentAudio(),
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

  testWidgets('assessment failure surfaces an error and keeps the user unstuck',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RootFlow(
        coordinator: _FailingSubmitCoordinator(),
        pinService: _pinService(),
        audio: _silentAudio(),
        onExport: () async {},
      ),
    ));

    await _unlock(tester);
    await tester.tap(find.byKey(const Key('profile_create')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('profile_name_field')), '孩子A');
    await _act(tester,
        () => tester.tap(find.byKey(const Key('profile_create_confirm'))));
    await tester.tap(find.text('孩子A'));
    await tester.pumpAndSettle();

    await _answerAll(tester);

    expect(find.text('提交失败，请重试'), findsOneWidget);
    expect(find.byKey(const Key('export_pdf')), findsNothing);
  });
}
