import 'package:flutter/material.dart';
import '../../models/question.dart';

class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({super.key, required this.questions, required this.onDone});
  final List<Question> questions;
  final void Function(Map<String, int> answers) onDone;
  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  int _i = 0;
  final Map<String, int> _answers = {};

  void _answer(int value) {
    final q = widget.questions[_i];
    _answers[q.id] = value;
    if (_i == widget.questions.length - 1) {
      widget.onDone(_answers);
      return;
    }
    setState(() => _i++);
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.questions[_i];
    return Scaffold(
      appBar: AppBar(title: Text('测评 ${_i + 1}/${widget.questions.length}')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Text(q.text, style: const TextStyle(fontSize: 20))),
        for (var i = 0; i < q.options.length; i++)
          ListTile(title: Text(q.options[i]), onTap: () => _answer(i + 1)),
      ]),
    );
  }
}
