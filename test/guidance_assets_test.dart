import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/services/asset_loader.dart';

Future<Map<String, dynamic>> _json(String name) async {
  final raw = await rootBundle.loadString('assets/data/$name');
  return jsonDecode(raw) as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('majors and careers are complete and internally consistent', () async {
    final dims = await AssetLoader().dimensions();
    final keys = {for (final d in dims) d.key};
    final majorsJson = await _json('majors.json');
    final careersJson = await _json('careers_advice.json');

    final clusters = (majorsJson['clusters'] as List)
        .cast<Map<String, dynamic>>();
    expect(clusters.length, 14);

    final clusterNames = <String>{};
    for (final cluster in clusters) {
      final name = cluster['name'] as String;
      clusterNames.add(name);
      expect(
        (cluster['majors'] as List).length,
        greaterThanOrEqualTo(3),
        reason: name,
      );
      final weights = (cluster['weights'] as Map).cast<String, num>();
      expect(weights.keys, everyElement(isIn(keys)), reason: name);
      expect(
        weights.values.fold<double>(0, (a, b) => a + b.toDouble()),
        closeTo(1.0, 0.001),
        reason: name,
      );
      final minimums = (cluster['minimums'] as Map?)?.cast<String, num>();
      if (minimums != null) {
        for (final entry in minimums.entries) {
          expect(weights.containsKey(entry.key), isTrue, reason: name);
          expect(entry.value, inInclusiveRange(0, 1), reason: name);
        }
      }
    }

    final careers = (careersJson['items'] as List).cast<Map<String, dynamic>>();
    expect(careers.length, greaterThanOrEqualTo(30));
    final names = <String>{};
    for (final career in careers) {
      final name = career['name'] as String;
      expect(names.add(name), isTrue, reason: 'duplicate career: $name');
      expect(clusterNames, contains(career['cluster']), reason: name);
      final weights = (career['weights'] as Map).cast<String, num>();
      expect(weights.keys, everyElement(isIn(keys)), reason: name);
      expect(
        weights.values.fold<double>(0, (a, b) => a + b.toDouble()),
        closeTo(1.0, 0.001),
        reason: name,
      );
      expect((career['entry'] as String).trim(), isNotEmpty, reason: name);
    }

    final byName = {
      for (final c in careers) c['name'] as String: c['cluster'] as String,
    };
    expect(byName['心理咨询师'], '教育与心理');
    expect(byName['UI/UX 设计师'], '传媒、设计与艺术');
  });

  test('AssetLoader parses the guidance content', () async {
    final content = await AssetLoader().guidanceContent();
    expect(content.clusters.length, 14);
    expect(content.careers.length, greaterThanOrEqualTo(30));
  });
}
