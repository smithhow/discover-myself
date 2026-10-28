import '../models/dimension.dart';
import '../models/guidance.dart';

const Map<String, double> _leadershipWeights = {
  'leadership_drive': 0.30,
  'enterprising': 0.20,
  'social_skills': 0.20,
  'emotional_stability': 0.15,
  'self_regulation': 0.15,
};

const Map<String, double> _executionWeights = {
  'execution_focus': 0.30,
  'conscientiousness': 0.25,
  'self_regulation': 0.20,
  'conventional': 0.15,
  'emotional_stability': 0.10,
};

const Map<String, double> _professionalWeights = {
  'investigative': 0.30,
  'artistic': 0.20,
  'openness': 0.20,
  'motivation': 0.15,
  'execution_focus': 0.15,
};

const List<String> _workstyleKeys = [
  'leadership_drive',
  'execution_focus',
  'adaptability',
];

/// Builds a guidance report from one profile's raw scores.
GuidanceReport buildGuidance({
  required Map<String, double> scores,
  required List<DimensionInfo> dimensions,
  required GuidanceContent content,
}) {
  final norms = <String, double>{};
  for (final dimension in dimensions) {
    final score = scores[dimension.key];
    if (score != null) norms[dimension.key] = dimension.normalized(score);
  }

  final majorRanked = <_Ranked<MajorFit>>[];
  for (var i = 0; i < content.clusters.length; i++) {
    final cluster = content.clusters[i];
    final result = _fit(
      weights: cluster.weights,
      minimums: cluster.minimums,
      norms: norms,
      dimensions: dimensions,
    );
    if (result == null) continue;
    majorRanked.add(
      _Ranked(
        i,
        MajorFit(
          cluster: cluster.name,
          summary: cluster.summary,
          majors: cluster.majors,
          fit: result.fit,
          reasons: result.reasons,
          caution: result.caution,
        ),
      ),
    );
  }

  final careerRanked = <_Ranked<CareerFit>>[];
  for (var i = 0; i < content.careers.length; i++) {
    final career = content.careers[i];
    final result = _fit(
      weights: career.weights,
      minimums: const {},
      norms: norms,
      dimensions: dimensions,
    );
    if (result == null) continue;
    careerRanked.add(
      _Ranked(
        i,
        CareerFit(
          name: career.name,
          cluster: career.cluster,
          fit: result.fit,
          reasons: result.reasons,
          entry: career.entry,
        ),
      ),
    );
  }

  final leadership = _index(_leadershipWeights, norms);
  final execution = _index(_executionWeights, norms);
  final professional = _index(_professionalWeights, norms);
  final type = _classify(leadership, execution, professional);
  final tips = _tips(type);
  final reasonWeights = professional >= leadership && professional >= execution
      ? _professionalWeights
      : execution >= leadership
      ? _executionWeights
      : _leadershipWeights;
  final reasons = _leadershipReasons(norms, dimensions, reasonWeights);

  final majors = _top(majorRanked, (m) => m.fit, 5);
  final careers = _top(careerRanked, (c) => c.fit, 8);

  final nextSteps = <String>[
    if (majors.isNotEmpty)
      '先了解「${majors.first.cluster}」下${majors.first.majors.take(2).join('、')}的课程设置与就业方向。',
    if (careers.isNotEmpty)
      '找 1-2 位「${careers.first.name}」从业者做信息访谈，确认日常工作内容。',
    tips.first,
    '用 3 个月做一次小范围尝试（课程/社团/实习），再回来复测。',
  ];

  return GuidanceReport(
    majors: majors,
    careers: careers,
    leadership: LeadershipProfile(
      type: type,
      leadership: leadership,
      execution: execution,
      professionalDepth: professional,
      reasons: reasons,
      tips: tips,
    ),
    nextSteps: nextSteps,
    hasWorkstyle: _workstyleKeys.every(scores.containsKey),
  );
}

class _FitResult {
  _FitResult(this.fit, this.reasons, this.caution);

  final double fit;
  final List<String> reasons;
  final String? caution;
}

class _Ranked<T> {
  _Ranked(this.index, this.value);

  final int index;
  final T value;
}

_FitResult? _fit({
  required Map<String, double> weights,
  required Map<String, double> minimums,
  required Map<String, double> norms,
  required List<DimensionInfo> dimensions,
}) {
  final available = <String, double>{};
  var weightSum = 0.0;
  for (final entry in weights.entries) {
    final value = norms[entry.key];
    if (value == null) continue;
    available[entry.key] = value;
    weightSum += entry.value;
  }
  if (available.isEmpty || weightSum <= 0) return null;

  var base = 0.0;
  final contributions = <String, double>{};
  for (final entry in available.entries) {
    final weight = weights[entry.key]!;
    base += weight * entry.value;
    contributions[entry.key] = weight * entry.value;
  }
  base /= weightSum;

  final unmet = <String>[
    for (final entry in minimums.entries)
      if (available.containsKey(entry.key) &&
          available[entry.key]! < entry.value)
        entry.key,
  ];

  final reasons = _reasons(contributions, available, dimensions);
  final caution = unmet.isEmpty
      ? null
      : _caution(unmet, minimums, available, dimensions);
  final fit = (unmet.isEmpty ? base : base * 0.85).clamp(0.0, 1.0).toDouble();

  return _FitResult(fit, reasons, caution);
}

List<String> _reasons(
  Map<String, double> contributions,
  Map<String, double> norms,
  List<DimensionInfo> dimensions,
) {
  final entries = contributions.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [
    for (final entry in entries.take(2))
      '你的${_label(entry.key, dimensions)}（${(norms[entry.key]! * 100).round()}%）与该方向匹配',
  ];
}

String _caution(
  List<String> unmet,
  Map<String, double> minimums,
  Map<String, double> norms,
  List<DimensionInfo> dimensions,
) {
  final parts = <String>[
    for (final key in unmet)
      '${_label(key, dimensions)}（建议 ≥${(minimums[key]! * 100).round()}%，你当前为 ${(norms[key]! * 100).round()}%）',
  ];
  return '该方向通常需要较强的${parts.join('、')}。';
}

String _label(String key, List<DimensionInfo> dimensions) {
  for (final dimension in dimensions) {
    if (dimension.key == key) return dimension.label;
  }
  return key;
}

double _index(Map<String, double> weights, Map<String, double> norms) {
  var sum = 0.0;
  var total = 0.0;
  for (final entry in weights.entries) {
    final value = norms[entry.key];
    if (value == null) continue;
    sum += entry.value * value;
    total += entry.value;
  }
  if (total == 0) return 0.5;
  return (sum / total).clamp(0.0, 1.0).toDouble();
}

LeadershipType _classify(double leadership, double execution, double professional) {
  if (leadership >= 0.65 && execution >= 0.65) return LeadershipType.hybrid;
  if (leadership >= 0.60) return LeadershipType.leader;
  if (professional >= 0.65 && leadership < 0.60) {
    return LeadershipType.specialist;
  }
  if (execution >= 0.60) return LeadershipType.executor;
  return LeadershipType.explorer;
}

List<String> _leadershipReasons(
  Map<String, double> norms,
  List<DimensionInfo> dimensions,
  Map<String, double> weights,
) {
  final contributions = <String, double>{};
  for (final entry in weights.entries) {
    final value = norms[entry.key];
    if (value == null) continue;
    contributions[entry.key] = entry.value * value;
  }
  final entries = contributions.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [
    for (final entry in entries.take(3))
      '${_label(entry.key, dimensions)}（${(norms[entry.key]! * 100).round()}%）',
  ];
}

List<String> _tips(LeadershipType type) => switch (type) {
  LeadershipType.leader => const [
    '从 3-5 人小团队负责人开始，练习目标拆解。',
    '练习授权与反馈，不要替团队把所有事做完。',
    '主动倾听执行层意见，避免只从管理者视角看问题。',
  ],
  LeadershipType.executor => const [
    '发挥可靠交付的优势，成为团队里最稳的落地者。',
    '主动争取小范围决策，逐步扩大责任边界。',
    '补足跨部门沟通与向上管理，让成果被看见。',
  ],
  LeadershipType.specialist => const [
    '持续深耕一个专业领域，建立可验证的作品或成果。',
    '练习把专业内容讲给非专业的人听。',
    '尝试技术带头人/专家路线，而不是过早转纯管理。',
  ],
  LeadershipType.hybrid => const [
    '你既能带人也能落地，优先选择项目制或管理岗。',
    '明确自己的角色边界，避免同时被拉进所有细节。',
    '培养战略视角，把团队目标和业务结果连起来。',
  ],
  LeadershipType.explorer => const [
    '多尝试不同角色，观察自己在哪类任务中更有能量。',
    '先建立一项可交付的硬技能，再谈方向选择。',
    '每 3-6 个月复盘一次，记录让你有成就感的时刻。',
  ],
};

List<T> _top<T>(List<_Ranked<T>> ranked, double Function(T) score, int limit) {
  ranked.sort((a, b) {
    final byScore = score(b.value).compareTo(score(a.value));
    return byScore != 0 ? byScore : a.index.compareTo(b.index);
  });
  return [for (final item in ranked.take(limit)) item.value];
}
