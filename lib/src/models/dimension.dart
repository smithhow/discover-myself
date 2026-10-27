/// Metadata about one assessment dimension, from `assets/data/models.json`.
///
/// [type] groups dimensions for display (`personality`, `iq`, `eq`,
/// `interest`). [kind] matches [Question.kind] so the UI knows whether the
/// score is a Likert mean (`1..max`) or a correctness fraction (`0..1`).
class DimensionInfo {
  final String key;
  final String label;
  final String type;
  final String kind;
  final int max;
  final double threshold;

  /// Plain-language explanation of what this dimension measures.
  final String desc;

  const DimensionInfo({
    required this.key,
    required this.label,
    required this.type,
    required this.kind,
    this.max = 5,
    this.threshold = 3.5,
    this.desc = '',
  });

  bool get isChoice => kind == 'choice';

  double normalized(double value) =>
      isChoice ? value.clamp(0, 1).toDouble() : (value / max).clamp(0, 1).toDouble();

  factory DimensionInfo.fromJson(Map<String, dynamic> j) => DimensionInfo(
        key: j['key'] as String,
        label: j['label'] as String,
        type: (j['type'] as String?) ?? 'personality',
        kind: (j['kind'] as String?) ?? 'likert',
        max: (j['max'] as num?)?.toInt() ?? 5,
        threshold: (j['threshold'] as num?)?.toDouble() ?? 3.5,
        desc: (j['desc'] as String?) ?? '',
      );
}
