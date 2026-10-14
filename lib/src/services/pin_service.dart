import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../encryption/key_derivation.dart';
import 'salt_store.dart';

/// Provides the per-install encryption salt and derives PIN keys.
///
/// The random 16-byte salt is persisted so every install derives a unique,
/// stable key (and therefore a stable SQLCipher password). Persistence is
/// attempted in this order:
///
/// 1. Secure storage (Keychain / Keystore / web secure storage).
/// 2. A file under the app support directory on IO platforms.
/// 3. An in-process salt, only when both stores fail.
///
/// When a salt is generated it is written to *every* available store, so a
/// single store failing on a later launch cannot change the derived key and
/// lock the user out of their database.
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
  Future<List<int>> salt() async {
    if (!_useSecureStorage) return _memorySalt ??= randomSalt();

    // 1) Primary: secure storage.
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

    // 3) Nothing persisted yet: generate once and mirror to every store so any
    // single store failing on a later launch can still recover the value.
    final generated = randomSalt();
    var persisted = false;
    try {
      await _storage.write(key: _saltKey, value: base64.encode(generated));
      persisted = true;
    } catch (_) {
      // Ignore; the secondary store may still succeed.
    }
    if (fallback != null) {
      try {
        await fallback.write(generated);
        persisted = true;
      } catch (_) {
        // Ignore; falls back to the in-process salt below.
      }
    }
    return persisted ? generated : (_memorySalt ??= generated);
  }

  /// Derives a 32-byte key for [pin] using the persistent salt.
  Future<List<int>> deriveKeyFor(String pin) async =>
      deriveKey(pin, await salt());
}
