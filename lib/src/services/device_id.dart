import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Returns a stable 31-bit hash derived from a persistent random device id.
///
/// The raw id is stored in [FlutterSecureStorage] under `device_id` and created
/// on first use. The first four bytes of its SHA-256 digest are folded
/// big-endian into an integer, then masked to 31 bits so the result stays a
/// positive value safe for use in a PRNG seed.
///
/// Secure storage is unavailable on the Dart VM (unit tests) and may fail on
/// some platforms; any failure returns `0`.
Future<int> deviceIdHash() async {
  try {
    const storage = FlutterSecureStorage();
    var id = await storage.read(key: 'device_id');
    if (id == null || id.isEmpty) {
      final rng = Random.secure();
      id = List<int>.generate(16, (_) => rng.nextInt(256))
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      await storage.write(key: 'device_id', value: id);
    }
    final digest = sha256.convert(id.codeUnits).bytes;
    var hash = 0;
    for (var i = 0; i < 4; i++) {
      hash = (hash << 8) | digest[i];
    }
    return hash & 0x7FFFFFFF;
  } catch (_) {
    return 0;
  }
}
