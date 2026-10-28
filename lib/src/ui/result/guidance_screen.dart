import 'package:flutter/material.dart';

import '../../models/guidance.dart';

/// Read-only development guidance: majors, careers, leadership, next steps.
class GuidanceScreen extends StatelessWidget {
  const GuidanceScreen({
    super.key,
    required this.report,
    required this.profileName,
  });

  final GuidanceReport report;
  final String profileName;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('guidance_screen'),
    appBar: AppBar(title: const Text('发展建议')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$profileName 的发展建议',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text('无论你在选专业、转专业还是考虑职业转型，都可以把这部分作为参考。'),
          if (!report.hasWorkstyle) ...[
            const SizedBox(height: 12),
            const Card(
              key: Key('guidance_reference_note'),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('本次测评未包含工作风格题，领导力判断为参考值。'),
              ),
            ),
          ],
          if (report.majors.isEmpty && report.careers.isEmpty) ...[
            const SizedBox(height: 12),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('暂无可用建议'),
              ),
            ),
          ],
          const SizedBox(height: 16),
          KeyedSubtree(
            key: const Key('guidance_majors'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('推荐专业方向'),
                if (report.majors.isEmpty)
                  const _EmptySection()
                else
                  for (var i = 0; i < report.majors.length; i++)
                    _MajorCard(index: i, fit: report.majors[i]),
              ],
            ),
          ),
          const SizedBox(height: 16),
          KeyedSubtree(
            key: const Key('guidance_careers'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('适合的职业方向'),
                if (report.careers.isEmpty)
                  const _EmptySection()
                else
                  for (var i = 0; i < report.careers.length; i++)
                    _CareerCard(index: i, fit: report.careers[i]),
              ],
            ),
          ),
          const SizedBox(height: 16),
          KeyedSubtree(
            key: const Key('guidance_leadership'),
            child: _LeadershipCard(profile: report.leadership),
          ),
          const SizedBox(height: 16),
          KeyedSubtree(
            key: const Key('guidance_next_steps'),
            child: _NextSteps(steps: report.nextSteps),
          ),
          const SizedBox(height: 16),
          const Text(
            '本建议基于你的自评结果，仅供探索参考，不替代专业咨询。',
            style: TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ],
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
  );
}

class _EmptySection extends StatelessWidget {
  const _EmptySection();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(bottom: 8),
    child: Text('暂无可用建议', style: TextStyle(color: Colors.black54)),
  );
}

class _MajorCard extends StatelessWidget {
  const _MajorCard({required this.index, required this.fit});

  final int index;
  final MajorFit fit;

  @override
  Widget build(BuildContext context) => Card(
    key: Key('major_card_$index'),
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  fit.cluster,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '匹配度 ${_pct(fit.fit)}',
                style: const TextStyle(color: Colors.deepPurple),
              ),
            ],
          ),
          if (fit.summary.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(fit.summary),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final major in fit.majors) Chip(label: Text(major)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '推荐理由：${fit.reasons.join('；')}',
            style: const TextStyle(fontSize: 13),
          ),
          if (fit.caution != null) ...[
            const SizedBox(height: 6),
            Text(
              fit.caution!,
              style: const TextStyle(fontSize: 13, color: Colors.orange),
            ),
          ],
        ],
      ),
    ),
  );
}

class _CareerCard extends StatelessWidget {
  const _CareerCard({required this.index, required this.fit});

  final int index;
  final CareerFit fit;

  @override
  Widget build(BuildContext context) => Card(
    key: Key('career_item_$index'),
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  fit.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '匹配度 ${_pct(fit.fit)}',
                style: const TextStyle(color: Colors.deepPurple),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '方向：${fit.cluster}',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 6),
          Text(
            '推荐理由：${fit.reasons.join('；')}',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            '入门：${fit.entry}',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    ),
  );
}

class _LeadershipCard extends StatelessWidget {
  const _LeadershipCard({required this.profile});

  final LeadershipProfile profile;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '领导力定位',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Chip(
                key: const Key('leadership_type'),
                label: Text(profile.type.label),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Bar(
            label: '领导潜力',
            value: profile.leadership,
            barKey: const Key('leadership_bar'),
          ),
          _Bar(
            label: '执行稳定性',
            value: profile.execution,
            barKey: const Key('execution_bar'),
          ),
          const SizedBox(height: 4),
          Text('判断依据：${profile.reasons.join('、')}'),
          const SizedBox(height: 10),
          const Text('发展建议', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final tip in profile.tips)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('• $tip'),
            ),
        ],
      ),
    ),
  );
}

class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.value, required this.barKey});

  final String label;
  final double value;
  final Key barKey;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(label), Text(_pct(value))],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(key: barKey, value: value, minHeight: 8),
      ],
    ),
  );
}

class _NextSteps extends StatelessWidget {
  const _NextSteps({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SectionTitle('下一步行动'),
      for (final step in steps)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('• $step'),
        ),
    ],
  );
}

String _pct(double value) => '${(value * 100).round()}%';
