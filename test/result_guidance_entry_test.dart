import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/ui/result/result_screen.dart';

void main() {
  testWidgets('shows the guidance entry and invokes the callback', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(
          profileName: '我',
          scores: const {'openness': 4},
          recommendations: const [],
          onGuidance: () => opened = true,
          onExport: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('guidance_entry')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('guidance_entry')));
    await tester.tap(find.byKey(const Key('guidance_entry')));
    expect(opened, isTrue);
  });
}
