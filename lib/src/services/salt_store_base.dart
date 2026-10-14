/// Persistence abstraction for the PIN salt.
///
/// [PinService] uses this as a secondary store when secure storage is
/// unavailable, so the derived key (and therefore the SQLCipher password) stays
/// stable across launches instead of silently changing and locking the user out.
abstract class SaltStore {
  /// Returns the stored salt, or `null` when none has been persisted yet.
  Future<List<int>?> read();

  /// Persists [salt] so it survives process restarts.
  Future<void> write(List<int> salt);
}
