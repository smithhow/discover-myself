import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/models/dimension.dart';
import 'package:discover_self/src/models/guidance.dart';
import 'package:discover_self/src/services/guidance.dart';

const _dims = [
  DimensionInfo(key: 'leadership_drive', label: '领导意愿', type: 'workstyle', kind: 'likert', max: 1),
  DimensionInfo(key: 'execution_focus', label: '执行偏好', type: 'workstyle', kind: 'likert', max: 1),
  DimensionInfo(key: 'adaptability', label: '变化适应', type: 'workstyle', kind: 'likert', max: 1),
  DimensionInfo(key: 'enterprising', label: '企业型 E', type: 'interest', kind: 'likert', max: 1),
  DimensionInfo(key: 'social_skills', label: '社交技能', type: 'eq', kind: 'likert', max: 1),
  DimensionInfo(key: 'emotional_stability', label: '情绪稳定性', type: 'personality', kind: 'likert', max: 1),
  DimensionInfo(key: 'self_regulation', label: '情绪调节', type: 'eq', kind: 'likert', max: 1),
  DimensionInfo(key: 'conscientiousness', label: '尽责性', type: 'personality', kind: 'likert', max: 1),
  DimensionInfo(key: 'conventional', label: '常规型 C', type: 'interest', kind: 'likert', max: 1),
  DimensionInfo(key: 'investigative', label: '研究型 I', type: 'interest', kind: 'likert', max: 1),
  DimensionInfo(key: 'artistic', label: '艺术型 A', type: 'interest', kind: 'likert', max: 1),
  DimensionInfo(key: 'openness', label: '开放性', type: 'personality', kind: 'likert', max: 1),
  DimensionInfo(key: 'motivation', label: '内在动机', type: 'eq', kind: 'likert', max: 1),
  DimensionInfo(key: 'empathy', label: '共情', type: 'eq', kind: 'likert', max: 1),
  DimensionInfo(key: 'social', label: '社会型 S', type: 'interest', kind: 'likert', max: 1),
  DimensionInfo(key: 'logic', label: '逻辑推理', type: 'iq', kind: 'choice', max: 1),
];

Map<String, double> _scores([Map<String, double> overrides = const {}]) => {
  for (final d in _dims) d.key: 0.5,
  ...overrides,
};

final _content = GuidanceContent(
  clusters: [
    MajorCluster(
      name: '计算机与人工智能',
      summary: '编程、算法与数据。',
      majors: const ['软件工程', '人工智能'],
      weights: const {'investigative': 0.5, 'logic': 0.5},
      minimums: const {'logic': 0.5},
    ),
    MajorCluster(
      name: '教育与心理',
      summary: '理解人、帮助人成长。',
      majors: const ['教育学', '心理学'],
      weights: const {'social': 0.5, 'empathy': 0.5},
      minimums: const {},
    ),
  ],
  careers: [
    CareerAdviceItem(
      name: '软件工程师',
      cluster: '计算机与人工智能',
      weights: const {'investigative': 0.5, 'logic': 0.5},
      entry: '从编程实习或初级开发岗位进入。',
    ),
    CareerAdviceItem(
      name: '教师',
      cluster: '教育与心理',
      weights: const {'social': 0.5, 'empathy': 0.5},
      entry: '从教学实习或教育机构岗位进入。',
    ),
  ],
);

GuidanceReport _report(Map<String, double> scores) =>
    buildGuidance(scores: scores, dimensions: _dims, content: _content);

LeadershipType _typeFor(Map<String, double> overrides) =>
    _report(_scores(overrides)).leadership.type;

void main() {
  test('classifies hybrid when leadership and execution are both high', () {
    expect(
      _typeFor({
        'leadership_drive': 0.8,
        'enterprising': 0.8,
        'social_skills': 0.8,
        'emotional_stability': 0.8,
        'self_regulation': 0.8,
        'execution_focus': 0.8,
        'conscientiousness': 0.8,
        'conventional': 0.8,
      }),
      LeadershipType.hybrid,
    );
  });

  test('classifies leader when leadership is high and execution is not', () {
    expect(
      _typeFor({
        'leadership_drive': 0.8,
        'enterprising': 0.8,
        'social_skills': 0.8,
      }),
      LeadershipType.leader,
    );
  });

  test('classifies specialist when professional depth is high and leadership low',
      () {
    expect(
      _typeFor({
        'leadership_drive': 0.3,
        'enterprising': 0.3,
        'social_skills': 0.3,
        'investigative': 0.95,
        'artistic': 0.9,
        'openness': 0.9,
        'motivation': 0.9,
        'execution_focus': 0.8,
        'conscientiousness': 0.8,
      }),
      LeadershipType.specialist,
    );
  });

  test('specialist reasons cite the dominant professional dimensions', () {
    final report = _report(_scores({
      'leadership_drive': 0.3,
      'enterprising': 0.3,
      'social_skills': 0.3,
      'investigative': 0.95,
      'artistic': 0.9,
      'openness': 0.9,
      'motivation': 0.9,
      'execution_focus': 0.8,
      'conscientiousness': 0.8,
    }));
    expect(report.leadership.type, LeadershipType.specialist);
    expect(report.leadership.professionalDepth, greaterThan(0.65));
    expect(report.leadership.reasons.any((r) => r.contains('研究型')), isTrue);
  });

  test('leader reasons cite the dominant leadership dimensions', () {
    final report = _report(_scores({
      'leadership_drive': 0.8,
      'enterprising': 0.8,
      'social_skills': 0.8,
    }));
    expect(report.leadership.type, LeadershipType.leader);
    expect(report.leadership.reasons.any((r) => r.contains('领导意愿')), isTrue);
  });

  test('classifies executor when execution is high and professional depth is low',
      () {
    expect(
      _typeFor({
        'leadership_drive': 0.3,
        'enterprising': 0.3,
        'social_skills': 0.3,
        'investigative': 0.4,
        'artistic': 0.4,
        'openness': 0.4,
        'motivation': 0.4,
        'execution_focus': 0.85,
        'conscientiousness': 0.85,
        'self_regulation': 0.85,
        'conventional': 0.85,
      }),
      LeadershipType.executor,
    );
  });

  test('classifies explorer when all indices are low', () {
    final scores = {
      for (final d in _dims) d.key: 0.25,
    };
    expect(_report(scores).leadership.type, LeadershipType.explorer);
  });

  test('ranks majors by normalized weighted fit', () {
    final report = _report(_scores({
      'investigative': 0.9,
      'logic': 0.8,
      'social': 0.3,
      'empathy': 0.3,
    }));
    expect(report.majors.first.cluster, '计算机与人工智能');
    expect(report.majors.first.fit, closeTo(0.85, 1e-9));
    expect(report.careers.first.name, '软件工程师');
  });

  test('applies the minimum penalty and explains every unmet minimum', () {
    final content = GuidanceContent(
      clusters: [
        MajorCluster(
          name: '测试方向',
          summary: '',
          majors: const ['测试专业'],
          weights: const {'investigative': 0.5, 'logic': 0.5},
          minimums: const {'logic': 0.8},
        ),
      ],
      careers: const [],
    );
    final report = buildGuidance(
      scores: _scores({'investigative': 1.0, 'logic': 0.5}),
      dimensions: _dims,
      content: content,
    );
    expect(report.majors.single.fit, closeTo(0.6375, 1e-9));
    expect(
      report.majors.single.caution,
      contains('该方向通常需要较强的逻辑推理'),
    );
    expect(report.majors.single.caution, contains('你当前为 50%'));
  });

  test('renormalizes when a weight key has no score', () {
    final content = GuidanceContent(
      clusters: [
        MajorCluster(
          name: '缺数据方向',
          summary: '',
          majors: const ['测试专业'],
          weights: const {'investigative': 0.5, 'unknown_key': 0.5},
          minimums: const {},
        ),
      ],
      careers: const [],
    );
    final report = buildGuidance(
      scores: _scores({'investigative': 1.0}),
      dimensions: _dims,
      content: content,
    );
    expect(report.majors.single.fit, closeTo(1.0, 1e-9));
  });

  test('degrades gracefully when workstyle dimensions are missing', () {
    final scores = _scores()
      ..remove('leadership_drive')
      ..remove('execution_focus')
      ..remove('adaptability');
    final report = _report(scores);
    expect(report.hasWorkstyle, isFalse);
    expect(report.leadership.leadership, inInclusiveRange(0.0, 1.0));
  });

  test('reasons use the top contributing dimensions', () {
    final content = GuidanceContent(
      clusters: [
        MajorCluster(
          name: '研究型方向',
          summary: '',
          majors: const ['测试专业'],
          weights: const {'investigative': 0.7, 'logic': 0.3},
          minimums: const {},
        ),
      ],
      careers: const [],
    );
    final report = buildGuidance(
      scores: _scores({'investigative': 0.9, 'logic': 0.2}),
      dimensions: _dims,
      content: content,
    );
    expect(report.majors.single.reasons.first, contains('研究型'));
  });

  test('ties keep content-library order', () {
    final content = GuidanceContent(
      clusters: [
        MajorCluster(
          name: '第一',
          summary: '',
          majors: const ['A'],
          weights: const {'openness': 1.0},
          minimums: const {},
        ),
        MajorCluster(
          name: '第二',
          summary: '',
          majors: const ['B'],
          weights: const {'openness': 1.0},
          minimums: const {},
        ),
      ],
      careers: const [],
    );
    final report = buildGuidance(
      scores: _scores({'openness': 0.7}),
      dimensions: _dims,
      content: content,
    );
    expect(report.majors.map((m) => m.cluster), ['第一', '第二']);
  });

  test('builds four next steps for a complete report', () {
    final report = _report(_scores());
    expect(report.nextSteps.length, 4);
    expect(report.nextSteps.first, contains('计算机与人工智能'));
  });
}
