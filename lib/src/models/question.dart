class QuestionOption {
  final String label;
  final int value;
  const QuestionOption(this.label, this.value);
}

/// A single assessment question.
///
/// [kind] distinguishes Likert-scale items (`likert`, scored by averaging the
/// chosen option) from items with a correct answer (`choice`, scored by
/// correctness). [reverse] marks reverse-scored Likert items whose value is
/// inverted (`max + 1 - value`) before averaging. [correct] is the 1-based
/// option value that counts as correct for `choice` items.
class Question {
  final String id;
  final String type;
  final String dimension;
  final String text;
  final List<String> options;
  final String kind;
  final bool reverse;
  final int? correct;

  const Question({
    required this.id,
    required this.type,
    required this.dimension,
    required this.text,
    required this.options,
    this.kind = 'likert',
    this.reverse = false,
    this.correct,
  });

  bool get isChoice => kind == 'choice';

  factory Question.fromJson(Map<String, dynamic> j) => Question(
        id: j['id'] as String,
        type: j['type'] as String,
        dimension: j['dimension'] as String,
        text: j['text'] as String,
        options: (j['options'] as List).cast<String>(),
        kind: (j['kind'] as String?) ?? 'likert',
        reverse: (j['reverse'] as bool?) ?? false,
        correct: (j['correct'] as num?)?.toInt(),
      );

  List<QuestionOption> toOptions() => [
        for (var i = 0; i < options.length; i++) QuestionOption(options[i], i + 1),
      ];
}
