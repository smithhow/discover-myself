import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../encryption/key_derivation.dart';
import 'salt_store.dart';

/// Thrown when a fresh salt cannot be persisted by any store.
///
/// Proceeding with an unpersisted salt would produce a key that cannot be
/// re-derived on the next launch, permanently locking the user out of their
/// encrypted database. Callers must surface this instead of continuing.
class SaltPersistenceException implements Exception {
  const SaltPersistenceException(this.message);

  final String message;

  @override
  String toString() => 'SaltPersistenceException: $message';
}

/// Provides the per-install encryption salt and derives PIN keys.
///
/// The random 16-byte salt is persisted so every install derives a unique,
/// stable key (and therefore a stable SQLCipher password). Persistence is
/// attempted in this order:
///
/// 1. Secure storage (Keychain / Keystore / web secure storage).
/// 2. A file under the app support directory on IO platforms.
///
/// When a salt is generated it is cached in-process first (so retries within the
/// same process are stable) and then written to *every* available store. If no
/// store can persist it, [salt] throws [SaltPersistenceException] rather than
/// silently proceeding.
///
/// Tests inject `useSecureStorage: false` to use a purely in-memory salt with no
/// platform channel (which would otherwise never complete under the fake-async
/// event loop used by `flutter test`).
class PinService {
  PinService({
    FlutterSecureStorage? storage,
    SaltStore? saltFallback,
    bool useSecureStorage = true,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _fallback =
            saltFallback ?? (useSecureStorage ? createSaltStore() : null),
        _useSecureStorage = useSecureStorage;

  static const String _saltKey = 'pin_salt';

  final FlutterSecureStorage _storage;
  final SaltStore? _fallback;
  final bool _useSecureStorage;

  /// Per-instance last-resort salt, used only when no store can persist one.
  List<int>? _memorySalt;

  /// Returns the persistent random 16-byte salt, creating and storing it on
  /// first use.
  ///
  /// Throws a [SaltPersistenceException] when a newly generated salt cannot be
  /// persisted by any available store, so an unrecoverable key is never used.
  Future<List<int>> salt() async {
    if (!_useSecureStorage) return _memorySalt ??= randomSalt();

    // 1) Primary: secure storage read.
    try {
      final stored = await _storage.read(key: _saltKey);
      if (stored != null && stored.isNotEmpty) return base64.decode(stored);
    } catch (_) {
      // Fall through to the secondary store.
    }

    // 2) Secondary: file under the app support directory (IO only).
    final fallback = _fallback;
    if (fallback != null) {
      try {
        final stored = await fallback.read();
        if (stored != null && stored.isNotEmpty) return stored;
      } catch (_) {
        // Fall through to generating a fresh salt.
      }
    }

    // 3) Nothing persisted yet: cache in-process first so retries within this
    // process stay stable, then mirror to every store.
    final generated = _memorySalt ??= randomSalt();
    var persisted = false;
    try {
      await _storage.write(key: _saltKey, value: base64.encode(generated));
      persisted = true;
    } catch (_) {
      // Ignore; the secondary store may still succeed.
    }
    if (fallback != null) {
      try {
        if (await fallback.write(generated)) persisted = true;
      } catch (_) {
        // Ignore; persistence failure is handled below.
      }
    }
    if (!persisted) {
      throw const SaltPersistenceException(
        '无法安全保存密钥，请检查设备存储设置',
      );
    }
    return generated;
  }

  /// Derives a 32-byte key for [pin] using the persistent salt.
  Future<List<int>> deriveKeyFor(String pin) async =>
      deriveKey(pin, await salt());
}
