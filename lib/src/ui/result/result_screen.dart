import 'package:flutter/material.dart';

import '../../models/career.dart';
import '../../models/dimension.dart';
import '../../services/summary.dart';
import '../../utils/date_format.dart';

/// Displays the overall evaluation, per-dimension scores (grouped by type),
/// career directions and growth tips, plus export/history/lottery actions.
///
/// When [reviewedAt] is set the screen shows a past attempt: a banner replaces
/// the lottery action so prizes cannot be claimed twice.
class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.profileName,
    required this.scores,
    required this.recommendations,
    this.dimensions = const [],
    this.careers = const [],
    this.onExport,
    this.onLottery,
    this.onRetake,
    this.onHistory,
    this.onGuidance,
    this.reviewedAt,
  });

  final String profileName;
  final Map<String, double> scores;
  final List<String> recommendations;

  /// Dimension metadata used to label, explain and group the scores.
  final List<DimensionInfo> dimensions;

  /// Career suggestions used to derive suitable / cautious directions.
  final List<CareerItem> careers;

  /// Exports the report (e.g. shares a PDF). Disabled when `null`.
  final Future<void> Function()? onExport;

  /// Draws a lottery prize. Hidden in review mode or when `null`.
  final VoidCallback? onLottery;

  /// Starts a fresh assessment. Hidden when `null`.
  final VoidCallback? onRetake;

  /// Opens the history list. Hidden when `null`.
  final VoidCallback? onHistory;

  /// Opens the development guidance page. Hidden when `null`.
  final VoidCallback? onGuidance;

  /// When non-null the screen is showing a past attempt.
  final DateTime? reviewedAt;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  static const Map<String, String> _typeTitles = {
    'personality': '人格特质',
    'iq': '认知能力',
    'eq': '情商',
    'interest': '职业兴趣',
    'workstyle': '工作风格',
  };

  static const List<String> _typeOrder = [
    'personality',
    'iq',
    'eq',
    'interest',
    'workstyle',
  ];

  late final AnimationController _controller;
  bool _started = false;

  bool get _isReview => widget.reviewedAt != null;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    if (MediaQuery.of(context).disableAnimations) return;
    _started = true;
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final summary = buildSummary(
      scores: widget.scores,
      dimensions: widget.dimensions,
      careers: widget.careers,
    );
    var barIndex = 0;

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.reviewedAt != null) ...[
            Container(
              key: const Key('review_banner'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '回看 · 测评于 ${formatDate(widget.reviewedAt!)}',
                style: const TextStyle(color: Color(0xFF8D4E00)),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            '档案：${widget.profileName}',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 12),
          _buildOverall(summary),
          const SizedBox(height: 8),
          if (widget.onGuidance != null) ...[
            Card(
              elevation: 0,
              color: const Color(0xFFE8F1FB),
              child: ListTile(
                key: const Key('guidance_entry'),
                leading: const Icon(Icons.explore_outlined),
                title: const Text('发展建议'),
                subtitle: const Text('专业方向 · 职业方向 · 领导力定位'),
                trailing: const Icon(Icons.chevron_right),
                onTap: widget.onGuidance,
              ),
            ),
            const SizedBox(height: 8),
          ],
          for (final type in _orderedTypes())
            _buildGroup(type, () => barIndex++),
          if (summary.suitableCareers.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildChips('适合的择业方向', summary.suitableCareers, Colors.green),
          ],
          if (summary.cautiousCareers.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildChips('可能需要谨慎的方向', summary.cautiousCareers, Colors.orange),
          ],
          const SizedBox(height: 16),
          const Text(
            '成长建议',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          for (final r in widget.recommendations) Text('• $r'),
          if (widget.onRetake != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('retake_assessment'),
              onPressed: widget.onRetake,
              child: const Text('重新测评（更新结果）'),
            ),
          ],
          if (widget.onHistory != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('history_list'),
              onPressed: widget.onHistory,
              child: const Text('历史记录'),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            key: const Key('export_pdf'),
            onPressed: widget.onExport == null
                ? null
                : () => widget.onExport!(),
            child: const Text('导出 PDF 报告'),
          ),
          if (!_isReview && widget.onLottery != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('lottery'),
              onPressed: widget.onLottery,
              child: const Text('抽奖'),
            ),
          ],
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(_isReview ? '历史结果' : '测评结果')),
      body: reduceMotion
          ? content
          : FadeTransition(
              opacity: _controller,
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, 0.02),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _controller,
                        curve: Curves.easeOut,
                      ),
                    ),
                child: content,
              ),
            ),
    );
  }

  Widget _buildOverall(ProfileSummary summary) => Card(
    elevation: 0,
    color: const Color(0xFFF3EFFB),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '总体评价',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(summary.headline, style: const TextStyle(height: 1.5)),
        ],
      ),
    ),
  );

  List<String> _orderedTypes() {
    final present = <String>{
      for (final d in widget.dimensions)
        if (widget.scores.containsKey(d.key)) d.type,
      ...widget.scores.keys.where((k) => _dimensionFor(k) == null),
    };
    return [
      for (final t in _typeOrder)
        if (present.contains(t)) t,
      for (final t in present)
        if (!_typeOrder.contains(t)) t,
    ];
  }

  DimensionInfo? _dimensionFor(String key) {
    for (final d in widget.dimensions) {
      if (d.key == key) return d;
    }
    return null;
  }

  Widget _buildGroup(String type, int Function() nextIndex) {
    final dims = <DimensionInfo>[
      for (final d in widget.dimensions)
        if (d.type == type && widget.scores.containsKey(d.key)) d,
    ];
    final unknown = <String>[
      if (!_typeOrder.contains(type))
        for (final k in widget.scores.keys)
          if (_dimensionFor(k) == null) k,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            _typeTitles[type] ?? '其他',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        for (final d in dims)
          _buildBar(
            d.label,
            d.normalized(widget.scores[d.key]!),
            _format(d, widget.scores[d.key]!),
            d.desc,
            nextIndex(),
          ),
        for (final k in unknown)
          _buildBar(
            k,
            (widget.scores[k]! / 4).clamp(0, 1).toDouble(),
            widget.scores[k]!.toStringAsFixed(1),
            '',
            nextIndex(),
          ),
      ],
    );
  }

  String _format(DimensionInfo d, double value) => d.isChoice
      ? '${(value * 100).round()}%'
      : '${value.toStringAsFixed(1)} / ${d.max}';

  Widget _buildBar(
    String label,
    double value,
    String display,
    String desc,
    int index,
  ) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final start = (index * 0.08).clamp(0.0, 0.6).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text(display, style: const TextStyle(color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 4),
          reduceMotion
              ? LinearProgressIndicator(value: value, minHeight: 10)
              : AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final t = ((_controller.value - start) / (1 - start))
                        .clamp(0.0, 1.0)
                        .toDouble();
                    return LinearProgressIndicator(
                      value: Curves.easeOut.transform(t) * value,
                      minHeight: 10,
                    );
                  },
                ),
          if (desc.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                desc,
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChips(String title, List<String> items, MaterialColor color) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final it in items)
                Chip(
                  label: Text(it),
                  backgroundColor: color.shade50,
                  side: BorderSide(color: color.shade200),
                ),
            ],
          ),
        ],
      );
}
