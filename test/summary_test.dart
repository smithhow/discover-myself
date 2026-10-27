import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/models/career.dart';
import 'package:discover_self/src/models/dimension.dart';
import 'package:discover_self/src/services/summary.dart';

void main() {
  const dims = [
    DimensionInfo(key: 'a', label: '开放性', type: 'personality', kind: 'likert', max: 5),
    DimensionInfo(key: 'b', label: '尽责性', type: 'personality', kind: 'likert', max: 5),
    DimensionInfo(key: 'c', label: '情绪稳定性', type: 'personality', kind: 'likert', max: 5),
    DimensionInfo(key: 'logic', label: '逻辑推理', type: 'iq', kind: 'choice', max: 1),
  ];
  const careers = [
    CareerItem(dimension: 'a', min: 3.5, careers: ['设计师', '产品经理']),
    CareerItem(dimension: 'b', min: 3.5, careers: ['项目管理', '设计师']),
    CareerItem(dimension: 'c', min: 3.5, careers: ['风控']),
  ];

  test('ranks strengths highest and watchouts lowest', () {
    final s = buildSummary(
      scores: {'a': 5.0, 'b': 4.0, 'c': 2.0, 'logic': 0.5},
      dimensions: dims,
      careers: careers,
    );
    expect(s.strengths.first.key, 'a');
    // Lowest normalized score is the reasoning dimension (0.5), then 情绪稳定性.
    expect(s.watchouts.first.key, 'logic');
    expect(s.watchouts.map((d) => d.key), contains('c'));
    expect(s.accuracy, 50);
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
