import 'package:flutter/material.dart';

import '../../utils/date_format.dart';

enum ProfileAction { viewLatest, retake, history }

/// Bottom sheet shown when a profile already has at least one attempt.
class ProfileActionSheet extends StatelessWidget {
  const ProfileActionSheet({
    super.key,
    required this.profileName,
    required this.lastFinishedAt,
    required this.historyCount,
  });

  final String profileName;
  final DateTime? lastFinishedAt;
  final int historyCount;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                lastFinishedAt == null
                    ? profileName
                    : '$profileName · 上次测评 ${formatDate(lastFinishedAt!)}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('view_last_result'),
                onPressed: () =>
                    Navigator.pop(context, ProfileAction.viewLatest),
                icon: const Icon(Icons.assessment_outlined),
                label: const Text('查看上次结果'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('sheet_retake'),
                onPressed: () => Navigator.pop(context, ProfileAction.retake),
                icon: const Icon(Icons.refresh),
                label: const Text('重新测评（更新结果）'),
              ),
              const SizedBox(height: 4),
              TextButton(
                key: const Key('open_history'),
                onPressed: () => Navigator.pop(context, ProfileAction.history),
                child: Text('历史记录 ($historyCount)'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
            ],
          ),
        ),
      );
}
