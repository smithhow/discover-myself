import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show sqfliteFfiInit, databaseFactoryFfi;

import 'package:discover_self/src/db/database.dart';
import 'package:discover_self/src/models/career.dart';
import 'package:discover_self/src/models/dimension.dart';
import 'package:discover_self/src/models/guidance.dart';
import 'package:discover_self/src/models/question.dart';
import 'package:discover_self/src/services/app_coordinator.dart';
import 'package:discover_self/src/services/asset_loader.dart';
import 'package:discover_self/src/services/lottery.dart';

const _question = Question(
  id: 'p1',
  type: 'personality',
  dimension: 'openness',
  text: 'Q1',
  options: ['a', 'b'],
);

class _StubLoader extends AssetLoader {
  @override
  Future<List<Question>> questions() async => const [_question];

  @override
  Future<List<DimensionInfo>> dimensions() async => const [];

  @override
  Future<List<CareerItem>> careers() async => const [];

  @override
  Future<List<Prize>> prizes() async => const [Prize('p', '奖品', 1, 1)];
}

const _choiceOne = Question(
  id: 'c1',
  type: 'iq',
  dimension: 'logic',
  text: 'Q1',
  options: ['a', 'b'],
  kind: 'choice',
  correct: 1,
);

const _choiceTwo = Question(
  id: 'c2',
  type: 'iq',
  dimension: 'logic',
  text: 'Q2',
  options: ['a', 'b'],
  kind: 'choice',
  correct: 1,
);

class _ChoiceLoader extends _StubLoader {
  @override
  Future<List<Question>> questions() async => const [_choiceOne, _choiceTwo];
}

class _GuidanceLoader extends _StubLoader {
  @override
  Future<GuidanceContent> guidanceContent() async =>
      GuidanceContent(clusters: const [], careers: const []);
}

class _FailingOpenDatabase extends Database {
  @override
  Future<void> open(List<int> key) async => throw Exception('wrong pin');

  @override
  Future<void> close() async {}
}

class _FailingProfilesDatabase extends Database {
  @override
  Future<void> open(List<int> key) async {}

  @override
  Future<List<Map<String, Object?>>> profiles() async =>
      throw Exception('corrupt database');

  @override
  Future<void> close() async {}
}

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'unlock leaves key null and data cleared when the DB open fails',
    () async {
      final coordinator = AppCoordinator(
        database: _FailingOpenDatabase(),
        loader: _StubLoader(),
      );

      await expectLater(
        coordinator.unlock(List<int>.filled(32, 1)),
        throwsA(isA<Exception>()),
      );

      expect(coordinator.key, isNull);
      expect(coordinator.questions, isEmpty);
      expect(coordinator.prizes, isEmpty);
    },
  );

  test(
    'unlock leaves key null when loading fails after a successful open',
    () async {
      final coordinator = AppCoordinator(
        database: _FailingProfilesDatabase(),
        loader: _StubLoader(),
      );

      await expectLater(
        coordinator.unlock(List<int>.filled(32, 1)),
        throwsA(isA<Exception>()),
      );

      expect(coordinator.key, isNull);
      expect(coordinator.questions, isEmpty);
    },
  );

  test('unlock sets key only after a fully successful load', () async {
    final coordinator = AppCoordinator(
      database: Database(inMemory: true, factory: databaseFactoryFfi),
      loader: _StubLoader(),
    );
    final key = List<int>.filled(32, 1);

    await coordinator.unlock(key);

    expect(coordinator.key, equals(key));
    expect(coordinator.questions, hasLength(1));
    expect(coordinator.prizes, hasLength(1));
  });

  test(
    'submitAnswers persists history and exposes the latest result',
    () async {
      final coordinator = AppCoordinator(
        database: Database(inMemory: true, factory: databaseFactoryFfi),
        loader: _StubLoader(),
      );
      await coordinator.unlock(List<int>.filled(32, 1));

      expect(await coordinator.latestResult(), isNull);

      final scores = await coordinator.submitAnswers({'p1': 2});
      expect(scores['openness'], 2.0);

      final latest = await coordinator.latestResult();
      expect(latest, isNotNull);
      expect(latest!.scores['openness'], 2.0);
      expect(latest.answers, {'p1': 2});

      final history = await coordinator.resultHistory();
      expect(history.length, 1);
      expect(history.single.id, latest.id);
    },
  );

  test(
    'submitAnswers persists fractional choice scores without rounding',
    () async {
      final coordinator = AppCoordinator(
        database: Database(inMemory: true, factory: databaseFactoryFfi),
        loader: _ChoiceLoader(),
      );
      await coordinator.unlock(List<int>.filled(32, 1));

      final scores = await coordinator.submitAnswers({'c1': 1, 'c2': 2});
      expect(scores['logic'], 0.5);

      final latest = await coordinator.latestResult();
      expect(latest, isNotNull);
      expect(latest!.scores['logic'], 0.5);
    },
  );

  test('loadGuidanceContent delegates to the loader', () async {
    final coordinator = AppCoordinator(
      database: Database(inMemory: true, factory: databaseFactoryFfi),
      loader: _GuidanceLoader(),
    );
    await coordinator.unlock(List<int>.filled(32, 1));

    final content = await coordinator.loadGuidanceContent();
    expect(content.clusters, isEmpty);
    expect(content.careers, isEmpty);
  });
}
