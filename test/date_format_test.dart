import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/utils/date_format.dart';

void main() {
  test('pads month and day', () {
    expect(formatDate(DateTime(2026, 1, 5)), '2026-01-05');
    expect(formatDate(DateTime(2026, 12, 31)), '2026-12-31');
  });
}
