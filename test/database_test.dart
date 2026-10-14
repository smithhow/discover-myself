import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show sqfliteFfiInit, databaseFactoryFfi;
import 'package:discover_self/src/db/database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

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
}
