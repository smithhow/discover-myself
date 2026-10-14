import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/services/achievement.dart';

void main() {
  test('award increases points and adds unique badge', () {
    final a = AchievementService();
    a.award('badge_1', 10);
    a.award('badge_1', 10);
    expect(a.points, 20);
    expect(a.badges, ['badge_1']);
  });
}
