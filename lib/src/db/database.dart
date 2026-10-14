import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart' as sqflite;

/// Thin wrapper around an encrypted SQLite database.
///
/// Production builds open the database with [sqflite_sqlcipher] and a password
/// derived from the user's key. Tests can inject an unencrypted
/// `sqflite_common_ffi` factory (see [factory]) so the layer runs on the Dart
/// VM without the native plugin.
class Database {
  Database({this.inMemory = false, sqflite.DatabaseFactory? factory})
      // ignore: prefer_initializing_formals
      : _factory = factory;

  /// When true the database is opened in memory instead of on disk.
  final bool inMemory;

  /// Optional factory override used by tests to supply an unencrypted backend.
  final sqflite.DatabaseFactory? _factory;

  sqflite.Database? _db;

  static const String _dbName = 'discover_self.db';

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
        options: sqflite.OpenDatabaseOptions(version: 1, onCreate: _create),
      );
      return;
    }

    final password = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    _db = await sqflite.openDatabase(
      path,
      password: password,
      version: 1,
      onCreate: _create,
    );
  }

  Future<void> _create(sqflite.Database db, int version) async {
    await db.execute(
        'CREATE TABLE users(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, '
        'pin_salt BLOB, created_at INTEGER)');
    await db.execute(
        'CREATE TABLE assessments(id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'profile_id INTEGER, type TEXT, score_json TEXT, finished_at INTEGER)');
    await db.execute(
        'CREATE TABLE achievements(id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'profile_id INTEGER, type TEXT, points INTEGER, earned_at INTEGER)');
    await db.execute(
        'CREATE TABLE lottery_logs(id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'profile_id INTEGER, seed INTEGER, prize_id TEXT, drawn_at INTEGER)');
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
          int profileId, String type, Map<String, int> scores) async =>
      _db!.insert('assessments', {
        'profile_id': profileId,
        'type': type,
        'score_json': jsonEncode(scores),
        'finished_at': DateTime.now().millisecondsSinceEpoch,
      });

  /// Returns the assessment results belonging to [profileId].
  Future<List<Map<String, Object?>>> results(int profileId) async =>
      _db!.query('assessments',
          where: 'profile_id = ?', whereArgs: [profileId]);

  /// Closes the database and releases the handle.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
