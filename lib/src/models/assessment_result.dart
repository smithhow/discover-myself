/// A stored assessment result row from the `assessments` table.
class AssessmentResult {
  /// Row id.
  final int? id;

  /// Owning profile's id.
  final int profileId;

  /// Assessment type, e.g. `personality` or `interest`.
  final String type;

  /// Dimension name to score map.
  final Map<String, int> scores;

  /// Completion time in milliseconds since the epoch.
  final int finishedAt;

  const AssessmentResult({
    this.id,
    required this.profileId,
    required this.type,
    required this.scores,
    required this.finishedAt,
  });
}
