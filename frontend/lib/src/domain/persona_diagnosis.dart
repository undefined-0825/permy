class DiagnosisChoice {
  const DiagnosisChoice(this.id, this.label);

  final String id;
  final String label;
}

class DiagnosisQuestion {
  const DiagnosisQuestion({
    required this.id,
    required this.title,
    required this.choices,
  });

  final String id;
  final String title;
  final List<DiagnosisChoice> choices;
}

class DiagnosisAnswer {
  const DiagnosisAnswer({required this.questionId, required this.choiceId});

  final String questionId;
  final String choiceId;

  Map<String, dynamic> toJson() => {
    'question_id': questionId,
    'choice_id': choiceId,
  };
}

class DiagnosisResult {
  const DiagnosisResult({
    required this.trueSelfType,
    required this.nightSelfType,
    required this.personaGoalPrimary,
    required this.personaGoalSecondary,
    required this.styleAssertiveness,
    required this.styleWarmth,
    required this.styleRiskGuard,
  });

  final String trueSelfType;
  final String nightSelfType;
  final String personaGoalPrimary;
  final String? personaGoalSecondary;
  final int styleAssertiveness;
  final int styleWarmth;
  final int styleRiskGuard;
}

const List<DiagnosisQuestion> diagnosisQuestions = [
  DiagnosisQuestion(
    id: 'true_priority',
    title: '普段いちばん大切にしているもの？',
    choices: [
      DiagnosisChoice('life_balance', 'ライフバランス'),
      DiagnosisChoice('future_stability', '将来の安定'),
      DiagnosisChoice('partner_time', 'パートナーとの時間'),
      DiagnosisChoice('social_trust', '周りの人からの評価・信頼'),
      DiagnosisChoice('self_autonomy', '自分の価値観・自由'),
    ],
  ),
  DiagnosisQuestion(
    id: 'true_decision_axis',
    title: '迷った時はどうする？',
    choices: [
      DiagnosisChoice('low_stress', '無理が少ない方にする'),
      DiagnosisChoice('long_term_return', '長期的に得な方にする'),
      DiagnosisChoice('emotional_satisfaction', '気持ちが満たされる方にする'),
      DiagnosisChoice('pace_control', '自分のペースを守れる方にする'),
    ],
  ),
  DiagnosisQuestion(
    id: 'night_goal_primary',
    title: '夜職のLINE返信で一番達成したいことは？',
    choices: [
      DiagnosisChoice('next_visit', '次回来店の約束'),
      DiagnosisChoice('relationship_keep', 'お客様との関係を維持する'),
      DiagnosisChoice('special_distance', '特別感を出して距離を縮める'),
      DiagnosisChoice('long_term_growth', '長期で太く育成したい'),
    ],
  ),
  DiagnosisQuestion(
    id: 'night_temperature',
    title: '返信の温度感は？',
    choices: [
      DiagnosisChoice('calm_safe', '安心感を重視する'),
      DiagnosisChoice('sweet_light', '軽く甘めに攻めてみる'),
      DiagnosisChoice('clear_proposal', '自分の考えをはっきり伝える'),
      DiagnosisChoice('adaptive', '相手に合わせる'),
    ],
  ),
  DiagnosisQuestion(
    id: 'night_game_tolerance',
    title: 'お客様との駆け引きは？',
    choices: [
      DiagnosisChoice('avoid_game', 'ほぼ使わない'),
      DiagnosisChoice('light_game', '少しなら使う'),
      DiagnosisChoice('adaptive_game', '状況次第で使う'),
      DiagnosisChoice('active_game', '積極的に使う'),
    ],
  ),
  DiagnosisQuestion(
    id: 'night_customer_allocation',
    title: 'お客様との関係をどうしたい？',
    choices: [
      DiagnosisChoice('wide_touchpoints', '幅広く接点を増やす'),
      DiagnosisChoice('care_existing', '今ある関係を丁寧に維持したい'),
      DiagnosisChoice('focus_key_clients', '重要なお客を大切にする'),
      DiagnosisChoice('dynamic_balance', '状況で配分を切り替える'),
    ],
  ),
  DiagnosisQuestion(
    id: 'night_risk_response',
    title: 'お客様とトラブル。どうする？',
    choices: [
      DiagnosisChoice('firefighting_safe', 'まずは火消しして安全を確保'),
      DiagnosisChoice('soft_distance', '柔らかく距離を保つ'),
      DiagnosisChoice('recover_initiative', '主導権を握って解決'),
      DiagnosisChoice('adaptive_landing', '相手に合わせて様子を見る'),
    ],
  ),
];

DiagnosisResult inferDiagnosis(List<DiagnosisAnswer> answers) {
  final answerMap = <String, String>{
    for (final answer in answers) answer.questionId: answer.choiceId,
  };

  final trueScores = {
    'Stability': 0,
    'Independence': 0,
    'Approval': 0,
    'Realism': 0,
    'Romance': 0,
  };
  final nightScores = {
    'VisitPush': 0,
    'Heal': 0,
    'LittleDevil': 0,
    'BigClient': 0,
    'Balance': 0,
  };

  const trueWeights = {
    'true_priority:life_balance': {
      'Stability': 3,
      'Independence': 1,
      'Realism': 1,
    },
    'true_priority:future_stability': {
      'Stability': 2,
      'Independence': 1,
      'Realism': 3,
    },
    'true_priority:partner_time': {'Stability': 1, 'Approval': 1, 'Romance': 3},
    'true_priority:social_trust': {'Approval': 3, 'Realism': 1, 'Romance': 1},
    'true_priority:self_autonomy': {
      'Stability': 1,
      'Independence': 3,
      'Realism': 1,
    },
    'true_decision_axis:low_stress': {
      'Stability': 3,
      'Independence': 1,
      'Realism': 2,
    },
    'true_decision_axis:long_term_return': {
      'Stability': 1,
      'Independence': 1,
      'Realism': 3,
    },
    'true_decision_axis:emotional_satisfaction': {'Approval': 2, 'Romance': 3},
    'true_decision_axis:pace_control': {
      'Stability': 1,
      'Independence': 3,
      'Realism': 1,
    },
  };

  const nightWeights = {
    'night_goal_primary:next_visit': {
      'VisitPush': 3,
      'LittleDevil': 1,
      'BigClient': 2,
      'Balance': 1,
    },
    'night_goal_primary:relationship_keep': {
      'VisitPush': 1,
      'Heal': 3,
      'BigClient': 1,
      'Balance': 2,
    },
    'night_goal_primary:special_distance': {
      'VisitPush': 1,
      'LittleDevil': 3,
      'BigClient': 1,
      'Balance': 1,
    },
    'night_goal_primary:long_term_growth': {
      'VisitPush': 1,
      'Heal': 1,
      'BigClient': 3,
      'Balance': 2,
    },
    'night_temperature:calm_safe': {'Heal': 3, 'BigClient': 1, 'Balance': 2},
    'night_temperature:sweet_light': {
      'VisitPush': 1,
      'Heal': 1,
      'LittleDevil': 3,
      'Balance': 1,
    },
    'night_temperature:clear_proposal': {
      'VisitPush': 3,
      'LittleDevil': 1,
      'BigClient': 2,
      'Balance': 1,
    },
    'night_temperature:adaptive': {
      'VisitPush': 1,
      'Heal': 2,
      'LittleDevil': 1,
      'BigClient': 2,
      'Balance': 3,
    },
    'night_game_tolerance:avoid_game': {
      'Heal': 3,
      'BigClient': 2,
      'Balance': 2,
    },
    'night_game_tolerance:light_game': {
      'VisitPush': 1,
      'Heal': 1,
      'LittleDevil': 2,
      'BigClient': 1,
      'Balance': 3,
    },
    'night_game_tolerance:adaptive_game': {
      'VisitPush': 2,
      'Heal': 1,
      'LittleDevil': 2,
      'BigClient': 2,
      'Balance': 3,
    },
    'night_game_tolerance:active_game': {
      'VisitPush': 2,
      'LittleDevil': 3,
      'BigClient': 1,
      'Balance': 1,
    },
    'night_customer_allocation:wide_touchpoints': {
      'VisitPush': 3,
      'Heal': 1,
      'LittleDevil': 1,
      'BigClient': 1,
      'Balance': 1,
    },
    'night_customer_allocation:care_existing': {
      'VisitPush': 1,
      'Heal': 3,
      'BigClient': 2,
      'Balance': 2,
    },
    'night_customer_allocation:focus_key_clients': {
      'VisitPush': 1,
      'LittleDevil': 1,
      'BigClient': 3,
      'Balance': 1,
    },
    'night_customer_allocation:dynamic_balance': {
      'VisitPush': 1,
      'Heal': 2,
      'LittleDevil': 1,
      'BigClient': 2,
      'Balance': 3,
    },
    'night_risk_response:firefighting_safe': {
      'VisitPush': 1,
      'Heal': 2,
      'BigClient': 2,
      'Balance': 3,
    },
    'night_risk_response:soft_distance': {
      'Heal': 3,
      'BigClient': 1,
      'Balance': 2,
    },
    'night_risk_response:recover_initiative': {
      'VisitPush': 3,
      'LittleDevil': 2,
      'BigClient': 1,
      'Balance': 1,
    },
    'night_risk_response:adaptive_landing': {
      'VisitPush': 1,
      'Heal': 2,
      'LittleDevil': 1,
      'BigClient': 2,
      'Balance': 3,
    },
  };

  for (final entry in answerMap.entries) {
    final key = '${entry.key}:${entry.value}';
    final t = trueWeights[key];
    if (t != null) {
      for (final s in t.entries) {
        trueScores[s.key] = (trueScores[s.key] ?? 0) + s.value;
      }
    }
    final n = nightWeights[key];
    if (n != null) {
      for (final s in n.entries) {
        nightScores[s.key] = (nightScores[s.key] ?? 0) + s.value;
      }
    }
  }

  final trueSelfType = _pickTop(trueScores, [
    'Stability',
    'Realism',
    'Independence',
    'Approval',
    'Romance',
  ]);
  final nightSelfType = _pickTop(nightScores, [
    'Balance',
    'BigClient',
    'VisitPush',
    'Heal',
    'LittleDevil',
  ]);

  String primary;
  switch (answerMap['night_goal_primary']) {
    case 'next_visit':
      primary = 'next_visit';
      break;
    case 'special_distance':
      primary = 'special_distance';
      break;
    case 'long_term_growth':
      primary = 'long_term_growth';
      break;
    default:
      primary = 'relationship_keep';
  }

  if (answerMap['night_risk_response'] == 'firefighting_safe' &&
      ((nightScores['Balance'] ?? 0) >= (nightScores['LittleDevil'] ?? 0) ||
          (nightScores['Heal'] ?? 0) >= (nightScores['VisitPush'] ?? 0))) {
    primary = 'firefighting';
  }

  final assertiveness = _normalize(
    (nightScores['VisitPush'] ?? 0) + (nightScores['LittleDevil'] ?? 0),
    0,
    24,
  );
  final warmth = _normalize(
    (nightScores['Heal'] ?? 0) + (nightScores['Balance'] ?? 0),
    0,
    24,
  );
  final safeBonus =
      {
        'firefighting_safe': 4,
        'adaptive_landing': 4,
      }[answerMap['night_risk_response']] ??
      0;
  final riskGuard = _normalize(
    (nightScores['Balance'] ?? 0) + safeBonus,
    0,
    16,
  );

  return DiagnosisResult(
    trueSelfType: trueSelfType,
    nightSelfType: nightSelfType,
    personaGoalPrimary: primary,
    personaGoalSecondary: _secondaryGoal(primary, nightScores),
    styleAssertiveness: assertiveness,
    styleWarmth: warmth,
    styleRiskGuard: riskGuard,
  );
}

String _pickTop(Map<String, int> scores, List<String> tieOrder) {
  var maxValue = -1;
  for (final value in scores.values) {
    if (value > maxValue) {
      maxValue = value;
    }
  }

  for (final key in tieOrder) {
    if ((scores[key] ?? 0) == maxValue) {
      return key;
    }
  }
  return tieOrder.first;
}

String? _secondaryGoal(String primary, Map<String, int> nightScores) {
  const mapping = {
    'VisitPush': 'next_visit',
    'Heal': 'relationship_keep',
    'LittleDevil': 'special_distance',
    'BigClient': 'long_term_growth',
    'Balance': 'relationship_keep',
  };
  final ordered = nightScores.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  if (ordered.length < 2) return null;
  final secondary = mapping[ordered[1].key];
  if (secondary == null || secondary == primary) {
    return null;
  }
  return secondary;
}

int _normalize(int value, int minValue, int maxValue) {
  if (maxValue <= minValue) return 0;
  final bounded = value.clamp(minValue, maxValue);
  return (((bounded - minValue) * 100) / (maxValue - minValue)).round();
}
