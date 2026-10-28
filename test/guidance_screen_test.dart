import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/models/guidance.dart';
import 'package:discover_self/src/ui/result/guidance_screen.dart';

GuidanceReport _report({bool hasWorkstyle = true, bool empty = false}) =>
    GuidanceReport(
      majors: empty
          ? const []
          : [
              MajorFit(
                cluster: '计算机与人工智能',
                summary: '编程、算法与数据。',
                majors: const ['软件工程', '人工智能'],
                fit: 0.82,
                reasons: const ['你的研究型 I（90%）与该方向匹配'],
                caution: null,
              ),
            ],
      careers: empty
          ? const []
          : [
              CareerFit(
                name: '软件工程师',
                cluster: '计算机与人工智能',
                fit: 0.80,
                reasons: const ['你的研究型 I（90%）与该方向匹配'],
                entry: '从编程实习或初级开发岗位进入。',
              ),
            ],
      leadership: LeadershipProfile(
        type: LeadershipType.hybrid,
        leadership: 0.70,
        execution: 0.66,
        professionalDepth: 0.60,
        reasons: const ['领导意愿（80%）', '执行偏好（75%）', '研究型 I（70%）'],
        tips: const ['从小团队负责人开始。', '练习授权与反馈。', '培养战略视角。'],
      ),
      nextSteps: const [
        '先了解「计算机与人工智能」下软件工程、人工智能的课程设置与就业方向。',
        '找 1-2 位「软件工程师」从业者做信息访谈。',
        '从小团队负责人开始。',
        '用 3 个月做一次小范围尝试，再回来复测。',
      ],
      hasWorkstyle: hasWorkstyle,
    );

void main() {
  testWidgets('renders all guidance sections', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GuidanceScreen(report: _report(), profileName: '我'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('guidance_screen')), findsOneWidget);
    expect(find.byKey(const Key('guidance_majors')), findsOneWidget);
    expect(find.byKey(const Key('major_card_0')), findsOneWidget);
    expect(find.byKey(const Key('guidance_careers')), findsOneWidget);
    expect(find.byKey(const Key('career_item_0')), findsOneWidget);
    expect(find.byKey(const Key('guidance_leadership')), findsOneWidget);
    expect(find.byKey(const Key('leadership_type')), findsOneWidget);
    expect(find.text('混合型'), findsOneWidget);
    expect(find.byKey(const Key('leadership_bar')), findsOneWidget);
    expect(find.byKey(const Key('execution_bar')), findsOneWidget);
    expect(find.byKey(const Key('guidance_next_steps')), findsOneWidget);
    expect(find.textContaining('软件工程师'), findsWidgets);
  });

  testWidgets('shows the reference note when workstyle is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GuidanceScreen(
          report: _report(hasWorkstyle: false),
          profileName: '我',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guidance_reference_note')), findsOneWidget);
    expect(find.byKey(const Key('leadership_type')), findsOneWidget);
  });

  testWidgets('shows empty guidance but still renders leadership', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GuidanceScreen(report: _report(empty: true), profileName: '我'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('暂无可用建议'), findsNWidgets(3));
    expect(find.byKey(const Key('leadership_type')), findsOneWidget);
  });
}
