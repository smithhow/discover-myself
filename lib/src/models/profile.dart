/// A local user profile row from the `users` table.
class Profile {
  /// Row id.
  final int? id;

  /// Display name shown in the UI.
  final String name;

  /// Per-profile PIN salt (bytes) used for key derivation.
  final List<int> pinSalt;

  /// Creation time in milliseconds since the epoch.
  final int createdAt;

  const Profile({
    this.id,
    required this.name,
    required this.pinSalt,
    required this.createdAt,
  });

  /// Builds a [Profile] from a raw database row.
  factory Profile.fromRow(Map<String, Object?> row) => Profile(
        id: row['id'] as int?,
        name: row['name'] as String,
        pinSalt: (row['pin_salt'] as List).cast<int>(),
        createdAt: row['created_at'] as int,
      );
}
