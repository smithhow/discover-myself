import 'package:flutter/material.dart';
import '../../utils/pdf_export.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.profileName, required this.scores, required this.recommendations});
  final String profileName;
  final Map<String, double> scores;
  final List<String> recommendations;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('测评结果')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text('档案：$profileName', style: const TextStyle(fontSize: 18)),
          for (final e in scores.entries) LinearProgressIndicator(value: (e.value / 4).clamp(0, 1), minHeight: 12),
          const SizedBox(height: 16),
          const Text('成长建议', style: TextStyle(fontSize: 18)),
          for (final r in recommendations) Text('• $r'),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: () async {
            await buildReportPdf(profileName: profileName, scores: scores, recommendations: recommendations);
          }, child: const Text('导出 PDF 报告')),
        ]),
      );
}
