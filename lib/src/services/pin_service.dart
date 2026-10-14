import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../encryption/key_derivation.dart';

/// Provides the per-install encryption salt and derives PIN keys.
///
/// The random 16-byte salt is persisted (base64) in secure storage under
/// [_saltKey] so every install derives a unique key. When secure storage is
/// unavailable (e.g. the platform channel never completes under the fake-async
/// event loop used by `flutter test`), a per-process in-memory salt is
/// generated once and reused instead.
class PinService {
  PinService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _saltKey = 'pin_salt';

  static List<int>? _memorySalt;

  final FlutterSecureStorage _storage;

  /// Platform channels never complete under the fake-async event loop used by
  /// widget tests, so short-circuit to the in-memory fallback there.
  static bool get _platformChannelsUnavailable =>
      Platform.environment['FLUTTER_TEST'] == 'true';

  /// Returns the persistent random 16-byte salt, creating and storing it on
  /// first use.
  Future<List<int>> salt() async {
    if (_platformChannelsUnavailable) return _fallbackSalt();
    try {
      final stored = await _storage.read(key: _saltKey);
      if (stored != null && stored.isNotEmpty) {
        return base64.decode(stored);
      }
      final generated = randomSalt();
      await _storage.write(key: _saltKey, value: base64.encode(generated));
      return generated;
    } catch (_) {
      return _fallbackSalt();
    }
  }

  List<int> _fallbackSalt() => _memorySalt ??= randomSalt();

  /// Derives a 32-byte key for [pin] using the persistent salt.
  Future<List<int>> deriveKeyFor(String pin) async =>
      deriveKey(pin, await salt());
}
