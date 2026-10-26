import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/models/assessment_record.dart';
import 'package:discover_self/src/models/dimension.dart';
import 'package:discover_self/src/ui/result/history_screen.dart';

void main() {
  testWidgets('lists attempts newest first and opens the tapped one',
      (tester) async {
    AssessmentRecord? opened;
    final records = [
      AssessmentRecord(
        id: 2,
        finishedAt: DateTime(2026, 10, 20),
        scores: const {'openness': 4},
      ),
      AssessmentRecord(
        id: 1,
        finishedAt: DateTime(2026, 10, 1),
        scores: const {'openness': 2},
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: HistoryScreen(
          records: records,
          dimensions: const [
            DimensionInfo(
              key: 'openness',
              label: '开放性',
              type: 'personality',
              kind: 'likert',
            ),
          ],
          careers: const [],
          onOpen: (record) => opened = record,
        ),
      ),
    );

    expect(find.text('2026-10-20'), findsOneWidget);
    expect(find.textContaining('开放性'), findsWidgets);

    await tester.tap(find.byKey(const Key('history_item_0')));
    expect(opened?.id, 2);
  });
}
