import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/utils/prng.dart';
import 'package:discover_self/src/services/lottery.dart';

void main() {
  test('mulberry32 is reproducible', () {
    expect(Mulberry32(42).next(), equals(Mulberry32(42).next()));
  });

  test('lottery deterministic for same seed', () {
    final l = Lottery([const Prize('a', 'A', 1, 10), const Prize('b', 'B', 0, 10)]);
    expect(l.draw(7).id, 'a');
    expect(l.draw(7).id, 'a');
  });

  test('weight zero prize never drawn', () {
    final l = Lottery([const Prize('a', 'A', 0, 10), const Prize('b', 'B', 5, 10)]);
    for (var s = 0; s < 50; s++) {
      expect(l.draw(s).id, 'b');
    }
  });
}
