import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show sqfliteFfiInit, databaseFactoryFfi;

import 'package:discover_self/src/app.dart';
import 'package:discover_self/src/db/database.dart';
import 'package:discover_self/src/models/assessment_record.dart';
import 'package:discover_self/src/models/dimension.dart';
import 'package:discover_self/src/models/guidance.dart';
import 'package:discover_self/src/services/app_coordinator.dart';
import 'package:discover_self/src/services/audio_service.dart';

GuidanceContent _guidanceContent() => GuidanceContent(
      clusters: [
        MajorCluster(
          name: '计算机与人工智能',
          summary: '编程、算法与数据。',
          majors: const ['软件工程', '人工智能'],
          weights: const {'investigative': 0.5, 'logic': 0.5},
          minimums: const {},
        ),
      ],
      careers: [
        CareerAdviceItem(
          name: '软件工程师',
          cluster: '计算机与人工智能',
          weights: const {'investigative': 0.5, 'logic': 0.5},
          entry: '从编程实习或初级开发岗位进入。',
        ),
      ],
    );

class _GuidanceCoordinator extends AppCoordinator {
  _GuidanceCoordinator()
      : super(
          database: Database(inMemory: true, factory: databaseFactoryFfi),
        ) {
    profileNames = const ['我'];
    profileIds = const [0];
    questions = const [];
    dimensions = const [
      DimensionInfo(key: 'leadership_drive', label: '领导意愿', type: 'workstyle', kind: 'likert', max: 1),
      DimensionInfo(key: 'execution_focus', label: '执行偏好', type: 'workstyle', kind: 'likert', max: 1),
      DimensionInfo(key: 'adaptability', label: '变化适应', type: 'workstyle', kind: 'likert', max: 1),
      DimensionInfo(key: 'investigative', label: '研究型 I', type: 'interest', kind: 'likert', max: 1),
      DimensionInfo(key: 'logic', label: '逻辑推理', type: 'iq', kind: 'choice', max: 1),
      DimensionInfo(key: 'enterprising', label: '企业型 E', type: 'interest', kind: 'likert', max: 1),
      DimensionInfo(key: 'social_skills', label: '社交技能', type: 'eq', kind: 'likert', max: 1),
      DimensionInfo(key: 'emotional_stability', label: '情绪稳定性', type: 'personality', kind: 'likert', max: 1),
      DimensionInfo(key: 'self_regulation', label: '情绪调节', type: 'eq', kind: 'likert', max: 1),
      DimensionInfo(key: 'conscientiousness', label: '尽责性', type: 'personality', kind: 'likert', max: 1),
      DimensionInfo(key: 'conventional', label: '常规型 C', type: 'interest', kind: 'likert', max: 1),
      DimensionInfo(key: 'artistic', label: '艺术型 A', type: 'interest', kind: 'likert', max: 1),
      DimensionInfo(key: 'openness', label: '开放性', type: 'personality', kind: 'likert', max: 1),
      DimensionInfo(key: 'motivation', label: '内在动机', type: 'eq', kind: 'likert', max: 1),
      DimensionInfo(key: 'empathy', label: '共情', type: 'eq', kind: 'likert', max: 1),
      DimensionInfo(key: 'social', label: '社会型 S', type: 'interest', kind: 'likert', max: 1),
    ];
    careers = const [];
    prizes = const [];
  }

  final record = AssessmentRecord(
    id: 1,
    finishedAt: DateTime(2026, 10, 20),
    scores: const {
      'leadership_drive': 0.8,
      'execution_focus': 0.7,
      'adaptability': 0.6,
      'investigative': 0.9,
      'logic': 0.8,
      'enterprising': 0.7,
      'social_skills': 0.7,
      'emotional_stability': 0.7,
      'self_regulation': 0.7,
      'conscientiousness': 0.8,
      'conventional': 0.6,
      'artistic': 0.5,
      'openness': 0.8,
      'motivation': 0.8,
      'empathy': 0.6,
      'social': 0.6,
    },
    answers: const {},
  );

  @override
  Future<AssessmentRecord?> latestResult() async => record;

  @override
  Future<List<AssessmentRecord>> resultHistory() async => [record];

  @override
  Future<List<String>> recommendations(Map<String, double> scores) async =>
      const [];

  @override
  Future<GuidanceContent> loadGuidanceContent() async => _guidanceContent();

  @override
  Future<void> lock() async {
    key = null;
  }
}

class _FailingGuidanceCoordinator extends _GuidanceCoordinator {
  @override
  Future<GuidanceContent> loadGuidanceContent() async =>
      throw Exception('bad guidance json');
}

class _GatedGuidanceCoordinator extends _GuidanceCoordinator {
  final gate = Completer<GuidanceContent>();
  int loadCalls = 0;

  @override
  Future<GuidanceContent> loadGuidanceContent() {
    loadCalls++;
    return gate.future;
  }
}

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('shows a message when guidance data fails to load',
      (tester) async {
    final coordinator = _FailingGuidanceCoordinator()
      ..key = List<int>.filled(32, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: RootFlow(
          coordinator: coordinator,
          audio: AudioService(silent: true),
          onExport: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('我'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('view_last_result')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('guidance_entry')));
    await tester.tap(find.byKey(const Key('guidance_entry')));
    await tester.pumpAndSettle();

    expect(find.text('建议数据加载失败'), findsOneWidget);
    expect(find.byKey(const Key('guidance_screen')), findsNothing);
  });

  testWidgets('opens guidance from the result screen', (tester) async {
    final coordinator = _GuidanceCoordinator()..key = List<int>.filled(32, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: RootFlow(
          coordinator: coordinator,
          audio: AudioService(silent: true),
          onExport: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('我'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('view_last_result')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('guidance_entry')));
    await tester.tap(find.byKey(const Key('guidance_entry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('guidance_screen')), findsOneWidget);
    expect(find.byKey(const Key('major_card_0')), findsOneWidget);
    expect(find.byKey(const Key('career_item_0')), findsOneWidget);
  });

  testWidgets('ignores a second guidance tap while the first is loading',
      (tester) async {
    final coordinator = _GatedGuidanceCoordinator()
      ..key = List<int>.filled(32, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: RootFlow(
          coordinator: coordinator,
          audio: AudioService(silent: true),
          onExport: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('我'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('view_last_result')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('guidance_entry')));
    await tester.tap(find.byKey(const Key('guidance_entry')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('guidance_entry')));
    await tester.pump();

    expect(coordinator.loadCalls, 1);

    coordinator.gate.complete(_guidanceContent());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('guidance_screen')), findsOneWidget);
  });
}
