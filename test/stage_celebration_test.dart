import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/ui/assessment/stage_celebration.dart';

void main() {
  testWidgets('calls onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StageCelebration(
            title: '第 2 关 · 认知能力',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('stage_celebration')));
    expect(tapped, isTrue);
  });
}
