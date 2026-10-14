import 'salt_store_base.dart';

/// Web/no-IO implementation of [SaltStore].
///
/// Web builds rely on secure storage (backed by `flutter_secure_storage_web`).
/// If that fails there is no local file to fall back to, so this store is a
/// no-op. [write] returns `false` so [PinService] never mistakes this store for
/// a durable persistence mechanism.
SaltStore createSaltStore() => _NoopSaltStore();

class _NoopSaltStore implements SaltStore {
  @override
  Future<List<int>?> read() async => null;

  @override
  Future<bool> write(List<int> salt) async => false;
}
