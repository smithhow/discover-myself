import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/services/asset_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('six workstyle questions and three dimensions are bundled', () async {
    final loader = AssetLoader();
    final questions = await loader.questions();
    final workstyle =
        questions.where((q) => q.type == 'workstyle').toList(growable: false);
    expect(workstyle.length, 6);
    expect(
      workstyle.map((q) => q.id),
      containsAll(<String>['w1', 'w2', 'w3', 'w4', 'w5', 'w6']),
    );
    expect(workstyle.firstWhere((q) => q.id == 'w6').reverse, isTrue);

    final dimensions = await loader.dimensions();
    final workDims =
        dimensions.where((d) => d.type == 'workstyle').toList(growable: false);
    expect(workDims.length, 3);
    expect(
      workDims.map((d) => d.key),
      containsAll(<String>[
        'leadership_drive',
        'execution_focus',
        'adaptability',
      ]),
    );
  });
}
