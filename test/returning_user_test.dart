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

class _HistoryCoordinator extends AppCoordinator {
  _HistoryCoordinator()
      : super(database: Database(inMemory: true, factory: databaseFactoryFfi)) {
    profileNames = const ['我'];
    profileIds = const [0];
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

  @override
  Future<AssessmentRecord?> latestResult() async => record;

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

RootFlow _flow(AppCoordinator coordinator) => RootFlow(
      coordinator: coordinator,
      audio: AudioService(silent: true),
      onExport: () async {},
    );

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('returning profile can review or retake', (tester) async {
    final coordinator = _HistoryCoordinator()
      ..key = List<int>.filled(32, 1);

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

  testWidgets('history list opens a past result in review mode',
      (tester) async {
    final coordinator = _HistoryCoordinator()
      ..key = List<int>.filled(32, 1);

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
}
