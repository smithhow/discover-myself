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

  testWidgets('shows a stage celebration and continues after skipping',
      (tester) async {
    Map<String, int>? done;
    await tester.pumpWidget(
      MaterialApp(
        home: AssessmentScreen(
          questions: const [
            Question(
              id: 'p1',
              type: 'personality',
              dimension: 'openness',
              text: 'Q1',
              options: ['a', 'b'],
            ),
            Question(
              id: 'i1',
              type: 'iq',
              dimension: 'logic',
              text: 'Q2',
              options: ['a', 'b'],
              kind: 'choice',
              correct: 1,
            ),
          ],
          onDone: (answers) => done = answers,
        ),
      ),
    );

    await tester.tap(find.text('a'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('stage_celebration')), findsOneWidget);

    await tester.tap(find.byKey(const Key('stage_celebration')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stage_celebration')), findsNothing);

    await tester.tap(find.text('a'));
    await tester.pumpAndSettle();
    expect(done, isNotNull);
    expect(done!.length, 2);
  });

  testWidgets('auto-dismisses the celebration after 800ms', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AssessmentScreen(
          questions: const [
            Question(
              id: 'p1',
              type: 'personality',
              dimension: 'openness',
              text: 'Q1',
              options: ['a', 'b'],
            ),
            Question(
              id: 'i1',
              type: 'iq',
              dimension: 'logic',
              text: 'Q2',
              options: ['a', 'b'],
              kind: 'choice',
              correct: 1,
            ),
          ],
          onDone: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('a'));
    await tester.pump();
    expect(find.byKey(const Key('stage_celebration')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byKey(const Key('stage_celebration')), findsNothing);
  });

  testWidgets('skips the celebration when reduce motion is on', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: AssessmentScreen(
            questions: const [
              Question(
                id: 'p1',
                type: 'personality',
                dimension: 'openness',
                text: 'Q1',
                options: ['a', 'b'],
              ),
              Question(
                id: 'i1',
                type: 'iq',
                dimension: 'logic',
                text: 'Q2',
                options: ['a', 'b'],
                kind: 'choice',
                correct: 1,
              ),
            ],
            onDone: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('a'));
    await tester.pump();
    expect(find.byKey(const Key('stage_celebration')), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
  });
}
