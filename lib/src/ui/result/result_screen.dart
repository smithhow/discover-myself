import 'package:flutter/material.dart';

/// Displays assessment scores and growth tips, and exposes export/lottery
/// actions supplied by the parent flow.
class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.profileName,
    required this.scores,
    required this.recommendations,
    this.onExport,
    this.onLottery,
  });

  final String profileName;
  final Map<String, double> scores;
  final List<String> recommendations;

  /// Exports the report (e.g. shares a PDF). Disabled when `null`.
  final Future<void> Function()? onExport;

  /// Draws a lottery prize. Hidden when `null`.
  final VoidCallback? onLottery;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('测评结果')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text('档案：$profileName', style: const TextStyle(fontSize: 18)),
          for (final e in scores.entries)
            LinearProgressIndicator(
                value: (e.value / 4).clamp(0, 1).toDouble(), minHeight: 12),
          const SizedBox(height: 16),
          const Text('成长建议', style: TextStyle(fontSize: 18)),
          for (final r in recommendations) Text('• $r'),
          const SizedBox(height: 16),
          ElevatedButton(
            key: const Key('export_pdf'),
            onPressed: onExport == null ? null : () => onExport!(),
            child: const Text('导出 PDF 报告'),
          ),
          if (onLottery != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('lottery'),
              onPressed: onLottery,
              child: const Text('抽奖'),
            ),
          ],
        ]),
      );
}
