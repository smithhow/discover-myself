/// Persistence abstraction for the PIN salt.
///
/// [PinService] uses this as a secondary store when secure storage is
/// unavailable, so the derived key (and therefore the SQLCipher password) stays
/// stable across launches instead of silently changing and locking the user out.
abstract class SaltStore {
  /// Returns the stored salt, or `null` when none has been persisted yet.
  Future<List<int>?> read();

  /// Persists [salt] so it survives process restarts.
  ///
  /// Returns `true` only when the value was actually persisted; `false` when the
  /// store cannot persist (e.g. the web no-op store). A `false` result lets
  /// [PinService] avoid treating a non-persisted salt as durable.
  Future<bool> write(List<int> salt);
}
