import '../models/question.dart';

class AssessmentService {
  AssessmentService(this.questions);
  final List<Question> questions;

  Map<String, double> score(Map<String, int> answers) {
    final sums = <String, int>{};
    final counts = <String, int>{};
    for (final q in questions) {
      final v = answers[q.id];
      if (v == null) continue;
      sums[q.dimension] = (sums[q.dimension] ?? 0) + v;
      counts[q.dimension] = (counts[q.dimension] ?? 0) + 1;
    }
    return {
      for (final k in sums.keys) k: sums[k]! / counts[k]!,
    };
  }
}
