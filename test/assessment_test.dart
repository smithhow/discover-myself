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
}
