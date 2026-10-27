import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/models/question.dart';
import 'package:discover_self/src/services/assessment.dart';

void main() {
  final qs = [
    const Question(id: 'p1', type: 'personality', dimension: 'openness', text: 't', options: ['a', 'b', 'c', 'd']),
    const Question(id: 'p2', type: 'personality', dimension: 'openness', text: 't', options: ['a', 'b', 'c', 'd']),
    const Question(id: 'p3', type: 'personality', dimension: 'extraversion', text: 't', options: ['a', 'b', 'c', 'd']),
  ];

  test('averages per dimension', () {
    final s = AssessmentService(qs).score({'p1': 4, 'p2': 2, 'p3': 3});
    expect(s['openness'], closeTo(3.0, 0.001));
    expect(s['extraversion'], closeTo(3.0, 0.001));
  });

  test('missing answers ignored', () {
    final s = AssessmentService(qs).score({'p1': 4});
    expect(s['openness'], closeTo(4.0, 0.001));
  });

  test('reverse-scored items are inverted before averaging', () {
    final rq = [
      const Question(id: 'a', type: 'personality', dimension: 'openness', text: 't', options: ['1', '2', '3', '4', '5'], reverse: true),
      const Question(id: 'b', type: 'personality', dimension: 'openness', text: 't', options: ['1', '2', '3', '4', '5']),
    ];
    // a: 5 -> inverted to 1; b: 5 -> 5; mean = 3.
    final s = AssessmentService(rq).score({'a': 5, 'b': 5});
    expect(s['openness'], closeTo(3.0, 0.001));
  });

  test('choice dimensions are scored as fraction correct', () {
    final cq = [
      const Question(id: 'q1', type: 'iq', dimension: 'logic', kind: 'choice', text: 't', options: ['a', 'b', 'c', 'd'], correct: 2),
      const Question(id: 'q2', type: 'iq', dimension: 'logic', kind: 'choice', text: 't', options: ['a', 'b', 'c', 'd'], correct: 3),
    ];
    // q1 correct, q2 wrong -> 1/2.
    final s = AssessmentService(cq).score({'q1': 2, 'q2': 1});
    expect(s['logic'], closeTo(0.5, 0.001));
  });
}
