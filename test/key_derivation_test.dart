import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/encryption/key_derivation.dart';

void main() {
  test('same pin+salt yields same 32-byte key', () {
    final salt = List<int>.filled(16, 7);
    final a = deriveKey('1234', salt);
    final b = deriveKey('1234', salt);
    expect(a.length, 32);
    expect(a, equals(b));
  });

  test('different pin yields different key', () {
    final salt = List<int>.filled(16, 7);
    expect(deriveKey('1234', salt), isNot(equals(deriveKey('9999', salt))));
  });

  test('randomSalt is 16 bytes and varies', () {
    expect(randomSalt().length, 16);
    expect(randomSalt(), isNot(equals(randomSalt())));
  });

  test('matches known PBKDF2-HMAC-SHA256 vectors', () {
    final salt = 'salt'.codeUnits;
    expect(
      bytesToHex(deriveKey('password', salt, iterations: 1)).toLowerCase(),
      '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
    );
    expect(
      bytesToHex(deriveKey('password', salt, iterations: 4096)).toLowerCase(),
      'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
    );
  });
}
