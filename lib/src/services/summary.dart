import '../models/career.dart';
import '../models/dimension.dart';

/// A plain-language digest of an assessment result: main strengths, relative
/// watch-outs, and career directions to lean into or approach with care.
class ProfileSummary {
  final String headline;
  final List<DimensionInfo> strengths;
  final List<DimensionInfo> watchouts;
  final List<String> suitableCareers;
  final List<String> cautiousCareers;

  /// Reasoning accuracy percentage (average of choice dimensions), or `null`.
  final int? accuracy;

  const ProfileSummary({
    required this.headline,
    required this.strengths,
    required this.watchouts,
    required this.suitableCareers,
    required this.cautiousCareers,
    this.accuracy,
  });
}

/// Builds a [ProfileSummary] from raw [scores].
///
/// Strengths are the highest-scoring dimensions (by normalized value) and
/// watch-outs the lowest. Careers are aggregated from [careers] for the
/// corresponding dimensions, de-duplicated and capped.
ProfileSummary buildSummary({
  required Map<String, double> scores,
  required List<DimensionInfo> dimensions,
  required List<CareerItem> careers,
  int strengthCount = 3,
  int watchoutCount = 3,
}) {
  final known = <DimensionInfo>[
    for (final d in dimensions)
      if (scores.containsKey(d.key)) d,
  ];

  final ranked = [...known]
    ..sort(
      (a, b) =>
          b.normalized(scores[b.key]!).compareTo(a.normalized(scores[a.key]!)),
    );

  final strengths = ranked.take(strengthCount).toList(growable: false);
  final remaining = ranked.skip(strengths.length).toList(growable: false);
  final watchouts = remaining.isEmpty
      ? const <DimensionInfo>[]
      : remaining.reversed.take(watchoutCount).toList(growable: false);

  final choice = known.where((d) => d.isChoice).toList(growable: false);
  final accuracy = choice.isEmpty
      ? null
      : (choice.map((d) => scores[d.key]!).reduce((a, b) => a + b) /
                choice.length *
                100)
            .round();

  final headline = _headline(strengths, watchouts, accuracy);

  return ProfileSummary(
    headline: headline,
    strengths: strengths,
    watchouts: watchouts,
    suitableCareers: _careersFor(strengths, careers, limit: 8),
    cautiousCareers: _careersFor(watchouts, careers, limit: 5),
    accuracy: accuracy,
  );
}

String _headline(
  List<DimensionInfo> strengths,
  List<DimensionInfo> watchouts,
  int? accuracy,
) {
  final s = strengths.map((d) => d.label).join('、');
  final w = watchouts.map((d) => d.label).join('、');
  final buffer = StringBuffer();
  if (s.isNotEmpty) {
    buffer.write('你的核心优势集中在「$s」');
  } else {
    buffer.write('你的各项表现比较均衡');
  }
  if (w.isNotEmpty) {
    buffer.write('；相对可以提升的是「$w」');
  }
  buffer.write('。');
  if (accuracy != null) {
    buffer.write(' 认知/推理题正确率约 $accuracy%。');
  }
  return buffer.toString();
}

List<String> _careersFor(
  List<DimensionInfo> dims,
  List<CareerItem> careers, {
  required int limit,
}) {
  final keys = {for (final d in dims) d.key};
  final out = <String>[];
  for (final c in careers) {
    if (!keys.contains(c.dimension)) continue;
    for (final name in c.careers) {
      if (!out.contains(name)) out.add(name);
      if (out.length >= limit) return out;
    }
  }
  return out;
}
