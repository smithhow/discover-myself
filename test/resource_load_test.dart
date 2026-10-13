import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Map<String, dynamic>> loadJson(String name) async {
  final s = await rootBundle.loadString('assets/data/$name');
  return jsonDecode(s) as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('questions.json 含 items 数组', () async {
    final data = await loadJson('questions.json');
    expect(data['items'], isA<List>());
  });
}
