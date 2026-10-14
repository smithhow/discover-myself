import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/utils/pdf_export.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('produces non-empty pdf bytes starting with %PDF', () async {
    final bytes = await buildReportPdf(
      profileName: '孩子A',
      scores: {'openness': 4.0},
      recommendations: ['多读书'],
    );
    expect(bytes.length, greaterThan(100));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('embeds a TrueType CJK font', () async {
    final bytes = await buildReportPdf(
      profileName: '孩子A',
      scores: {'openness': 4.0},
      recommendations: ['多读书'],
    );
    final text = latin1.decode(bytes, allowInvalid: true);
    expect(text.contains('FontFile2'), isTrue,
        reason: 'CJK TTF must be embedded');
  });
}
