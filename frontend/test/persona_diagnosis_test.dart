import 'package:flutter_test/flutter_test.dart';
import 'package:sample_app/src/domain/persona_diagnosis.dart';

void main() {
  test('高スコアなら安定/攻め寄りに分類される', () {
    final result = inferDiagnosis(List<int>.filled(11, 5));
    expect(result.trueSelfType, 'true_stability');
    expect(result.nightSelfType, 'night_little_devil');
  });

  test('低スコアなら現実/癒し寄りに分類される', () {
    final result = inferDiagnosis(List<int>.filled(11, 1));
    expect(result.trueSelfType, 'true_realism');
    expect(result.nightSelfType, 'night_heal');
  });
}
