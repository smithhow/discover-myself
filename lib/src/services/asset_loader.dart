import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/career.dart';
import '../models/dimension.dart';
import '../models/question.dart';
import 'lottery.dart';

/// Loads bundled JSON resources (question bank, prize table, growth tips).
class AssetLoader {
  Future<Map<String, dynamic>> _read(String name) async {
    final raw = await rootBundle.loadString('assets/data/$name');
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// The assessment question bank from `assets/data/questions.json`.
  Future<List<Question>> questions() async {
    final data = await _read('questions.json');
    return (data['items'] as List)
        .map((e) => Question.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Dimension metadata from `assets/data/models.json`.
  Future<List<DimensionInfo>> dimensions() async {
    final data = await _read('models.json');
    return (data['dimensions'] as List)
        .map((e) => DimensionInfo.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Career suggestions from `assets/data/career.json`.
  Future<List<CareerItem>> careers() async {
    final data = await _read('career.json');
    return (data['items'] as List)
        .map((e) => CareerItem.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// The lottery prize table from `assets/data/prizes.json`.
  Future<List<Prize>> prizes() async {
    final data = await _read('prizes.json');
    return (data['items'] as List)
        .map((e) => Prize.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Growth tips whose `dimension` is present in [scores].
  ///
  /// Falls back to every available action when no dimension matches (or when
  /// [scores] is empty) so the report always has content.
  Future<List<String>> recommendations(Map<String, double> scores) async {
    final data = await _read('recommendations.json');
    final items = (data['items'] as List).cast<Map<String, dynamic>>();
    final matched = items
        .where((e) => scores.containsKey(e['dimension']))
        .map((e) => e['action'] as String)
        .toList(growable: false);
    if (matched.isEmpty) {
      return items.map((e) => e['action'] as String).toList(growable: false);
    }
    return matched;
  }
}
