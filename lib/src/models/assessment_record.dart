import 'dart:convert';

/// One persisted assessment attempt for a profile.
///
/// [answers] is non-null only for the newest attempt: saving a new result
/// clears the answer sheet on older rows.
class AssessmentRecord {
  const AssessmentRecord({
    required this.id,
    required this.finishedAt,
    required this.scores,
    this.answers,
  });

  final int id;
  final DateTime finishedAt;
  final Map<String, double> scores;
  final Map<String, int>? answers;

  /// Parses a database row, returning `null` when `score_json` is invalid or
  /// contains no numeric values.
  static AssessmentRecord? tryFromRow(Map<String, Object?> row) {
    try {
      final decoded = jsonDecode(row['score_json'] as String? ?? '');
      if (decoded is! Map) return null;

      final scores = <String, double>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is num) scores[entry.key as String] = value.toDouble();
      }
      if (scores.isEmpty) return null;

      final rawAnswers = row['answers_json'] as String?;
      Map<String, int>? answers;
      if (rawAnswers != null && rawAnswers.isNotEmpty) {
        final decodedAnswers = jsonDecode(rawAnswers);
        if (decodedAnswers is Map) {
          answers = {
            for (final entry in decodedAnswers.entries)
              if (entry.value is num)
                entry.key as String: (entry.value as num).toInt(),
          };
        }
      }

      return AssessmentRecord(
        id: row['id'] as int,
        finishedAt: DateTime.fromMillisecondsSinceEpoch(
          (row['finished_at'] as num?)?.toInt() ?? 0,
        ),
        scores: scores,
        answers: answers,
      );
    } catch (_) {
      return null;
    }
  }
}
