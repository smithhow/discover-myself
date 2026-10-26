import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/models/assessment_record.dart';

void main() {
  test('parses scores and answers from a row', () {
    final record = AssessmentRecord.tryFromRow({
      'id': 7,
      'finished_at': 1000,
      'score_json': '{"a":3,"b":4.5}',
      'answers_json': '{"q1":2,"q2":4}',
    });

    expect(record, isNotNull);
    expect(record!.id, 7);
    expect(record.finishedAt.millisecondsSinceEpoch, 1000);
    expect(record.scores, {'a': 3.0, 'b': 4.5});
    expect(record.answers, {'q1': 2, 'q2': 4});
  });

  test('returns null for invalid score json', () {
    expect(
      AssessmentRecord.tryFromRow({
        'id': 1,
        'finished_at': 0,
        'score_json': 'not json',
      }),
      isNull,
    );
  });

  test('returns null when scores are empty', () {
    expect(
      AssessmentRecord.tryFromRow({
        'id': 1,
        'finished_at': 0,
        'score_json': '{}',
      }),
      isNull,
    );
  });
}
