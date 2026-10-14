import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

Uint8List deriveKey(String pin, List<int> salt, {int iterations = 10000}) {
  final pbkdf2 = _Pbkdf2(sha256, iterations);
  return pbkdf2.derive(Uint8List.fromList(pin.codeUnits), Uint8List.fromList(salt), 32);
}

Uint8List randomSalt() {
  final r = Random.secure();
  return Uint8List.fromList(List<int>.generate(16, (_) => r.nextInt(256)));
}

String bytesToHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

class _Pbkdf2 {
  final Hash hash;
  final int iterations;
  _Pbkdf2(this.hash, this.iterations);

  Uint8List derive(Uint8List password, Uint8List salt, int keyLen) {
    final hLen = hash.convert(<int>[]).bytes.length;
    final blocks = (keyLen / hLen).ceil();
    final out = BytesBuilder();
    for (var i = 1; i <= blocks; i++) {
      var u = _f(password, salt, i);
      final t = Uint8List.fromList(u);
      for (var j = 1; j < iterations; j++) {
        u = Uint8List.fromList(_hmac(password, u));
        for (var k = 0; k < t.length; k++) {
          t[k] ^= u[k];
        }
      }
      out.add(t);
    }
    return Uint8List.sublistView(out.toBytes(), 0, keyLen);
  }

  Uint8List _f(Uint8List password, Uint8List salt, int blockIndex) {
    final input = <int>[...salt, (blockIndex >> 24) & 0xff, (blockIndex >> 16) & 0xff, (blockIndex >> 8) & 0xff, blockIndex & 0xff];
    return Uint8List.fromList(_hmac(password, Uint8List.fromList(input)));
  }

  List<int> _hmac(Uint8List key, Uint8List data) =>
      Hmac(hash, key).convert(data).bytes;
}
