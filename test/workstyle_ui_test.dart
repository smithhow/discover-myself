import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/models/dimension.dart';
import 'package:discover_self/src/models/question.dart';
import 'package:discover_self/src/ui/assessment/assessment_screen.dart';
import 'package:discover_self/src/ui/result/result_screen.dart';

void main() {
  testWidgets('shows the workstyle stage title after interest', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AssessmentScreen(
          questions: const [
            Question(
              id: 'i1',
              type: 'interest',
              dimension: 'investigative',
              text: 'Q1',
              options: ['a', 'b'],
            ),
            Question(
              id: 'w1',
              type: 'workstyle',
              dimension: 'leadership_drive',
              text: 'Q2',
              options: ['a', 'b'],
            ),
          ],
          onDone: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('a'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('stage_celebration')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('stage_celebration')),
        matching: find.text('第 5 关 · 工作风格'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('result groups workstyle dimensions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(
          profileName: '我',
          scores: const {'leadership_drive': 4},
          recommendations: const [],
          dimensions: const [
            DimensionInfo(
              key: 'leadership_drive',
              label: '领导意愿',
              type: 'workstyle',
              kind: 'likert',
            ),
          ],
          careers: const [],
          onExport: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('工作风格'), findsOneWidget);
  });
}
