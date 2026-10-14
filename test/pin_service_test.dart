import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/services/pin_service.dart';

void main() {
  test('salt returns 16 bytes and is stable across calls', () async {
    final service = PinService();
    final first = await service.salt();
    final second = await service.salt();
    expect(first.length, 16);
    expect(second, equals(first));
  });

  test('deriveKeyFor returns a 32-byte key', () async {
    final service = PinService();
    final key = await service.deriveKeyFor('1234');
    expect(key.length, 32);
  });
}
