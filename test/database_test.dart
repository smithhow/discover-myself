import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show sqfliteFfiInit, databaseFactoryFfi, OpenDatabaseOptions;
import 'package:discover_self/src/db/database.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('open, insert profile and result, read back', () async {
    final db = Database(inMemory: true, factory: databaseFactoryFfi);
    await db.open(List<int>.filled(32, 1));
    final pid = await db.insertProfile('孩子A', List<int>.filled(16, 2));
    expect(pid, greaterThan(0));
    await db.insertResult(pid, 'personality', {
      'openness': 4,
      'extraversion': 3,
    });
    final rows = await db.results(pid);
    expect(rows.length, 1);
    expect(rows.first['type'], 'personality');
    await db.close();
  });

  test('migrates a version 1 database by adding answers_json', () async {
    final factory = databaseFactoryFfi;
    final path = p.join(await factory.getDatabasesPath(), 'discover_self.db');
    await factory.deleteDatabase(path);

    try {
      final v1 = await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE users(id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'name TEXT, pin_salt BLOB, created_at INTEGER)',
            );
            await db.execute(
              'CREATE TABLE assessments(id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'profile_id INTEGER, type TEXT, score_json TEXT, '
              'finished_at INTEGER)',
            );
            await db.execute(
              'CREATE TABLE achievements(id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'profile_id INTEGER, type TEXT, points INTEGER, earned_at INTEGER)',
            );
            await db.execute(
              'CREATE TABLE lottery_logs(id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'profile_id INTEGER, seed INTEGER, prize_id TEXT, drawn_at INTEGER)',
            );
          },
        ),
      );
      await v1.insert('assessments', {
        'profile_id': 1,
        'type': 'personality',
        'score_json': '{"a":3}',
        'finished_at': 10,
      });
      await v1.close();

      final db = Database(factory: factory);
      await db.open(List<int>.filled(32, 1));
      final rows = await db.results(1);
      expect(rows.single['answers_json'], isNull);
      await db.close();
    } finally {
      await factory.deleteDatabase(path);
    }
  });

  test('latestResult orders by time then id', () async {
    final db = Database(inMemory: true, factory: databaseFactoryFfi);
    await db.open(List<int>.filled(32, 1));
    final pid = await db.insertProfile('A', List<int>.filled(16, 2));

    await db.insertResult(pid, 'personality', {'a': 1});
    await db.insertResult(pid, 'personality', {'a': 2});

    final latest = await db.latestResult(pid);
    expect(latest, isNotNull);
    expect(latest!.scores, {'a': 2.0});
    expect(await db.latestResult(999), isNull);
    await db.close();
  });

  test('saveResult keeps only the latest answers and prunes to keep', () async {
    final db = Database(inMemory: true, factory: databaseFactoryFfi);
    await db.open(List<int>.filled(32, 1));
    final pid = await db.insertProfile('A', List<int>.filled(16, 2));

    await db.saveResult(
      pid,
      'personality',
      {'a': 1},
      answers: {'q1': 1},
      keep: 3,
    );
    await db.saveResult(
      pid,
      'personality',
      {'a': 2},
      answers: {'q1': 2},
      keep: 3,
    );

    var history = await db.resultHistory(pid);
    expect(history.length, 2);
    expect(history.first.scores, {'a': 2.0});
    expect(history.first.answers, {'q1': 2});
    expect(history.last.answers, isNull);

    for (var i = 0; i < 3; i++) {
      await db.saveResult(
        pid,
        'personality',
        {'a': 10 + i},
        answers: {'q1': 10 + i},
        keep: 3,
      );
    }

    history = await db.resultHistory(pid);
    expect(history.length, 3);
    expect(history.first.scores, {'a': 12.0});
    expect(history.first.answers, {'q1': 12});
    expect(history[1].answers, isNull);
    expect(history[2].answers, isNull);
    await db.close();
  });
}
