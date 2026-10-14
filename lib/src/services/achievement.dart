class AchievementService {
  int points = 0;
  final List<String> badges = [];

  void award(String badgeId, int value) {
    points += value;
    if (!badges.contains(badgeId)) badges.add(badgeId);
  }
}
