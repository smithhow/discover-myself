import 'dart:async';

import 'package:flutter/material.dart';
import '../../models/question.dart';
import '../../services/audio_service.dart';
import 'stage_celebration.dart';

class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({
    super.key,
    required this.questions,
    required this.onDone,
    this.audio,
  });
  final List<Question> questions;
  final void Function(Map<String, int> answers) onDone;

  /// Optional feedback sounds + background-music toggle.
  final AudioService? audio;

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  int _i = 0;
  final Map<String, int> _answers = {};

  /// Blocks further taps briefly after an answer, so an accidental double tap
  /// (or a stray input event) cannot skip a question.
  bool _locked = false;
  static const Duration _lockFor = Duration(milliseconds: 160);

  /// Non-null while the stage-completion overlay is visible.
  String? _celebrating;
  Timer? _celebrationTimer;

  static const Map<String, String> _stageTitles = {
    'personality': '第 1 关 · 人格特质',
    'iq': '第 2 关 · 认知能力',
    'eq': '第 3 关 · 情商',
    'interest': '第 4 关 · 职业兴趣',
  };

  @override
  void initState() {
    super.initState();
    if (widget.questions.isEmpty) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => widget.onDone(const {}));
    }
  }

  @override
  void dispose() {
    _celebrationTimer?.cancel();
    super.dispose();
  }

  void _answer(int value) {
    if (_locked || _celebrating != null || widget.questions.isEmpty) return;
    _locked = true;
    final q = widget.questions[_i];
    _answers[q.id] = value;
    widget.audio?.tap();

    if (_i == widget.questions.length - 1) {
      widget.onDone(Map<String, int>.of(_answers));
      return;
    }

    final nextType = widget.questions[_i + 1].type;
    setState(() => _i++);
    if (nextType != q.type) {
      widget.audio?.stageComplete();
      final title = _stageTitles[nextType];
      if (title != null && !MediaQuery.of(context).disableAnimations) {
        _celebrationTimer?.cancel();
        setState(() => _celebrating = title);
        _celebrationTimer =
            Timer(const Duration(milliseconds: 800), _dismissCelebration);
      }
    }
    Future.delayed(_lockFor, () {
      if (mounted) _locked = false;
    });
  }

  void _dismissCelebration() {
    _celebrationTimer?.cancel();
    _celebrationTimer = null;
    if (!mounted || _celebrating == null) return;
    setState(() => _celebrating = null);
  }

  void _back() {
    if (_i == 0) return;
    widget.audio?.back();
    setState(() => _i--);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return const Scaffold(body: Center(child: Text('暂无题目')));
    }
    final q = widget.questions[_i];
    final total = widget.questions.length;
    final stage = _stageTitles[q.type] ?? '测评';
    final audio = widget.audio;
    return Scaffold(
      appBar: AppBar(
        title: Text('测评 ${_i + 1}/$total'),
        leading: _i > 0
            ? IconButton(
                key: const Key('assess_back'),
                icon: const Icon(Icons.arrow_back),
                tooltip: '上一题',
                onPressed: _back,
              )
            : null,
        actions: [
          if (audio != null)
            IconButton(
              key: const Key('music_toggle'),
              tooltip: audio.musicOn ? '关闭音乐' : '开启音乐',
              icon: Icon(audio.musicOn ? Icons.music_note : Icons.music_off),
              onPressed: () async {
                await audio.setMusic(!audio.musicOn);
                if (mounted) setState(() {});
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(children: [
            LinearProgressIndicator(
              value: (_i + 1) / total,
              minHeight: 6,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(stage,
                    style: const TextStyle(
                        color: Colors.deepPurple, fontSize: 13)),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.06, 0),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: Column(
                  key: ValueKey(_i),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child:
                          Text(q.text, style: const TextStyle(fontSize: 20)),
                    ),
                    for (var i = 0; i < q.options.length; i++)
                      ListTile(
                        title: Text(q.options[i]),
                        onTap: () => _answer(i + 1),
                      ),
                  ],
                ),
              ),
            ),
          ]),
          if (_celebrating != null)
            Positioned.fill(
              child: StageCelebration(
                title: _celebrating!,
                onTap: _dismissCelebration,
              ),
            ),
        ],
      ),
    );
  }
}
