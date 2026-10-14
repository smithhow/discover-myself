import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/models/question.dart';
import 'package:discover_self/src/ui/assessment/assessment_screen.dart';

void main() {
  testWidgets('answering all questions calls onDone with answers', (tester) async {
    Map<String, int>? done;
    await tester.pumpWidget(MaterialApp(home: AssessmentScreen(
      questions: const [
        Question(id: 'p1', type: 'personality', dimension: 'openness', text: 'Q1', options: ['a', 'b']),
        Question(id: 'p2', type: 'personality', dimension: 'openness', text: 'Q2', options: ['a', 'b']),
      ],
      onDone: (a) => done = a,
    )));
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('a'));
      await tester.pumpAndSettle();
    }
    expect(done, isNotNull);
    expect(done!.length, 2);
  });
}
