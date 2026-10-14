import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show sqfliteFfiInit, databaseFactoryFfi;

import 'package:discover_self/src/db/database.dart';
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
  Future<List<Prize>> prizes() async => const [Prize('p', '奖品', 1, 1)];
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

  test('unlock leaves key null and data cleared when the DB open fails',
      () async {
    final coordinator =
        AppCoordinator(database: _FailingOpenDatabase(), loader: _StubLoader());

    await expectLater(coordinator.unlock(List<int>.filled(32, 1)),
        throwsA(isA<Exception>()));

    expect(coordinator.key, isNull);
    expect(coordinator.questions, isEmpty);
    expect(coordinator.prizes, isEmpty);
  });

  test('unlock leaves key null when loading fails after a successful open',
      () async {
    final coordinator = AppCoordinator(
        database: _FailingProfilesDatabase(), loader: _StubLoader());

    await expectLater(coordinator.unlock(List<int>.filled(32, 1)),
        throwsA(isA<Exception>()));

    expect(coordinator.key, isNull);
    expect(coordinator.questions, isEmpty);
  });

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
}
