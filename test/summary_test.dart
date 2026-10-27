import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/models/career.dart';
import 'package:discover_self/src/models/dimension.dart';
import 'package:discover_self/src/services/summary.dart';

void main() {
  const dims = [
    DimensionInfo(
      key: 'a',
      label: '开放性',
      type: 'personality',
      kind: 'likert',
      max: 5,
    ),
    DimensionInfo(
      key: 'b',
      label: '尽责性',
      type: 'personality',
      kind: 'likert',
      max: 5,
    ),
    DimensionInfo(
      key: 'c',
      label: '情绪稳定性',
      type: 'personality',
      kind: 'likert',
      max: 5,
    ),
    DimensionInfo(
      key: 'logic',
      label: '逻辑推理',
      type: 'iq',
      kind: 'choice',
      max: 1,
    ),
  ];
  const careers = [
    CareerItem(dimension: 'a', min: 3.5, careers: ['设计师', '产品经理']),
    CareerItem(dimension: 'b', min: 3.5, careers: ['项目管理', '设计师']),
    CareerItem(dimension: 'c', min: 3.5, careers: ['风控']),
  ];

  test('ranks strengths highest and watchouts lowest by normalized score', () {
    final s = buildSummary(
      scores: {'a': 5.0, 'b': 4.0, 'c': 2.0, 'logic': 0.5},
      dimensions: dims,
      careers: careers,
    );
    // Normalized order: a 1.0, b 0.8, logic 0.5, c 0.4.
    expect(s.strengths.map((d) => d.key), ['a', 'b', 'logic']);
    expect(s.watchouts.map((d) => d.key), ['c']);
    expect(s.accuracy, 50);
  });

  test('choice scores outrank low Likert scores after normalization', () {
    final s = buildSummary(
      scores: {'logic': 0.9, 'c': 2.0},
      dimensions: dims,
      careers: careers,
      strengthCount: 1,
      watchoutCount: 1,
    );
    expect(s.strengths.map((d) => d.key), contains('logic'));
    expect(s.watchouts.map((d) => d.key), contains('c'));
    final strengthKeys = s.strengths.map((d) => d.key).toSet();
    final watchoutKeys = s.watchouts.map((d) => d.key).toSet();
    expect(strengthKeys.intersection(watchoutKeys), isEmpty);
  });

  test('aggregates careers from strengths, de-duplicated', () {
    final s = buildSummary(
      scores: {'a': 5.0, 'b': 4.0, 'c': 2.0},
      dimensions: dims,
      careers: careers,
    );
    expect(s.suitableCareers, containsAll(<String>['设计师', '产品经理', '项目管理']));
    // '设计师' appears under both a and b but only once.
    expect(s.suitableCareers.where((c) => c == '设计师').length, 1);
  });

  test('headline mentions the strength labels', () {
    final s = buildSummary(
      scores: {'a': 5.0, 'b': 1.0, 'c': 1.0},
      dimensions: dims,
      careers: careers,
    );
    expect(s.headline, contains('开放性'));
  });
}
