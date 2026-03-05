class DiagnosisQuestion {
  const DiagnosisQuestion(this.id, this.title);

  final String id;
  final String title;
}

class DiagnosisResult {
  const DiagnosisResult({
    required this.trueSelfType,
    required this.nightSelfType,
  });

  final String trueSelfType;
  final String nightSelfType;
}

const List<DiagnosisQuestion> diagnosisQuestions = [
  DiagnosisQuestion('q1', '返信は、丁寧さを優先したい'),
  DiagnosisQuestion('q2', '相手との距離はゆっくり縮めたい'),
  DiagnosisQuestion('q3', '感情よりも安定感を大事にしたい'),
  DiagnosisQuestion('q4', '短い文より、理由を添えたい'),
  DiagnosisQuestion('q5', '駆け引きより誠実さを選びたい'),
  DiagnosisQuestion('q6', '仕事中はテンポよく返したい'),
  DiagnosisQuestion('q7', '相手を前向きに動かす言い方が得意'),
  DiagnosisQuestion('q8', '少し甘めの言い回しを使える'),
  DiagnosisQuestion('q9', '次の約束につなげる提案がしやすい'),
  DiagnosisQuestion('q10', '相手に合わせて距離感を調整できる'),
  DiagnosisQuestion('q11', '押し引きの判断は早いほうだ'),
];

DiagnosisResult inferDiagnosis(List<int> answers) {
  final safe = List<int>.from(answers);
  while (safe.length < 11) {
    safe.add(3);
  }

  final trueScore = safe.take(5).fold<int>(0, (sum, value) => sum + value);
  final nightScore = safe.skip(5).take(6).fold<int>(0, (sum, value) => sum + value);

  final trueType = trueScore >= 18
      ? 'true_stability'
      : trueScore >= 15
      ? 'true_independence'
      : 'true_realism';

  final nightType = nightScore >= 24
      ? 'night_little_devil'
      : nightScore >= 20
      ? 'night_balance'
      : 'night_heal';

  return DiagnosisResult(
    trueSelfType: trueType,
    nightSelfType: nightType,
  );
}
