class QuestionOption {
  final String label;
  final int value;
  const QuestionOption(this.label, this.value);
}

class Question {
  final String id;
  final String type;
  final String dimension;
  final String text;
  final List<String> options;
  const Question({required this.id, required this.type, required this.dimension, required this.text, required this.options});

  factory Question.fromJson(Map<String, dynamic> j) => Question(
        id: j['id'] as String,
        type: j['type'] as String,
        dimension: j['dimension'] as String,
        text: j['text'] as String,
        options: (j['options'] as List).cast<String>(),
      );

  List<QuestionOption> toOptions() => [
        for (var i = 0; i < options.length; i++) QuestionOption(options[i], i + 1),
      ];
}
