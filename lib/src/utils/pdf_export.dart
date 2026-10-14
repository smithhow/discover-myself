import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<Uint8List> buildReportPdf({
  required String profileName,
  required Map<String, double> scores,
  required List<String> recommendations,
}) async {
  final cjk = pw.Font.ttf(await rootBundle.load('assets/fonts/SimHei.ttf'));
  final theme = pw.ThemeData.withFont(base: cjk, bold: cjk);

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      theme: theme,
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => [
        pw.Header(level: 0, text: '发现自我 - 测评报告'),
        pw.Text('档案：$profileName'),
        pw.SizedBox(height: 12),
        pw.Text('维度得分', style: const pw.TextStyle(fontSize: 16)),
        pw.Bullet(
          text: scores.entries
              .map((e) => '${e.key}: ${e.value.toStringAsFixed(2)}')
              .join('\n'),
        ),
        pw.SizedBox(height: 12),
        pw.Text('成长建议', style: const pw.TextStyle(fontSize: 16)),
        for (final r in recommendations) pw.Bullet(text: r),
      ],
    ),
  );
  return doc.save();
}
