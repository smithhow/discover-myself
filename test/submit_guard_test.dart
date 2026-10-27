import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show sqfliteFfiInit, databaseFactoryFfi;

import 'package:discover_self/src/app.dart';
import 'package:discover_self/src/db/database.dart';
import 'package:discover_self/src/models/assessment_record.dart';
import 'package:discover_self/src/models/question.dart';
import 'package:discover_self/src/services/app_coordinator.dart';
import 'package:discover_self/src/services/audio_service.dart';

class _DelayedSubmitCoordinator extends AppCoordinator {
  _DelayedSubmitCoordinator()
    : super(database: Database(inMemory: true, factory: databaseFactoryFfi)) {
    key = List<int>.filled(32, 1);
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
  }

  final Completer<Map<String, double>> save = Completer<Map<String, double>>();
  int submitCalls = 0;

  @override
  Future<Map<String, double>> submitAnswers(Map<String, int> answers) {
    submitCalls++;
    return save.future;
  }

  @override
  Future<AssessmentRecord?> latestResult() async => null;

  @override
  Future<List<AssessmentRecord>> resultHistory() async => const [];

  @override
  Future<List<String>> recommendations(Map<String, double> scores) async =>
      const [];

  @override
  Future<void> lock() async {
    key = null;
  }
}

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('ignores duplicate submits while the first save is pending', (
    tester,
  ) async {
    final coordinator = _DelayedSubmitCoordinator();

    await tester.pumpWidget(
      MaterialApp(
        home: RootFlow(
          coordinator: coordinator,
          audio: AudioService(silent: true),
          onExport: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('我'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('a'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(coordinator.submitCalls, 1);

    await tester.tap(find.text('a'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(coordinator.submitCalls, 1);

    coordinator.save.complete({'openness': 2.0});
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('export_pdf')), findsOneWidget);
  });
}
