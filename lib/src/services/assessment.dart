import '../models/question.dart';

/// Scores assessment answers into a per-dimension result.
///
/// Likert dimensions are averaged (reverse-scored items are inverted first) and
/// therefore range over `1..max`. Choice dimensions (e.g. reasoning items with
/// a correct answer) are scored as the fraction correct, ranging over `0..1`.
/// The scale for a given dimension is described by its `DimensionInfo.kind`.
class AssessmentService {
  AssessmentService(this.questions);
  final List<Question> questions;

  Map<String, double> score(Map<String, int> answers) {
    final likertSum = <String, int>{};
    final likertCount = <String, int>{};
    final choiceCorrect = <String, int>{};
    final choiceTotal = <String, int>{};

    for (final q in questions) {
      final v = answers[q.id];
      if (v == null) continue;

      if (q.isChoice) {
        choiceTotal[q.dimension] = (choiceTotal[q.dimension] ?? 0) + 1;
        if (q.correct != null && v == q.correct) {
          choiceCorrect[q.dimension] = (choiceCorrect[q.dimension] ?? 0) + 1;
        }
      } else {
        final max = q.options.length;
        final adjusted = q.reverse ? (max + 1 - v) : v;
        likertSum[q.dimension] = (likertSum[q.dimension] ?? 0) + adjusted;
        likertCount[q.dimension] = (likertCount[q.dimension] ?? 0) + 1;
      }
    }

    return {
      for (final k in likertSum.keys) k: likertSum[k]! / likertCount[k]!,
      for (final k in choiceTotal.keys)
        k: (choiceCorrect[k] ?? 0) / choiceTotal[k]!,
    };
  }
}
