import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/ui/onboarding/profile_action_sheet.dart';

void main() {
  testWidgets('returns the chosen action', (tester) async {
    ProfileAction? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('open_sheet'),
                onPressed: () async {
                  chosen = await showModalBottomSheet<ProfileAction>(
                    context: context,
                    builder: (_) => const ProfileActionSheet(
                      profileName: '我',
                      lastFinishedAt: null,
                      historyCount: 2,
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open_sheet')));
    await tester.pumpAndSettle();

    expect(find.text('我'), findsOneWidget);
    expect(find.byKey(const Key('view_last_result')), findsOneWidget);
    expect(find.byKey(const Key('sheet_retake')), findsOneWidget);
    expect(find.byKey(const Key('open_history')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sheet_retake')));
    await tester.pumpAndSettle();
    expect(chosen, ProfileAction.retake);
  });
}
