import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show sqfliteFfiInit, databaseFactoryFfi;

import 'package:discover_self/src/app.dart';
import 'package:discover_self/src/db/database.dart';
import 'package:discover_self/src/models/assessment_record.dart';
import 'package:discover_self/src/models/dimension.dart';
import 'package:discover_self/src/models/question.dart';
import 'package:discover_self/src/services/app_coordinator.dart';
import 'package:discover_self/src/services/audio_service.dart';
import 'package:discover_self/src/ui/assessment/assessment_screen.dart';
import 'package:discover_self/src/ui/onboarding/profile_action_sheet.dart';

class _HistoryCoordinator extends AppCoordinator {
  _HistoryCoordinator({List<String> names = const ['我']})
    : super(database: Database(inMemory: true, factory: databaseFactoryFfi)) {
    profileNames = names;
    profileIds = List<int>.generate(names.length, (i) => i);
    questions = const [
      Question(
        id: 'p1',
        type: 'personality',
        dimension: 'openness',
        text: 'Q1',
        options: ['a', 'b'],
      ),
    ];
    dimensions = const [
      DimensionInfo(
        key: 'openness',
        label: '开放性',
        type: 'personality',
        kind: 'likert',
      ),
    ];
    careers = const [];
    prizes = const [];
  }

  final record = AssessmentRecord(
    id: 1,
    finishedAt: DateTime(2026, 10, 20),
    scores: const {'openness': 4},
    answers: const {'p1': 1},
  );

  Completer<void>? readGate;

  @override
  Future<AssessmentRecord?> latestResult() async {
    final gate = readGate;
    if (gate != null) await gate.future;
    return record;
  }

  @override
  Future<List<AssessmentRecord>> resultHistory() async => [record];

  @override
  Future<List<String>> recommendations(Map<String, double> scores) async =>
      const ['多尝试新事物'];

  @override
  Future<void> lock() async {
    key = null;
  }
}

RootFlow _flow(
  AppCoordinator coordinator, {
  DateTime Function()? now,
  Duration autoLockTimeout = const Duration(minutes: 5),
}) => RootFlow(
  coordinator: coordinator,
  audio: AudioService(silent: true),
  onExport: () async {},
  now: now ?? () => DateTime(2026, 1, 1, 12),
  autoLockTimeout: autoLockTimeout,
);

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('returning profile can review or retake', (tester) async {
    final coordinator = _HistoryCoordinator()..key = List<int>.filled(32, 1);

    await tester.pumpWidget(MaterialApp(home: _flow(coordinator)));
    await tester.pumpAndSettle();

    expect(find.text('选择档案'), findsOneWidget);
    await tester.tap(find.text('我'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('view_last_result')), findsOneWidget);
    expect(find.byKey(const Key('sheet_retake')), findsOneWidget);
    expect(find.byKey(const Key('open_history')), findsOneWidget);

    await tester.tap(find.byKey(const Key('view_last_result')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('review_banner')), findsOneWidget);
    expect(find.byKey(const Key('lottery')), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('retake_assessment')));
    await tester.tap(find.byKey(const Key('retake_assessment')));
    await tester.pumpAndSettle();
    expect(find.byType(AssessmentScreen), findsOneWidget);
  });

  testWidgets('history list opens a past result in review mode', (
    tester,
  ) async {
    final coordinator = _HistoryCoordinator()..key = List<int>.filled(32, 1);

    await tester.pumpWidget(MaterialApp(home: _flow(coordinator)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('我'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open_history')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('history_item_0')), findsOneWidget);
    await tester.tap(find.byKey(const Key('history_item_0')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('review_banner')), findsOneWidget);
  });

  testWidgets('auto-lock on resume closes an open history route and locks', (
    tester,
  ) async {
    var clock = DateTime(2026, 1, 1, 12);
    final coordinator = _HistoryCoordinator()..key = List<int>.filled(32, 1);

    await tester.pumpWidget(
      MaterialApp(home: _flow(coordinator, now: () => clock)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('我'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open_history')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history_item_0')), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    clock = clock.add(const Duration(minutes: 6));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pin_field')), findsOneWidget);
    expect(find.byKey(const Key('history_item_0')), findsNothing);
  });

  testWidgets('rapid profile taps open a single sheet for the tapped profile', (
    tester,
  ) async {
    final coordinator = _HistoryCoordinator(names: const ['甲', '乙'])
      ..key = List<int>.filled(32, 1)
      ..readGate = Completer<void>();

    await tester.pumpWidget(MaterialApp(home: _flow(coordinator)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('甲'));
    await tester.tap(find.text('乙'));
    coordinator.readGate!.complete();
    await tester.pumpAndSettle();

    expect(find.byType(ProfileActionSheet), findsOneWidget);
    final sheet = tester.widget<ProfileActionSheet>(
      find.byType(ProfileActionSheet),
    );
    expect(sheet.profileName, '甲');
  });
}
