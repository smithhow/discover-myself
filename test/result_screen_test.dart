import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/models/dimension.dart';
import 'package:discover_self/src/ui/result/result_screen.dart';

Widget _screen({
  DateTime? reviewedAt,
  VoidCallback? onLottery,
  VoidCallback? onRetake,
  VoidCallback? onHistory,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: ResultScreen(
        profileName: '我',
        scores: const {'openness': 4},
        recommendations: const ['多尝试新事物'],
        dimensions: const [
          DimensionInfo(
            key: 'openness',
            label: '开放性',
            type: 'personality',
            kind: 'likert',
          ),
        ],
        careers: const [],
        reviewedAt: reviewedAt,
        onLottery: onLottery,
        onRetake: onRetake,
        onHistory: onHistory,
        onExport: () async {},
      ),
    ),
  );
}

void main() {
  testWidgets('latest result shows the lottery button', (tester) async {
    await tester.pumpWidget(_screen(onLottery: () {}));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('review_banner')), findsNothing);
    expect(find.byKey(const Key('lottery')), findsOneWidget);
  });

  testWidgets(
    'review mode shows the banner, hides lottery, and wires actions',
    (tester) async {
      var retook = false;
      var openedHistory = false;

      await tester.pumpWidget(
        _screen(
          reviewedAt: DateTime(2026, 10, 20),
          onRetake: () => retook = true,
          onHistory: () => openedHistory = true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('review_banner')), findsOneWidget);
      expect(find.textContaining('2026-10-20'), findsOneWidget);
      expect(find.byKey(const Key('lottery')), findsNothing);

      await tester.ensureVisible(find.byKey(const Key('retake_assessment')));
      await tester.tap(find.byKey(const Key('retake_assessment')));
      expect(retook, isTrue);

      await tester.ensureVisible(find.byKey(const Key('history_list')));
      await tester.tap(find.byKey(const Key('history_list')));
      expect(openedHistory, isTrue);
    },
  );

  testWidgets('renders without animation when reduce motion is on', (
    tester,
  ) async {
    await tester.pumpWidget(_screen(disableAnimations: true));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsWidgets);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(0.8, 1e-9));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
