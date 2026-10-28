import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'encryption/key_derivation.dart';
import 'models/assessment_record.dart';
import 'services/app_coordinator.dart';
import 'services/audio_service.dart';
import 'services/device_id.dart';
import 'services/guidance.dart';
import 'services/lottery.dart';
import 'services/pin_service.dart';
import 'services/summary.dart';
import 'ui/assessment/assessment_screen.dart';
import 'ui/onboarding/pin_screen.dart';
import 'ui/onboarding/profile_action_sheet.dart';
import 'ui/onboarding/profile_select_screen.dart';
import 'ui/result/guidance_screen.dart';
import 'ui/result/history_screen.dart';
import 'ui/result/result_screen.dart';
import 'ui/widgets/confetti.dart';
import 'utils/pdf_export.dart';

/// Builds the application root.
///
/// [coordinator] can be injected by tests; production uses a default instance.
Widget app({AppCoordinator? coordinator}) => MaterialApp(
  title: '发现自我',
  home: RootFlow(coordinator: coordinator ?? AppCoordinator()),
);

enum _Stage { profiles, assessment, result }

/// Animated "drawing…" then "reveal" lottery dialog.
class _PrizeDialog extends StatefulWidget {
  const _PrizeDialog({required this.prize});
  final Prize prize;

  @override
  State<_PrizeDialog> createState() => _PrizeDialogState();
}

class _PrizeDialogState extends State<_PrizeDialog> {
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _revealed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return AlertDialog(
      title: const Text('抽奖'),
      content: SizedBox(
        height: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_revealed) const Positioned.fill(child: Confetti()),
            Center(
              child: AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 320),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: CurvedAnimation(
                    parent: anim,
                    curve: Curves.easeOutBack,
                  ),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: _revealed
                    ? Column(
                        key: const ValueKey('prize'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.emoji_events,
                            size: 44,
                            color: Colors.amber,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '恭喜获得：${widget.prize.name}',
                            style: const TextStyle(fontSize: 18),
                          ),
                        ],
                      )
                    : const Column(
                        key: ValueKey('drawing'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('抽奖中…'),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

/// Owns the top-level flow: PIN unlock → profile select → assessment → result.
///
/// Also implements the 5-minute background auto-lock required by the spec.
class RootFlow extends StatefulWidget {
  const RootFlow({
    super.key,
    required this.coordinator,
    this.pinService,
    this.onExport,
    this.audio,
    this.autoLockTimeout = const Duration(minutes: 5),
    this.now = _defaultNow,
  });

  final AppCoordinator coordinator;

  /// Sound effects + background music. Defaults to a live instance; tests
  /// inject `AudioService(silent: true)`.
  final AudioService? audio;

  /// Overrides the PIN key derivation/unlock screen (tests inject an in-memory
  /// salt so no platform channel is required).
  final PinService? pinService;

  /// Overrides the PDF export action (tests pass a no-op).
  final Future<void> Function()? onExport;

  /// Background time after which the app relocks.
  final Duration autoLockTimeout;

  /// Injectable clock so auto-lock can be tested deterministically.
  final DateTime Function() now;

  static DateTime _defaultNow() => DateTime.now();

  @override
  State<RootFlow> createState() => _RootFlowState();
}

class _RootFlowState extends State<RootFlow> with WidgetsBindingObserver {
  _Stage _stage = _Stage.profiles;
  Map<String, double> _scores = const {};
  List<String> _recommendations = const [];
  DateTime? _pausedAt;
  DateTime? _viewedAt;
  bool _submitting = false;
  bool _selectingProfile = false;

  late final AudioService _audio = widget.audio ?? AudioService();
  bool get _ownsAudio => widget.audio == null;

  AppCoordinator get _c => widget.coordinator;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsAudio) _audio.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = widget.now();
    } else if (state == AppLifecycleState.resumed) {
      final paused = _pausedAt;
      _pausedAt = null;
      if (paused != null &&
          widget.now().difference(paused) > widget.autoLockTimeout) {
        _lock();
      }
    }
  }

  Future<void> _lock() async {
    await _audio.setMusic(false);
    await _c.lock();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _stage = _Stage.profiles;
      _scores = const {};
      _recommendations = const [];
      _viewedAt = null;
    });
  }

  String get _activeName =>
      _c.profileNames.isEmpty ? '我' : _c.profileNames[_c.activeProfile];

  Future<void> _defaultExport() async {
    final summary = buildSummary(
      scores: _scores,
      dimensions: _c.dimensions,
      careers: _c.careers,
    );
    final bytes = await buildReportPdf(
      profileName: _activeName,
      scores: _labeledScores(),
      recommendations: _recommendations,
      summary: summary.headline,
      suitableCareers: summary.suitableCareers,
      cautiousCareers: summary.cautiousCareers,
    );
    await Printing.sharePdf(bytes: bytes, filename: '发现自我-报告.pdf');
  }

  /// Maps dimension keys to their Chinese labels for the PDF report.
  Map<String, double> _labeledScores() {
    final labels = {for (final d in _c.dimensions) d.key: d.label};
    return {for (final e in _scores.entries) (labels[e.key] ?? e.key): e.value};
  }

  Future<void> _drawLottery() async {
    final seed = DateTime.now().millisecondsSinceEpoch + await deviceIdHash();
    final prize = Lottery(_c.prizes).draw(seed);
    await _audio.win();
    if (!mounted) return;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '抽奖',
      transitionDuration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 320),
      pageBuilder: (_, __, ___) => _PrizeDialog(prize: prize),
      transitionBuilder: (ctx, anim, _, child) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
          child: child,
        ),
      ),
    );
  }

  Future<void> _selectProfile(int index) async {
    if (_selectingProfile) return;
    _selectingProfile = true;
    final previous = _c.activeProfile;
    try {
      _c.activeProfile = index;
      final name = index >= 0 && index < _c.profileNames.length
          ? _c.profileNames[index]
          : '我';

      AssessmentRecord? latest;
      var history = const <AssessmentRecord>[];
      try {
        latest = await _c.latestResult();
        history = await _c.resultHistory();
      } catch (_) {
        _c.activeProfile = previous;
        if (!mounted || _c.key == null) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('读取历史失败')));
        return;
      }
      if (!mounted || _c.key == null) return;

      final record = latest;
      if (record == null) {
        setState(() {
          _viewedAt = null;
          _stage = _Stage.assessment;
        });
        return;
      }

      final action = await showModalBottomSheet<ProfileAction>(
        context: context,
        showDragHandle: true,
        builder: (_) => ProfileActionSheet(
          profileName: name,
          lastFinishedAt: record.finishedAt,
          historyCount: history.length,
        ),
      );
      if (!mounted || _c.key == null || action == null) return;

      switch (action) {
        case ProfileAction.viewLatest:
          await _openRecord(record);
        case ProfileAction.retake:
          setState(() {
            _viewedAt = null;
            _stage = _Stage.assessment;
          });
        case ProfileAction.history:
          await _openHistory();
      }
    } finally {
      _selectingProfile = false;
    }
  }

  Future<void> _openRecord(AssessmentRecord record) async {
    try {
      final recs = await _c.recommendations(record.scores);
      if (!mounted || _c.key == null) return;
      setState(() {
        _scores = record.scores;
        _recommendations = recs;
        _viewedAt = record.finishedAt;
        _stage = _Stage.result;
      });
    } catch (_) {
      if (!mounted || _c.key == null) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('读取历史失败')));
    }
  }

  Future<void> _openHistory() async {
    var records = const <AssessmentRecord>[];
    try {
      records = await _c.resultHistory();
    } catch (_) {
      if (!mounted || _c.key == null) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('读取历史失败')));
      return;
    }
    if (!mounted || _c.key == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => HistoryScreen(
          records: records,
          dimensions: _c.dimensions,
          careers: _c.careers,
          onOpen: (record) {
            Navigator.of(context).pop();
            _openRecord(record);
          },
        ),
      ),
    );
  }

  Future<void> _openGuidance() async {
    try {
      final content = await _c.loadGuidanceContent();
      final report = buildGuidance(
        scores: _scores,
        dimensions: _c.dimensions,
        content: content,
      );
      if (!mounted || _c.key == null) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              GuidanceScreen(report: report, profileName: _activeName),
        ),
      );
    } catch (_) {
      if (!mounted || _c.key == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('建议数据加载失败')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_c.key == null) {
      return PinScreen(
        pinService: widget.pinService,
        onUnlocked: (key) async {
          await _c.unlock(key);
          if (_audio.musicOn) await _audio.setMusic(true);
          if (!mounted) return;
          setState(() => _stage = _Stage.profiles);
        },
      );
    }

    switch (_stage) {
      case _Stage.profiles:
        return ProfileSelectScreen(
          names: _c.profileNames,
          onSelect: _selectProfile,
          onCreate: (name) async {
            await _c.createProfile(name, randomSalt());
            if (!mounted) return;
            setState(() {});
          },
        );
      case _Stage.assessment:
        return AssessmentScreen(
          questions: _c.questions,
          onDone: _finishAssessment,
          audio: _audio,
        );
      case _Stage.result:
        return ResultScreen(
          profileName: _activeName,
          scores: _scores,
          recommendations: _recommendations,
          dimensions: _c.dimensions,
          careers: _c.careers,
          reviewedAt: _viewedAt,
          onExport: widget.onExport ?? _defaultExport,
          onLottery: _viewedAt == null ? _drawLottery : null,
          onRetake: () => setState(() {
            _viewedAt = null;
            _stage = _Stage.assessment;
          }),
          onHistory: _openHistory,
          onGuidance: _openGuidance,
        );
    }
  }

  /// Scores and persists the assessment, then advances to the result stage.
  ///
  /// [AssessmentScreen.onDone] is synchronous, so this is fire-and-forget; the
  /// try/catch keeps a failure from becoming an unhandled async error and
  /// surfaces it to the user instead of leaving them stuck.
  Future<void> _finishAssessment(Map<String, int> answers) async {
    if (_submitting) return;
    _submitting = true;

    final Map<String, double> scores;
    try {
      scores = await _c.submitAnswers(answers);
    } catch (_) {
      _submitting = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('提交失败，请重试')));
      return;
    }

    List<String> recs;
    try {
      recs = await _c.recommendations(scores);
    } catch (_) {
      recs = const [];
    }

    _submitting = false;
    if (!mounted) return;
    setState(() {
      _scores = scores;
      _recommendations = recs;
      _viewedAt = null;
      _stage = _Stage.result;
    });
    await _audio.result();
  }
}
