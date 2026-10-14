import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'encryption/key_derivation.dart';
import 'services/app_coordinator.dart';
import 'services/device_id.dart';
import 'services/lottery.dart';
import 'ui/assessment/assessment_screen.dart';
import 'ui/onboarding/pin_screen.dart';
import 'ui/onboarding/profile_select_screen.dart';
import 'ui/result/result_screen.dart';
import 'utils/pdf_export.dart';

/// Builds the application root.
///
/// [coordinator] can be injected by tests; production uses a default instance.
Widget app({AppCoordinator? coordinator}) => MaterialApp(
      title: '发现自我',
      home: RootFlow(coordinator: coordinator ?? AppCoordinator()),
    );

enum _Stage { profiles, assessment, result }

/// Owns the top-level flow: PIN unlock → profile select → assessment → result.
///
/// Also implements the 5-minute background auto-lock required by the spec.
class RootFlow extends StatefulWidget {
  const RootFlow({
    super.key,
    required this.coordinator,
    this.onExport,
    this.autoLockTimeout = const Duration(minutes: 5),
    this.now = _defaultNow,
  });

  final AppCoordinator coordinator;

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

  AppCoordinator get _c => widget.coordinator;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    await _c.lock();
    if (!mounted) return;
    setState(() {
      _stage = _Stage.profiles;
      _scores = const {};
      _recommendations = const [];
    });
  }

  String get _activeName =>
      _c.profileNames.isEmpty ? '我' : _c.profileNames[_c.activeProfile];

  Future<void> _defaultExport() async {
    final bytes = await buildReportPdf(
      profileName: _activeName,
      scores: _scores,
      recommendations: _recommendations,
    );
    await Printing.sharePdf(bytes: bytes, filename: '发现自我-报告.pdf');
  }

  Future<void> _drawLottery() async {
    final seed = DateTime.now().millisecondsSinceEpoch + await deviceIdHash();
    final prize = Lottery(_c.prizes).draw(seed);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('抽奖'),
        content: Text('恭喜获得：${prize.name}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_c.key == null) {
      return PinScreen(onUnlocked: (key) async {
        await _c.unlock(key);
        if (!mounted) return;
        setState(() => _stage = _Stage.profiles);
      });
    }

    switch (_stage) {
      case _Stage.profiles:
        return ProfileSelectScreen(
          names: _c.profileNames,
          onSelect: (i) => setState(() {
            _c.activeProfile = i;
            _stage = _Stage.assessment;
          }),
          onCreate: (name) async {
            await _c.createProfile(name, randomSalt());
            if (!mounted) return;
            setState(() {});
          },
        );
      case _Stage.assessment:
        return AssessmentScreen(
          questions: _c.questions,
          onDone: (answers) async {
            final scores = await _c.submitAnswers(answers);
            final recs = await _c.recommendations(scores);
            if (!mounted) return;
            setState(() {
              _scores = scores;
              _recommendations = recs;
              _stage = _Stage.result;
            });
          },
        );
      case _Stage.result:
        return ResultScreen(
          profileName: _activeName,
          scores: _scores,
          recommendations: _recommendations,
          onExport: widget.onExport ?? _defaultExport,
          onLottery: _drawLottery,
        );
    }
  }
}
