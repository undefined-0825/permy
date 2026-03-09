import 'package:flutter_test/flutter_test.dart';
import 'package:sample_app/src/domain/persona_diagnosis.dart';

void main() {
  test('導入設問からタイプと目的を判定できる', () {
    final result = inferDiagnosis([
      const DiagnosisAnswer(
        questionId: 'true_priority',
        choiceId: 'life_balance',
      ),
      const DiagnosisAnswer(
        questionId: 'true_decision_axis',
        choiceId: 'low_stress',
      ),
      const DiagnosisAnswer(
        questionId: 'night_goal_primary',
        choiceId: 'next_visit',
      ),
      const DiagnosisAnswer(
        questionId: 'night_temperature',
        choiceId: 'clear_proposal',
      ),
      const DiagnosisAnswer(
        questionId: 'night_game_tolerance',
        choiceId: 'adaptive_game',
      ),
      const DiagnosisAnswer(
        questionId: 'night_customer_allocation',
        choiceId: 'wide_touchpoints',
      ),
      const DiagnosisAnswer(
        questionId: 'night_risk_response',
        choiceId: 'recover_initiative',
      ),
    ]);

    expect(result.trueSelfType, 'Stability');
    expect(result.nightSelfType, 'VisitPush');
    expect(result.personaGoalPrimary, 'next_visit');
    expect(result.styleAssertiveness, greaterThan(50));
  });
}
