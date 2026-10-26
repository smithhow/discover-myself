# 发现自我 · 关卡动画与结果回看 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add lightweight stage-completion/result animations and a "review last result / retake" flow that persists per-profile score history while keeping only the latest answer sheet.

**Architecture:** Persist each attempt in SQLite version 2 with a new `answers_json` column; expose `latestResult` / `resultHistory` through `AppCoordinator`; gate the profile tap behind a bottom sheet when history exists; render history through `ResultScreen` in a review mode. Animations stay dependency-free using Flutter's built-in controllers and `CustomPainter`.

**Tech Stack:** Flutter 3.47.7, Dart 3.13.5, sqflite_sqlcipher / sqflite_common_ffi, flutter_test, Material 3.

## Global Constraints

- No new dependencies and no Lottie/Rive; `lottie` already exists in `pubspec.yaml` but must not be imported.
- All user-facing copy is Simplified Chinese, exactly as written in the tasks below.
- Data stays local and encrypted; do not add network calls or new storage locations.
- Keep at most 50 results per profile and only the newest result's `answers_json`.
- Respect `MediaQuery.of(context).disableAnimations` in every new animation.
- Use `Color.withValues(alpha: ...)`, not deprecated `withOpacity`.
- Run commands from `D:\openclaw\workspace\discover-myself`.

---

## File Structure

Create:
- `lib/src/models/assessment_record.dart` — typed view of one persisted attempt.
- `lib/src/utils/date_format.dart` — shared `YYYY-MM-DD` formatter.
- `lib/src/ui/onboarding/profile_action_sheet.dart` — bottom sheet with review/retake/history actions.
- `lib/src/ui/result/history_screen.dart` — attempt list with score summaries.
- `lib/src/ui/assessment/stage_celebration.dart` — full-screen stage-completion overlay.
- `lib/src/ui/widgets/confetti.dart` — reusable falling-confetti animation.
- `test/assessment_record_test.dart`, `test/date_format_test.dart`, `test/profile_action_sheet_test.dart`, `test/history_screen_test.dart`, `test/result_screen_test.dart`, `test/stage_celebration_test.dart`, `test/confetti_test.dart`, `test/returning_user_test.dart`.

Modify:
- `lib/src/db/database.dart` — schema v2, history queries, transactional save.
- `lib/src/services/app_coordinator.dart` — persist answers, expose history.
- `lib/src/ui/result/result_screen.dart` — review mode, buttons, staggered animation.
- `lib/src/ui/assessment/assessment_screen.dart` — celebration overlay.
- `lib/src/app.dart` — profile action routing, review state, history navigation, confetti in prize dialog.
- `test/database_test.dart`, `test/app_coordinator_test.dart`, `test/integration_flow_test.dart`.

---

### Task 1: Assessment record model and database history

**Files:**
- Create: `lib/src/models/assessment_record.dart`
- Modify: `lib/src/db/database.dart`
- Test: `test/assessment_record_test.dart` (create)
- Test: `test/database_test.dart` (modify)

**Interfaces:**
- Consumes: `sqflite` rows from the `assessments` table.
- Produces:
  - `class AssessmentRecord { int id; DateTime finishedAt; Map<String, double> scores; Map<String, int>? answers; static AssessmentRecord? tryFromRow(Map<String, Object?> row); }`
  - `Database.saveResult(int profileId, String type, Map<String, int> scores, {required Map<String, int> answers, int keep = 50})`
  - `Database.latestResult(int profileId) -> Future<AssessmentRecord?>`
  - `Database.resultHistory(int profileId) -> Future<List<AssessmentRecord>>`
  - `Database.pruneResults(int profileId, {int keep = 50}) -> Future<void>`
  - `Database.insertResult(...)` gains optional `Map<String, int>? answers`.

- [ ] **Step 1: Write the failing model test**

Create `test/assessment_record_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/models/assessment_record.dart';

void main() {
  test('parses scores and answers from a row', () {
    final record = AssessmentRecord.tryFromRow({
      'id': 7,
      'finished_at': 1000,
      'score_json': '{"a":3,"b":4.5}',
      'answers_json': '{"q1":2,"q2":4}',
    });

    expect(record, isNotNull);
    expect(record!.id, 7);
    expect(record.finishedAt.millisecondsSinceEpoch, 1000);
    expect(record.scores, {'a': 3.0, 'b': 4.5});
    expect(record.answers, {'q1': 2, 'q2': 4});
  });

  test('returns null for invalid score json', () {
    expect(
      AssessmentRecord.tryFromRow({
        'id': 1,
        'finished_at': 0,
        'score_json': 'not json',
      }),
      isNull,
    );
  });

  test('returns null when scores are empty', () {
    expect(
      AssessmentRecord.tryFromRow({
        'id': 1,
        'finished_at': 0,
        'score_json': '{}',
      }),
      isNull,
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/assessment_record_test.dart -r expanded`

Expected: FAIL because `assessment_record.dart` does not exist.

- [ ] **Step 3: Create the model**

Create `lib/src/models/assessment_record.dart`:

```dart
import 'dart:convert';

/// One persisted assessment attempt for a profile.
///
/// [answers] is non-null only for the newest attempt: saving a new result
/// clears the answer sheet on older rows.
class AssessmentRecord {
  const AssessmentRecord({
    required this.id,
    required this.finishedAt,
    required this.scores,
    this.answers,
  });

  final int id;
  final DateTime finishedAt;
  final Map<String, double> scores;
  final Map<String, int>? answers;

  /// Parses a database row, returning `null` when `score_json` is invalid or
  /// contains no numeric values.
  static AssessmentRecord? tryFromRow(Map<String, Object?> row) {
    try {
      final decoded = jsonDecode(row['score_json'] as String? ?? '');
      if (decoded is! Map) return null;

      final scores = <String, double>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is num) scores[entry.key as String] = value.toDouble();
      }
      if (scores.isEmpty) return null;

      final rawAnswers = row['answers_json'] as String?;
      Map<String, int>? answers;
      if (rawAnswers != null && rawAnswers.isNotEmpty) {
        final decodedAnswers = jsonDecode(rawAnswers);
        if (decodedAnswers is Map) {
          answers = {
            for (final entry in decodedAnswers.entries)
              if (entry.value is num)
                entry.key as String: (entry.value as num).toInt(),
          };
        }
      }

      return AssessmentRecord(
        id: row['id'] as int,
        finishedAt: DateTime.fromMillisecondsSinceEpoch(
          (row['finished_at'] as num?)?.toInt() ?? 0,
        ),
        scores: scores,
        answers: answers,
      );
    } catch (_) {
      return null;
    }
  }
}
```

- [ ] **Step 4: Run the model test**

Run: `flutter test test/assessment_record_test.dart -r expanded`

Expected: PASS (3 tests).

- [ ] **Step 5: Write the failing database tests**

Replace `test/database_test.dart` with:

```dart
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
    await db.insertResult(pid, 'personality', {'openness': 4, 'extraversion': 3});
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
                'name TEXT, pin_salt BLOB, created_at INTEGER)');
            await db.execute(
                'CREATE TABLE assessments(id INTEGER PRIMARY KEY AUTOINCREMENT, '
                'profile_id INTEGER, type TEXT, score_json TEXT, '
                'finished_at INTEGER)');
            await db.execute(
                'CREATE TABLE achievements(id INTEGER PRIMARY KEY AUTOINCREMENT, '
                'profile_id INTEGER, type TEXT, points INTEGER, earned_at INTEGER)');
            await db.execute(
                'CREATE TABLE lottery_logs(id INTEGER PRIMARY KEY AUTOINCREMENT, '
                'profile_id INTEGER, seed INTEGER, prize_id TEXT, drawn_at INTEGER)');
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

    await db.saveResult(pid, 'personality', {'a': 1}, answers: {'q1': 1}, keep: 3);
    await db.saveResult(pid, 'personality', {'a': 2}, answers: {'q1': 2}, keep: 3);

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
```

- [ ] **Step 6: Run the database tests to verify they fail**

Run: `flutter test test/database_test.dart -r expanded`

Expected: FAIL because `saveResult`, `latestResult`, and `resultHistory` are undefined.

- [ ] **Step 7: Implement the database changes**

Replace `lib/src/db/database.dart` with:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart' as sqflite;

import '../models/assessment_record.dart';

/// Thin wrapper around an encrypted SQLite database.
///
/// Production builds open the database with [sqflite_sqlcipher] and a password
/// derived from the user's key. Tests can inject an unencrypted
/// `sqflite_common_ffi` factory (see [factory]) so the layer runs on the Dart
/// VM without the native plugin.
class Database {
  Database({this.inMemory = false, sqflite.DatabaseFactory? factory})
      : _factory = factory;

  /// When true the database is opened in memory instead of on disk.
  final bool inMemory;

  /// Optional factory override used by tests to supply an unencrypted backend.
  final sqflite.DatabaseFactory? _factory;

  sqflite.Database? _db;

  static const String _dbName = 'discover_self.db';
  static const int _version = 2;

  /// Opens the database. [key] is used as the encryption password in
  /// production; it is ignored when a test [factory] is injected.
  Future<void> open(List<int> key) async {
    final factory = _factory ?? sqflite.databaseFactory;
    final path = inMemory
        ? sqflite.inMemoryDatabasePath
        : p.join(await factory.getDatabasesPath(), _dbName);

    if (_factory != null) {
      _db = await _factory.openDatabase(
        path,
        options: sqflite.OpenDatabaseOptions(
          version: _version,
          onCreate: _create,
          onUpgrade: _onUpgrade,
        ),
      );
      return;
    }

    final password = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    _db = await sqflite.openDatabase(
      path,
      password: password,
      version: _version,
      onCreate: _create,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _create(sqflite.Database db, int version) async {
    await db.execute(
        'CREATE TABLE users(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, '
        'pin_salt BLOB, created_at INTEGER)');
    await db.execute(
        'CREATE TABLE assessments(id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'profile_id INTEGER, type TEXT, score_json TEXT, answers_json TEXT, '
        'finished_at INTEGER)');
    await db.execute(
        'CREATE TABLE achievements(id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'profile_id INTEGER, type TEXT, points INTEGER, earned_at INTEGER)');
    await db.execute(
        'CREATE TABLE lottery_logs(id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'profile_id INTEGER, seed INTEGER, prize_id TEXT, drawn_at INTEGER)');
  }

  Future<void> _onUpgrade(
      sqflite.Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE assessments ADD COLUMN answers_json TEXT');
    }
  }

  /// Inserts a profile and returns its row id.
  Future<int> insertProfile(String name, List<int> salt) async => _db!.insert(
        'users',
        {
          'name': name,
          'pin_salt': Uint8List.fromList(salt),
          'created_at': DateTime.now().millisecondsSinceEpoch,
        },
      );

  /// Returns all stored profiles.
  Future<List<Map<String, Object?>>> profiles() async => _db!.query('users');

  /// Inserts an assessment result and returns its row id.
  Future<int> insertResult(
    int profileId,
    String type,
    Map<String, int> scores, {
    Map<String, int>? answers,
  }) async =>
      _db!.insert('assessments', {
        'profile_id': profileId,
        'type': type,
        'score_json': jsonEncode(scores),
        'answers_json': answers == null ? null : jsonEncode(answers),
        'finished_at': DateTime.now().millisecondsSinceEpoch,
      });

  /// Saves a new attempt atomically: insert, clear older answer sheets, prune.
  Future<void> saveResult(
    int profileId,
    String type,
    Map<String, int> scores, {
    required Map<String, int> answers,
    int keep = 50,
  }) async {
    await _db!.transaction((txn) async {
      final id = await txn.insert('assessments', {
        'profile_id': profileId,
        'type': type,
        'score_json': jsonEncode(scores),
        'answers_json': jsonEncode(answers),
        'finished_at': DateTime.now().millisecondsSinceEpoch,
      });

      await txn.update(
        'assessments',
        {'answers_json': null},
        where: 'profile_id = ? AND id != ?',
        whereArgs: [profileId, id],
      );

      final rows = await txn.query(
        'assessments',
        columns: ['id'],
        where: 'profile_id = ?',
        whereArgs: [profileId],
        orderBy: 'finished_at DESC, id DESC',
      );
      if (rows.length > keep) {
        final stale = rows.skip(keep).map((row) => row['id'] as int).toList();
        await txn.delete(
          'assessments',
          where: 'id IN (${List.filled(stale.length, '?').join(',')})',
          whereArgs: stale,
        );
      }
    });
  }

  /// Returns the assessment results belonging to [profileId].
  Future<List<Map<String, Object?>>> results(int profileId) async =>
      _db!.query('assessments',
          where: 'profile_id = ?', whereArgs: [profileId]);

  /// Returns the newest parseable attempt, or `null` when there is none.
  Future<AssessmentRecord?> latestResult(int profileId) async {
    final rows = await _db!.query(
      'assessments',
      where: 'profile_id = ?',
      whereArgs: [profileId],
      orderBy: 'finished_at DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AssessmentRecord.tryFromRow(rows.first);
  }

  /// Returns every parseable attempt newest first.
  Future<List<AssessmentRecord>> resultHistory(int profileId) async {
    final rows = await _db!.query(
      'assessments',
      where: 'profile_id = ?',
      whereArgs: [profileId],
      orderBy: 'finished_at DESC, id DESC',
    );
    final out = <AssessmentRecord>[];
    for (final row in rows) {
      final record = AssessmentRecord.tryFromRow(row);
      if (record != null) out.add(record);
    }
    return out;
  }

  /// Deletes all but the newest [keep] attempts for [profileId].
  Future<void> pruneResults(int profileId, {int keep = 50}) async {
    final rows = await _db!.query(
      'assessments',
      columns: ['id'],
      where: 'profile_id = ?',
      whereArgs: [profileId],
      orderBy: 'finished_at DESC, id DESC',
    );
    if (rows.length <= keep) return;
    final stale = rows.skip(keep).map((row) => row['id'] as int).toList();
    await _db!.delete(
      'assessments',
      where: 'id IN (${List.filled(stale.length, '?').join(',')})',
      whereArgs: stale,
    );
  }

  /// Closes the database and releases the handle.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
```

- [ ] **Step 8: Run the database and model tests**

Run: `flutter test test/database_test.dart test/assessment_record_test.dart -r expanded`

Expected: PASS (7 tests).

- [ ] **Step 9: Commit**

```bash
git add lib/src/models/assessment_record.dart lib/src/db/database.dart test/assessment_record_test.dart test/database_test.dart
git commit -m "feat: persist assessment history with latest-only answers"
```

---

### Task 2: Coordinator history APIs

**Files:**
- Modify: `lib/src/services/app_coordinator.dart`
- Test: `test/app_coordinator_test.dart` (modify)

**Interfaces:**
- Consumes: `Database.saveResult`, `Database.latestResult`, `Database.resultHistory`.
- Produces:
  - `AppCoordinator.latestResult() -> Future<AssessmentRecord?>`
  - `AppCoordinator.resultHistory() -> Future<List<AssessmentRecord>>`
  - `AppCoordinator.submitAnswers(...)` now persists the answer map.

- [ ] **Step 1: Write the failing coordinator test**

Append this test inside `void main()` in `test/app_coordinator_test.dart`, after the existing tests:

```dart
  test('submitAnswers persists history and exposes the latest result',
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
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/app_coordinator_test.dart -r expanded`

Expected: FAIL because `latestResult` and `resultHistory` are undefined.

- [ ] **Step 3: Implement the coordinator changes**

In `lib/src/services/app_coordinator.dart`, add the import:

```dart
import '../models/assessment_record.dart';
```

Replace `submitAnswers` with:

```dart
  /// Scores [answers], persists the rounded per-dimension result and answer
  /// sheet, and returns the averaged scores keyed by dimension.
  Future<Map<String, double>> submitAnswers(Map<String, int> answers) async {
    final scores = AssessmentService(questions).score(answers);
    final rounded = scores.map((k, v) => MapEntry(k, v.round()));
    final type = questions.isNotEmpty ? questions.first.type : 'personality';
    await _db.saveResult(
      _activeProfileId,
      type,
      rounded,
      answers: answers,
    );
    return scores;
  }

  int get _activeProfileId =>
      profileIds.isNotEmpty ? profileIds[activeProfile] : activeProfile;

  /// The newest persisted attempt for the active profile, if any.
  Future<AssessmentRecord?> latestResult() =>
      _db.latestResult(_activeProfileId);

  /// All persisted attempts for the active profile, newest first.
  Future<List<AssessmentRecord>> resultHistory() =>
      _db.resultHistory(_activeProfileId);
```

- [ ] **Step 4: Run the coordinator tests**

Run: `flutter test test/app_coordinator_test.dart -r expanded`

Expected: PASS (all existing tests plus the new one).

- [ ] **Step 5: Commit**

```bash
git add lib/src/services/app_coordinator.dart test/app_coordinator_test.dart
git commit -m "feat: expose assessment history through the coordinator"
```

---

### Task 3: Date formatter and profile action sheet

**Files:**
- Create: `lib/src/utils/date_format.dart`
- Create: `lib/src/ui/onboarding/profile_action_sheet.dart`
- Test: `test/date_format_test.dart` (create)
- Test: `test/profile_action_sheet_test.dart` (create)

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `String formatDate(DateTime date)` → `YYYY-MM-DD`
  - `enum ProfileAction { viewLatest, retake, history }`
  - `class ProfileActionSheet extends StatelessWidget` with `profileName`, `lastFinishedAt`, `historyCount`.

- [ ] **Step 1: Write the failing formatter test**

Create `test/date_format_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/utils/date_format.dart';

void main() {
  test('pads month and day', () {
    expect(formatDate(DateTime(2026, 1, 5)), '2026-01-05');
    expect(formatDate(DateTime(2026, 12, 31)), '2026-12-31');
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/date_format_test.dart -r expanded`

Expected: FAIL because `date_format.dart` does not exist.

- [ ] **Step 3: Implement the formatter**

Create `lib/src/utils/date_format.dart`:

```dart
/// Formats [date] as `YYYY-MM-DD` for compact history labels.
String formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
```

- [ ] **Step 4: Write the failing sheet test**

Create `test/profile_action_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/ui/onboarding/profile_action_sheet.dart';

void main() {
  testWidgets('returns the chosen action', (tester) async {
    ProfileAction? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('open_sheet'),
                onPressed: () async {
                  chosen = await showModalBottomSheet<ProfileAction>(
                    context: context,
                    builder: (_) => const ProfileActionSheet(
                      profileName: '我',
                      lastFinishedAt: null,
                      historyCount: 2,
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open_sheet')));
    await tester.pumpAndSettle();

    expect(find.text('我'), findsOneWidget);
    expect(find.byKey(const Key('view_last_result')), findsOneWidget);
    expect(find.byKey(const Key('sheet_retake')), findsOneWidget);
    expect(find.byKey(const Key('open_history')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sheet_retake')));
    await tester.pumpAndSettle();
    expect(chosen, ProfileAction.retake);
  });
}
```

- [ ] **Step 5: Run the sheet test to verify it fails**

Run: `flutter test test/profile_action_sheet_test.dart -r expanded`

Expected: FAIL because `profile_action_sheet.dart` does not exist.

- [ ] **Step 6: Implement the sheet**

Create `lib/src/ui/onboarding/profile_action_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import '../../utils/date_format.dart';

enum ProfileAction { viewLatest, retake, history }

/// Bottom sheet shown when a profile already has at least one attempt.
class ProfileActionSheet extends StatelessWidget {
  const ProfileActionSheet({
    super.key,
    required this.profileName,
    required this.lastFinishedAt,
    required this.historyCount,
  });

  final String profileName;
  final DateTime? lastFinishedAt;
  final int historyCount;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                lastFinishedAt == null
                    ? profileName
                    : '$profileName · 上次测评 ${formatDate(lastFinishedAt!)}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('view_last_result'),
                onPressed: () =>
                    Navigator.pop(context, ProfileAction.viewLatest),
                icon: const Icon(Icons.assessment_outlined),
                label: const Text('查看上次结果'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('sheet_retake'),
                onPressed: () => Navigator.pop(context, ProfileAction.retake),
                icon: const Icon(Icons.refresh),
                label: const Text('重新测评（更新结果）'),
              ),
              const SizedBox(height: 4),
              TextButton(
                key: const Key('open_history'),
                onPressed: () => Navigator.pop(context, ProfileAction.history),
                child: Text('历史记录 ($historyCount)'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
            ],
          ),
        ),
      );
}
```

- [ ] **Step 7: Run both tests**

Run: `flutter test test/date_format_test.dart test/profile_action_sheet_test.dart -r expanded`

Expected: PASS (2 tests).

- [ ] **Step 8: Commit**

```bash
git add lib/src/utils/date_format.dart lib/src/ui/onboarding/profile_action_sheet.dart test/date_format_test.dart test/profile_action_sheet_test.dart
git commit -m "feat: add profile result action sheet"
```

---

### Task 4: History screen

**Files:**
- Create: `lib/src/ui/result/history_screen.dart`
- Test: `test/history_screen_test.dart` (create)

**Interfaces:**
- Consumes: `AssessmentRecord`, `DimensionInfo`, `CareerItem`, `buildSummary`, `formatDate`.
- Produces: `HistoryScreen({records, dimensions, careers, onOpen})`.

- [ ] **Step 1: Write the failing history test**

Create `test/history_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/models/assessment_record.dart';
import 'package:discover_self/src/models/dimension.dart';
import 'package:discover_self/src/ui/result/history_screen.dart';

void main() {
  testWidgets('lists attempts newest first and opens the tapped one',
      (tester) async {
    AssessmentRecord? opened;
    final records = [
      AssessmentRecord(
        id: 2,
        finishedAt: DateTime(2026, 10, 20),
        scores: const {'openness': 4},
      ),
      AssessmentRecord(
        id: 1,
        finishedAt: DateTime(2026, 10, 1),
        scores: const {'openness': 2},
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: HistoryScreen(
          records: records,
          dimensions: const [
            DimensionInfo(
              key: 'openness',
              label: '开放性',
              type: 'personality',
              kind: 'likert',
            ),
          ],
          careers: const [],
          onOpen: (record) => opened = record,
        ),
      ),
    );

    expect(find.text('2026-10-20'), findsOneWidget);
    expect(find.textContaining('开放性'), findsWidgets);

    await tester.tap(find.byKey(const Key('history_item_0')));
    expect(opened?.id, 2);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/history_screen_test.dart -r expanded`

Expected: FAIL because `history_screen.dart` does not exist.

- [ ] **Step 3: Implement the history screen**

Create `lib/src/ui/result/history_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../models/assessment_record.dart';
import '../../models/career.dart';
import '../../models/dimension.dart';
import '../../services/summary.dart';
import '../../utils/date_format.dart';

/// Lists every persisted attempt for one profile, newest first.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    super.key,
    required this.records,
    required this.dimensions,
    required this.careers,
    required this.onOpen,
  });

  final List<AssessmentRecord> records;
  final List<DimensionInfo> dimensions;
  final List<CareerItem> careers;
  final void Function(AssessmentRecord record) onOpen;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('历史记录')),
        body: records.isEmpty
            ? const Center(child: Text('暂无历史记录'))
            : ListView.separated(
                itemCount: records.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final record = records[index];
                  final summary = buildSummary(
                    scores: record.scores,
                    dimensions: dimensions,
                    careers: careers,
                  );
                  final scores = _scoreSummary(record);
                  return ListTile(
                    key: Key('history_item_$index'),
                    title: Text(formatDate(record.finishedAt)),
                    subtitle: Text(
                      scores.isEmpty
                          ? summary.headline
                          : '${summary.headline}\n$scores',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: scores.isNotEmpty,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onOpen(record),
                  );
                },
              ),
      );

  String _scoreSummary(AssessmentRecord record) {
    final parts = <String>[];
    for (final dimension in dimensions) {
      final value = record.scores[dimension.key];
      if (value == null) continue;
      final display = dimension.isChoice
          ? '${(value * 100).round()}%'
          : value.toStringAsFixed(1);
      parts.add('${dimension.label} $display');
    }
    return parts.take(4).join(' · ');
  }
}
```

- [ ] **Step 4: Run the history test**

Run: `flutter test test/history_screen_test.dart -r expanded`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/ui/result/history_screen.dart test/history_screen_test.dart
git commit -m "feat: add result history list"
```

---

### Task 5: Result screen review mode and staggered animation

**Files:**
- Modify: `lib/src/ui/result/result_screen.dart`
- Test: `test/result_screen_test.dart` (create)

**Interfaces:**
- Consumes: `formatDate`, existing `buildSummary`.
- Produces: `ResultScreen` gains `onRetake`, `onHistory`, `reviewedAt`; review mode hides the lottery button; keys `review_banner`, `retake_assessment`, `history_list`.

- [ ] **Step 1: Write the failing result tests**

Create `test/result_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/models/dimension.dart';
import 'package:discover_self/src/ui/result/result_screen.dart';

Widget _screen({
  DateTime? reviewedAt,
  VoidCallback? onLottery,
  VoidCallback? onRetake,
  VoidCallback? onHistory,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: ResultScreen(
        profileName: '我',
        scores: const {'openness': 4},
        recommendations: const ['多尝试新事物'],
        dimensions: const [
          DimensionInfo(
            key: 'openness',
            label: '开放性',
            type: 'personality',
            kind: 'likert',
          ),
        ],
        careers: const [],
        reviewedAt: reviewedAt,
        onLottery: onLottery,
        onRetake: onRetake,
        onHistory: onHistory,
        onExport: () async {},
      ),
    ),
  );
}

void main() {
  testWidgets('latest result shows the lottery button', (tester) async {
    await tester.pumpWidget(_screen(onLottery: () {}));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('review_banner')), findsNothing);
    expect(find.byKey(const Key('lottery')), findsOneWidget);
  });

  testWidgets('review mode shows the banner, hides lottery, and wires actions',
      (tester) async {
    var retook = false;
    var openedHistory = false;

    await tester.pumpWidget(_screen(
      reviewedAt: DateTime(2026, 10, 20),
      onRetake: () => retook = true,
      onHistory: () => openedHistory = true,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('review_banner')), findsOneWidget);
    expect(find.textContaining('2026-10-20'), findsOneWidget);
    expect(find.byKey(const Key('lottery')), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('retake_assessment')));
    await tester.tap(find.byKey(const Key('retake_assessment')));
    expect(retook, isTrue);

    await tester.ensureVisible(find.byKey(const Key('history_list')));
    await tester.tap(find.byKey(const Key('history_list')));
    expect(openedHistory, isTrue);
  });

  testWidgets('renders without animation when reduce motion is on',
      (tester) async {
    await tester.pumpWidget(_screen(disableAnimations: true));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/result_screen_test.dart -r expanded`

Expected: FAIL because `reviewedAt`, `onRetake`, and `onHistory` are undefined.

- [ ] **Step 3: Replace the result screen**

Replace `lib/src/ui/result/result_screen.dart` with:

```dart
import 'package:flutter/material.dart';

import '../../models/career.dart';
import '../../models/dimension.dart';
import '../../services/summary.dart';
import '../../utils/date_format.dart';

/// Displays the overall evaluation, per-dimension scores (grouped by type),
/// career directions and growth tips, plus export/history/lottery actions.
///
/// When [reviewedAt] is set the screen shows a past attempt: a banner replaces
/// the lottery action so prizes cannot be claimed twice.
class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.profileName,
    required this.scores,
    required this.recommendations,
    this.dimensions = const [],
    this.careers = const [],
    this.onExport,
    this.onLottery,
    this.onRetake,
    this.onHistory,
    this.reviewedAt,
  });

  final String profileName;
  final Map<String, double> scores;
  final List<String> recommendations;

  /// Dimension metadata used to label, explain and group the scores.
  final List<DimensionInfo> dimensions;

  /// Career suggestions used to derive suitable / cautious directions.
  final List<CareerItem> careers;

  /// Exports the report (e.g. shares a PDF). Disabled when `null`.
  final Future<void> Function()? onExport;

  /// Draws a lottery prize. Hidden in review mode or when `null`.
  final VoidCallback? onLottery;

  /// Starts a fresh assessment. Hidden when `null`.
  final VoidCallback? onRetake;

  /// Opens the history list. Hidden when `null`.
  final VoidCallback? onHistory;

  /// When non-null the screen is showing a past attempt.
  final DateTime? reviewedAt;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  static const Map<String, String> _typeTitles = {
    'personality': '人格特质',
    'iq': '认知能力',
    'eq': '情商',
    'interest': '职业兴趣',
  };

  static const List<String> _typeOrder = [
    'personality',
    'iq',
    'eq',
    'interest',
  ];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  bool get _isReview => widget.reviewedAt != null;

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final summary = buildSummary(
      scores: widget.scores,
      dimensions: widget.dimensions,
      careers: widget.careers,
    );
    var barIndex = 0;

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.reviewedAt != null) ...[
            Container(
              key: const Key('review_banner'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '回看 · 测评于 ${formatDate(widget.reviewedAt!)}',
                style: const TextStyle(color: Color(0xFF8D4E00)),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text('档案：${widget.profileName}',
              style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 12),
          _buildOverall(summary),
          const SizedBox(height: 8),
          for (final type in _orderedTypes())
            _buildGroup(type, () => barIndex++),
          if (summary.suitableCareers.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildChips('适合的择业方向', summary.suitableCareers, Colors.green),
          ],
          if (summary.cautiousCareers.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildChips('可能需要谨慎的方向', summary.cautiousCareers, Colors.orange),
          ],
          const SizedBox(height: 16),
          const Text('成长建议',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          for (final r in widget.recommendations) Text('• $r'),
          if (widget.onRetake != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('retake_assessment'),
              onPressed: widget.onRetake,
              child: const Text('重新测评（更新结果）'),
            ),
          ],
          if (widget.onHistory != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('history_list'),
              onPressed: widget.onHistory,
              child: const Text('历史记录'),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            key: const Key('export_pdf'),
            onPressed:
                widget.onExport == null ? null : () => widget.onExport!(),
            child: const Text('导出 PDF 报告'),
          ),
          if (!_isReview && widget.onLottery != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('lottery'),
              onPressed: widget.onLottery,
              child: const Text('抽奖'),
            ),
          ],
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(_isReview ? '历史结果' : '测评结果')),
      body: reduceMotion
          ? content
          : FadeTransition(
              opacity: _controller,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.02),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _controller,
                  curve: Curves.easeOut,
                )),
                child: content,
              ),
            ),
    );
  }

  Widget _buildOverall(ProfileSummary summary) => Card(
        elevation: 0,
        color: const Color(0xFFF3EFFB),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('总体评价',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(summary.headline, style: const TextStyle(height: 1.5)),
            ],
          ),
        ),
      );

  List<String> _orderedTypes() {
    final present = <String>{
      for (final d in widget.dimensions)
        if (widget.scores.containsKey(d.key)) d.type,
      ...widget.scores.keys.where((k) => _dimensionFor(k) == null),
    };
    return [
      for (final t in _typeOrder)
        if (present.contains(t)) t,
      for (final t in present)
        if (!_typeOrder.contains(t)) t,
    ];
  }

  DimensionInfo? _dimensionFor(String key) {
    for (final d in widget.dimensions) {
      if (d.key == key) return d;
    }
    return null;
  }

  Widget _buildGroup(String type, int Function() nextIndex) {
    final dims = <DimensionInfo>[
      for (final d in widget.dimensions)
        if (d.type == type && widget.scores.containsKey(d.key)) d,
    ];
    final unknown = <String>[
      if (!_typeOrder.contains(type))
        for (final k in widget.scores.keys)
          if (_dimensionFor(k) == null) k,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            _typeTitles[type] ?? '其他',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        for (final d in dims)
          _buildBar(
            d.label,
            d.normalized(widget.scores[d.key]!),
            _format(d, widget.scores[d.key]!),
            d.desc,
            nextIndex(),
          ),
        for (final k in unknown)
          _buildBar(
            k,
            (widget.scores[k]! / 4).clamp(0, 1).toDouble(),
            widget.scores[k]!.toStringAsFixed(1),
            '',
            nextIndex(),
          ),
      ],
    );
  }

  String _format(DimensionInfo d, double value) => d.isChoice
      ? '${(value * 100).round()}%'
      : '${value.toStringAsFixed(1)} / ${d.max}';

  Widget _buildBar(
    String label,
    double value,
    String display,
    String desc,
    int index,
  ) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final start = (index * 0.08).clamp(0.0, 0.6).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text(display, style: const TextStyle(color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 4),
          reduceMotion
              ? LinearProgressIndicator(value: value, minHeight: 10)
              : AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final t = ((_controller.value - start) / (1 - start))
                        .clamp(0.0, 1.0)
                        .toDouble();
                    return LinearProgressIndicator(
                      value: Curves.easeOut.transform(t) * value,
                      minHeight: 10,
                    );
                  },
                ),
          if (desc.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                desc,
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChips(String title, List<String> items, MaterialColor color) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final it in items)
                Chip(
                  label: Text(it),
                  backgroundColor: color.shade50,
                  side: BorderSide(color: color.shade200),
                ),
            ],
          ),
        ],
      );
}
```

- [ ] **Step 4: Run the result tests**

Run: `flutter test test/result_screen_test.dart -r expanded`

Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/ui/result/result_screen.dart test/result_screen_test.dart
git commit -m "feat: add result review mode and staggered bars"
```

---

### Task 6: Stage-completion celebration

**Files:**
- Create: `lib/src/ui/assessment/stage_celebration.dart`
- Modify: `lib/src/ui/assessment/assessment_screen.dart`
- Test: `test/stage_celebration_test.dart` (create)
- Test: `test/assessment_screen_test.dart` (modify)

**Interfaces:**
- Produces: `StageCelebration({required String title, required VoidCallback onTap})`, key `stage_celebration`.
- `AssessmentScreen` gains an internal `_celebrating` state; no public API change.

- [ ] **Step 1: Write the failing celebration tests**

Create `test/stage_celebration_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/ui/assessment/stage_celebration.dart';

void main() {
  testWidgets('calls onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StageCelebration(
            title: '第 2 关 · 认知能力',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('stage_celebration')));
    expect(tapped, isTrue);
  });
}
```

Append to `test/assessment_screen_test.dart` inside `void main()`:

```dart
  testWidgets('shows a stage celebration and continues after skipping',
      (tester) async {
    Map<String, int>? done;
    await tester.pumpWidget(
      MaterialApp(
        home: AssessmentScreen(
          questions: const [
            Question(
              id: 'p1',
              type: 'personality',
              dimension: 'openness',
              text: 'Q1',
              options: ['a', 'b'],
            ),
            Question(
              id: 'i1',
              type: 'iq',
              dimension: 'logic',
              text: 'Q2',
              options: ['a', 'b'],
              kind: 'choice',
              correct: 1,
            ),
          ],
          onDone: (answers) => done = answers,
        ),
      ),
    );

    await tester.tap(find.text('a'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('stage_celebration')), findsOneWidget);

    await tester.tap(find.byKey(const Key('stage_celebration')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stage_celebration')), findsNothing);

    await tester.tap(find.text('a'));
    await tester.pumpAndSettle();
    expect(done, isNotNull);
    expect(done!.length, 2);
  });

  testWidgets('auto-dismisses the celebration after 800ms', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AssessmentScreen(
          questions: const [
            Question(
              id: 'p1',
              type: 'personality',
              dimension: 'openness',
              text: 'Q1',
              options: ['a', 'b'],
            ),
            Question(
              id: 'i1',
              type: 'iq',
              dimension: 'logic',
              text: 'Q2',
              options: ['a', 'b'],
              kind: 'choice',
              correct: 1,
            ),
          ],
          onDone: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('a'));
    await tester.pump();
    expect(find.byKey(const Key('stage_celebration')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byKey(const Key('stage_celebration')), findsNothing);
  });

  testWidgets('skips the celebration when reduce motion is on', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: AssessmentScreen(
            questions: const [
              Question(
                id: 'p1',
                type: 'personality',
                dimension: 'openness',
                text: 'Q1',
                options: ['a', 'b'],
              ),
              Question(
                id: 'i1',
                type: 'iq',
                dimension: 'logic',
                text: 'Q2',
                options: ['a', 'b'],
                kind: 'choice',
                correct: 1,
              ),
            ],
            onDone: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('a'));
    await tester.pump();
    expect(find.byKey(const Key('stage_celebration')), findsNothing);
  });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/stage_celebration_test.dart test/assessment_screen_test.dart -r expanded`

Expected: FAIL because `stage_celebration.dart` does not exist and the overlay is not implemented.

- [ ] **Step 3: Create the celebration widget**

Create `lib/src/ui/assessment/stage_celebration.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Full-screen overlay shown when the assessment advances to a new stage.
///
/// Tapping anywhere dismisses it; the parent also dismisses it on a timer.
class StageCelebration extends StatefulWidget {
  const StageCelebration({
    super.key,
    required this.title,
    required this.onTap,
  });

  final String title;
  final VoidCallback onTap;

  @override
  State<StageCelebration> createState() => _StageCelebrationState();
}

class _StageCelebrationState extends State<StageCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: const Key('stage_celebration'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.45),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              final scale = 0.7 + 0.3 * Curves.easeOutBack.transform(t);
              return Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: _GlowParticlesPainter(t)),
                  Center(
                    child: Opacity(
                      opacity: t.clamp(0.0, 1.0).toDouble(),
                      child: Transform.scale(
                        scale: scale,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.workspace_premium,
                              size: 72,
                              color: Colors.amber,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '点击继续',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
}

class _GlowParticlesPainter extends CustomPainter {
  _GlowParticlesPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint();
    for (var i = 0; i < 12; i++) {
      final angle = math.pi * 2 * i / 12;
      final distance = 60 + 90 * progress;
      final offset =
          center + Offset(math.cos(angle), math.sin(angle)) * distance;
      paint.color = Colors.amber.withValues(alpha: (1 - progress) * 0.8);
      canvas.drawCircle(offset, 5 * (1 - progress) + 1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GlowParticlesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
```

- [ ] **Step 4: Replace the assessment screen**

Replace `lib/src/ui/assessment/assessment_screen.dart` with:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import '../../models/question.dart';
import '../../services/audio_service.dart';
import 'stage_celebration.dart';

class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({
    super.key,
    required this.questions,
    required this.onDone,
    this.audio,
  });
  final List<Question> questions;
  final void Function(Map<String, int> answers) onDone;

  /// Optional feedback sounds + background-music toggle.
  final AudioService? audio;

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  int _i = 0;
  final Map<String, int> _answers = {};

  /// Blocks further taps briefly after an answer, so an accidental double tap
  /// (or a stray input event) cannot skip a question.
  bool _locked = false;
  static const Duration _lockFor = Duration(milliseconds: 160);

  /// Non-null while the stage-completion overlay is visible.
  String? _celebrating;
  Timer? _celebrationTimer;

  static const Map<String, String> _stageTitles = {
    'personality': '第 1 关 · 人格特质',
    'iq': '第 2 关 · 认知能力',
    'eq': '第 3 关 · 情商',
    'interest': '第 4 关 · 职业兴趣',
  };

  @override
  void initState() {
    super.initState();
    if (widget.questions.isEmpty) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => widget.onDone(const {}));
    }
  }

  @override
  void dispose() {
    _celebrationTimer?.cancel();
    super.dispose();
  }

  void _answer(int value) {
    if (_locked || _celebrating != null || widget.questions.isEmpty) return;
    _locked = true;
    final q = widget.questions[_i];
    _answers[q.id] = value;
    widget.audio?.tap();

    if (_i == widget.questions.length - 1) {
      widget.onDone(Map<String, int>.of(_answers));
      return;
    }

    final nextType = widget.questions[_i + 1].type;
    setState(() => _i++);
    if (nextType != q.type) {
      widget.audio?.stageComplete();
      final title = _stageTitles[nextType];
      if (title != null && !MediaQuery.of(context).disableAnimations) {
        _celebrationTimer?.cancel();
        setState(() => _celebrating = title);
        _celebrationTimer =
            Timer(const Duration(milliseconds: 800), _dismissCelebration);
      }
    }
    Future.delayed(_lockFor, () {
      if (mounted) _locked = false;
    });
  }

  void _dismissCelebration() {
    _celebrationTimer?.cancel();
    _celebrationTimer = null;
    if (!mounted || _celebrating == null) return;
    setState(() => _celebrating = null);
  }

  void _back() {
    if (_i == 0) return;
    widget.audio?.back();
    setState(() => _i--);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return const Scaffold(body: Center(child: Text('暂无题目')));
    }
    final q = widget.questions[_i];
    final total = widget.questions.length;
    final stage = _stageTitles[q.type] ?? '测评';
    final audio = widget.audio;
    return Scaffold(
      appBar: AppBar(
        title: Text('测评 ${_i + 1}/$total'),
        leading: _i > 0
            ? IconButton(
                key: const Key('assess_back'),
                icon: const Icon(Icons.arrow_back),
                tooltip: '上一题',
                onPressed: _back,
              )
            : null,
        actions: [
          if (audio != null)
            IconButton(
              key: const Key('music_toggle'),
              tooltip: audio.musicOn ? '关闭音乐' : '开启音乐',
              icon: Icon(audio.musicOn ? Icons.music_note : Icons.music_off),
              onPressed: () async {
                await audio.setMusic(!audio.musicOn);
                if (mounted) setState(() {});
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(children: [
            LinearProgressIndicator(
              value: (_i + 1) / total,
              minHeight: 6,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(stage,
                    style: const TextStyle(
                        color: Colors.deepPurple, fontSize: 13)),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.06, 0),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: Column(
                  key: ValueKey(_i),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child:
                          Text(q.text, style: const TextStyle(fontSize: 20)),
                    ),
                    for (var i = 0; i < q.options.length; i++)
                      ListTile(
                        title: Text(q.options[i]),
                        onTap: () => _answer(i + 1),
                      ),
                  ],
                ),
              ),
            ),
          ]),
          if (_celebrating != null)
            Positioned.fill(
              child: StageCelebration(
                title: _celebrating!,
                onTap: _dismissCelebration,
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run the celebration tests**

Run: `flutter test test/stage_celebration_test.dart test/assessment_screen_test.dart -r expanded`

Expected: PASS (5 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/src/ui/assessment/stage_celebration.dart lib/src/ui/assessment/assessment_screen.dart test/stage_celebration_test.dart test/assessment_screen_test.dart
git commit -m "feat: celebrate completing each assessment stage"
```

---

### Task 7: Lottery confetti

**Files:**
- Create: `lib/src/ui/widgets/confetti.dart`
- Modify: `lib/src/app.dart` (prize dialog only)
- Test: `test/confetti_test.dart` (create)

**Interfaces:**
- Produces: `Confetti({int particles = 20, Duration duration = const Duration(seconds: 2)})`, key `confetti`.

- [ ] **Step 1: Write the failing confetti tests**

Create `test/confetti_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/ui/widgets/confetti.dart';

void main() {
  testWidgets('renders confetti when animations are enabled', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 300, height: 300, child: Confetti()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('confetti')), findsOneWidget);
  });

  testWidgets('hides confetti when animations are disabled', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: SizedBox(width: 300, height: 300, child: Confetti()),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('confetti')), findsNothing);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/confetti_test.dart -r expanded`

Expected: FAIL because `confetti.dart` does not exist.

- [ ] **Step 3: Implement the confetti widget**

Create `lib/src/ui/widgets/confetti.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Lightweight falling-confetti animation drawn with a [CustomPainter].
class Confetti extends StatefulWidget {
  const Confetti({
    super.key,
    this.particles = 20,
    this.duration = const Duration(seconds: 2),
  });

  final int particles;
  final Duration duration;

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          key: const Key('confetti'),
          painter: _ConfettiPainter(_controller.value, widget.particles),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.progress, this.count);

  final double progress;
  final int count;

  static const _colors = [
    Colors.amber,
    Colors.pinkAccent,
    Colors.lightBlueAccent,
    Colors.greenAccent,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      final lane = (i + 0.5) / count;
      final x = size.width * lane + math.sin(progress * math.pi * 4 + i) * 12;
      final y = -20 + (size.height + 40) * ((progress + i * 0.05) % 1.0);
      paint.color = _colors[i % _colors.length].withValues(alpha: 1 - progress);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * math.pi * 2 + i);
      canvas.drawRect(const Rect.fromLTWH(-4, -3, 8, 6), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.count != count;
}
```

- [ ] **Step 4: Run the confetti tests**

Run: `flutter test test/confetti_test.dart -r expanded`

Expected: PASS (2 tests).

- [ ] **Step 5: Add confetti to the prize dialog**

In `lib/src/app.dart`, add the import:

```dart
import 'ui/widgets/confetti.dart';
```

Replace the `_PrizeDialogState` class with:

```dart
class _PrizeDialogState extends State<_PrizeDialog> {
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _revealed = true);
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('抽奖'),
        content: SizedBox(
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_revealed) const Positioned.fill(child: Confetti()),
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale:
                        CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: _revealed
                      ? Column(
                          key: const ValueKey('prize'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.emoji_events,
                                size: 44, color: Colors.amber),
                            const SizedBox(height: 8),
                            Text('恭喜获得：${widget.prize.name}',
                                style: const TextStyle(fontSize: 18)),
                          ],
                        )
                      : const Column(
                          key: ValueKey('drawing'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('抽奖中…'),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      );
}
```

- [ ] **Step 6: Run the confetti tests and analyzer**

Run: `flutter test test/confetti_test.dart -r expanded`

Expected: PASS (2 tests).

- [ ] **Step 7: Commit**

```bash
git add lib/src/ui/widgets/confetti.dart lib/src/app.dart test/confetti_test.dart
git commit -m "feat: add confetti to the lottery reveal"
```

---

### Task 8: Wire profile review/retake into the root flow

**Files:**
- Modify: `lib/src/app.dart`
- Test: `test/returning_user_test.dart` (create)
- Test: `test/integration_flow_test.dart` (modify)

**Interfaces:**
- Consumes: `AppCoordinator.latestResult`, `resultHistory`, `ProfileActionSheet`, `HistoryScreen`, `ResultScreen.reviewedAt/onRetake/onHistory`.
- Produces: profile tap opens the action sheet when history exists; result review navigation.

- [ ] **Step 1: Write the failing returning-user test**

Create `test/returning_user_test.dart`:

```dart
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
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/returning_user_test.dart -r expanded`

Expected: FAIL because the profile tap still goes straight to the assessment and the sheet keys do not exist.

- [ ] **Step 3: Add imports and review state to `app.dart`**

Add these imports next to the existing `ui/` imports:

```dart
import 'models/assessment_record.dart';
import 'ui/onboarding/profile_action_sheet.dart';
import 'ui/result/history_screen.dart';
```

Add the review state field next to `_pausedAt`:

```dart
  DateTime? _pausedAt;
  DateTime? _viewedAt;
```

In `_lock`, reset it inside the existing `setState`:

```dart
    setState(() {
      _stage = _Stage.profiles;
      _scores = const {};
      _recommendations = const [];
      _viewedAt = null;
    });
```

- [ ] **Step 4: Add profile routing methods**

Insert these methods in `_RootFlowState` after `_drawLottery` and before `build`:

```dart
  Future<void> _selectProfile(int index) async {
    _c.activeProfile = index;

    AssessmentRecord? latest;
    var history = const <AssessmentRecord>[];
    try {
      latest = await _c.latestResult();
      history = await _c.resultHistory();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('读取历史失败')),
      );
      return;
    }
    if (!mounted) return;

    final record = latest;
    if (record == null) {
      setState(() {
        _viewedAt = null;
        _stage = _Stage.assessment;
      });
      return;
    }

    final action = await showModalBottomSheet<ProfileAction>(
      context: context,
      showDragHandle: true,
      builder: (_) => ProfileActionSheet(
        profileName: _activeName,
        lastFinishedAt: record.finishedAt,
        historyCount: history.length,
      ),
    );
    if (!mounted || action == null) return;

    switch (action) {
      case ProfileAction.viewLatest:
        await _openRecord(record);
      case ProfileAction.retake:
        setState(() {
          _viewedAt = null;
          _stage = _Stage.assessment;
        });
      case ProfileAction.history:
        await _openHistory();
    }
  }

  Future<void> _openRecord(AssessmentRecord record) async {
    try {
      final recs = await _c.recommendations(record.scores);
      if (!mounted) return;
      setState(() {
        _scores = record.scores;
        _recommendations = recs;
        _viewedAt = record.finishedAt;
        _stage = _Stage.result;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('读取历史失败')),
      );
    }
  }

  Future<void> _openHistory() async {
    var records = const <AssessmentRecord>[];
    try {
      records = await _c.resultHistory();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('读取历史失败')),
      );
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => HistoryScreen(
          records: records,
          dimensions: _c.dimensions,
          careers: _c.careers,
          onOpen: (record) {
            Navigator.of(context).pop();
            _openRecord(record);
          },
        ),
      ),
    );
  }
```

- [ ] **Step 5: Replace the profile and result cases**

In `build`, change the profiles case to:

```dart
      case _Stage.profiles:
        return ProfileSelectScreen(
          names: _c.profileNames,
          onSelect: _selectProfile,
          onCreate: (name) async {
            await _c.createProfile(name, randomSalt());
            if (!mounted) return;
            setState(() {});
          },
        );
```

Change the result case to:

```dart
      case _Stage.result:
        return ResultScreen(
          profileName: _activeName,
          scores: _scores,
          recommendations: _recommendations,
          dimensions: _c.dimensions,
          careers: _c.careers,
          reviewedAt: _viewedAt,
          onExport: widget.onExport ?? _defaultExport,
          onLottery: _viewedAt == null ? _drawLottery : null,
          onRetake: () => setState(() {
            _viewedAt = null;
            _stage = _Stage.assessment;
          }),
          onHistory: _openHistory,
        );
```

- [ ] **Step 6: Reset review state after a fresh assessment**

In `_finishAssessment`, inside the existing `setState`, add `_viewedAt = null;`:

```dart
      setState(() {
        _scores = scores;
        _recommendations = recs;
        _viewedAt = null;
        _stage = _Stage.result;
      });
```

- [ ] **Step 7: Update the integration helper for celebration and async profile selection**

In `test/integration_flow_test.dart`, replace `_answerAll` with:

```dart
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
```

In both existing tests, replace the direct profile taps with `_act` so the real database queries complete:

```dart
    await _act(tester, () => tester.tap(find.text('孩子A')));
```

There are two occurrences (full flow and failure test). Replace both.

- [ ] **Step 8: Run the returning-user and integration tests**

Run: `flutter test test/returning_user_test.dart test/integration_flow_test.dart -r expanded`

Expected: PASS (5 tests total).

- [ ] **Step 9: Commit**

```bash
git add lib/src/app.dart test/returning_user_test.dart test/integration_flow_test.dart
git commit -m "feat: route returning profiles to review or retake"
```

---

### Task 9: Full verification

- [ ] **Step 1: Run the full test suite**

Run: `flutter test`

Expected: all tests pass, including the new history, animation, and returning-user tests.

- [ ] **Step 2: Run the analyzer**

Run: `flutter analyze`

Expected: no new errors or warnings introduced by these tasks. Fix any that appear before committing.

- [ ] **Step 3: Manual smoke check**

Run: `flutter run`

Verify:
1. Complete a full assessment; each stage change shows the celebration and can be skipped.
2. Result page bars animate in; lottery reveal adds confetti.
3. Return to the profile list, tap the same profile, and see the review/retake sheet.
4. Review mode shows the banner, hides lottery, and the history list opens past attempts.
5. Enable the system "remove animations" setting; celebration/confetti disappear and bars render immediately.

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "test: verify animation and history flow end to end"
```
