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
}
