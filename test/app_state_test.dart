import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/services/app_state.dart';

void main() {
  test('AppState default has no key and profile 0', () {
    final s = AppState();
    expect(s.key, isNull);
    expect(s.activeProfile, 0);
  });

  test('lock clears key', () {
    final s = AppState()..key = [1, 2];
    s.lock();
    expect(s.key, isNull);
  });
}
