import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/ui/widgets/confetti.dart';

void main() {
  testWidgets('renders confetti when animations are enabled', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 300, height: 300, child: Confetti()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('confetti')), findsOneWidget);
  });

  testWidgets('hides confetti when animations are disabled', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: SizedBox(width: 300, height: 300, child: Confetti()),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('confetti')), findsNothing);
  });
}
