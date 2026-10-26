import 'package:flutter/material.dart';

import '../../models/assessment_record.dart';
import '../../models/career.dart';
import '../../models/dimension.dart';
import '../../services/summary.dart';
import '../../utils/date_format.dart';

/// Lists every persisted attempt for one profile, newest first.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    super.key,
    required this.records,
    required this.dimensions,
    required this.careers,
    required this.onOpen,
  });

  final List<AssessmentRecord> records;
  final List<DimensionInfo> dimensions;
  final List<CareerItem> careers;
  final void Function(AssessmentRecord record) onOpen;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('历史记录')),
        body: records.isEmpty
            ? const Center(child: Text('暂无历史记录'))
            : ListView.separated(
                itemCount: records.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final record = records[index];
                  final summary = buildSummary(
                    scores: record.scores,
                    dimensions: dimensions,
                    careers: careers,
                  );
                  final scores = _scoreSummary(record);
                  return ListTile(
                    key: Key('history_item_$index'),
                    title: Text(formatDate(record.finishedAt)),
                    subtitle: Text(
                      scores.isEmpty
                          ? summary.headline
                          : '${summary.headline}\n$scores',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: scores.isNotEmpty,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onOpen(record),
                  );
                },
              ),
      );

  String _scoreSummary(AssessmentRecord record) {
    final parts = <String>[];
    for (final dimension in dimensions) {
      final value = record.scores[dimension.key];
      if (value == null) continue;
      final display = dimension.isChoice
          ? '${(value * 100).round()}%'
          : value.toStringAsFixed(1);
      parts.add('${dimension.label} $display');
    }
    return parts.take(4).join(' · ');
  }
}
