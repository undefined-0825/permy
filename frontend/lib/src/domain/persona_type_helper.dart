/// ペルソナタイプの表示名変換ヘルパー

/// True Self タイプ名を日本語で返す
String getTrueSelfTypeName(String typeValue) {
  switch (typeValue) {
    case 'Stability':
      return '安定重視タイプ';
    case 'Independence':
      return '自立タイプ';
    case 'Approval':
      return '承認欲求タイプ';
    case 'Realism':
      return '現実派タイプ';
    case 'Romance':
      return 'ロマンタイプ';
    default:
      return typeValue;
  }
}

/// Night Self タイプ名を日本語で返す
String getNightSelfTypeName(String typeValue) {
  switch (typeValue) {
    case 'VisitPush':
      return '来店重視タイプ';
    case 'Heal':
      return '癒しタイプ';
    case 'LittleDevil':
      return '小悪魔タイプ';
    case 'BigClient':
      return '太客育成タイプ';
    case 'Balance':
      return 'バランスタイプ';
    default:
      return typeValue;
  }
}
