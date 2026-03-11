/// ペルソナタイプの表示名変換ヘルパー

/// True Self タイプ名を日本語で返す
String getTrueSelfTypeName(String typeValue) {
  switch (_normalizeTypeValue(typeValue)) {
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
      return typeValue.trim();
  }
}

/// Night Self タイプ名を日本語で返す
String getNightSelfTypeName(String typeValue) {
  switch (_normalizeTypeValue(typeValue)) {
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
      return typeValue.trim();
  }
}

String _normalizeTypeValue(String typeValue) {
  final trimmed = typeValue.trim();
  switch (trimmed.toLowerCase()) {
    case 'stability':
      return 'Stability';
    case 'independence':
      return 'Independence';
    case 'approval':
      return 'Approval';
    case 'realism':
      return 'Realism';
    case 'romance':
      return 'Romance';
    case 'visitpush':
      return 'VisitPush';
    case 'heal':
      return 'Heal';
    case 'littledevil':
      return 'LittleDevil';
    case 'bigclient':
      return 'BigClient';
    case 'balance':
      return 'Balance';
    default:
      return trimmed;
  }
}

/// True Self タイプ画像のアセットパスを返す
String? getTrueSelfTypeImagePath(String typeValue) {
  switch (_normalizeTypeValue(typeValue)) {
    case 'Stability':
      return 'assets/images/self_type/TrueStability.png';
    case 'Independence':
      return 'assets/images/self_type/TrueIndependence.png';
    case 'Approval':
      return 'assets/images/self_type/TrueApproval.png';
    case 'Realism':
      return 'assets/images/self_type/TrueRealism.png';
    case 'Romance':
      return 'assets/images/self_type/TrueRomance.png';
    default:
      return null;
  }
}

/// Night Self タイプ画像のアセットパスを返す
String? getNightSelfTypeImagePath(String typeValue) {
  switch (_normalizeTypeValue(typeValue)) {
    case 'VisitPush':
      return 'assets/images/self_type/NightVisitPush.png';
    case 'Heal':
      return 'assets/images/self_type/NightHeal.png';
    case 'LittleDevil':
      return 'assets/images/self_type/NightLittleDevil.png';
    case 'BigClient':
      return 'assets/images/self_type/NightBigClient.png';
    case 'Balance':
      return 'assets/images/self_type/NightBalance.png';
    default:
      return null;
  }
}
