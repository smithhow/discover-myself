/// Suggested careers tied to a dimension, from `assets/data/career.json`.
class CareerItem {
  final String dimension;
  final double min;
  final List<String> careers;

  const CareerItem({
    required this.dimension,
    required this.min,
    required this.careers,
  });

  factory CareerItem.fromJson(Map<String, dynamic> j) => CareerItem(
        dimension: j['dimension'] as String,
        min: (j['min'] as num?)?.toDouble() ?? 0,
        careers: (j['careers'] as List).cast<String>(),
      );
}
