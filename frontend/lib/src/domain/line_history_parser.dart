// LINE .txt から送信者名を抽出するパーサー
// Android（タブ区切り）/ iOS（全角スペース区切り）両対応

sealed class LineParseResult {
  const LineParseResult();
}

/// 2名のトーク → 正常
final class LineDuoResult extends LineParseResult {
  const LineDuoResult(this.names);
  final List<String> names; // 必ず2要素
}

/// 3名以上 → グループトーク
final class LineGroupResult extends LineParseResult {
  const LineGroupResult(this.names);
  final List<String> names;
}

/// パース不能
final class LineUnknownResult extends LineParseResult {
  const LineUnknownResult();
}

/// LINE トーク履歴テキストから送信者名セットを抽出する
class LineHistoryParser {
  // HH:MM\t名前\t（タブ区切り・Android / 新iOS）
  static final _tabPattern = RegExp(r'^\d{1,2}:\d{2}\t(.+?)\t');

  // HH:MM　名前　（全角スペース区切り・iOS一部）
  static final _wideSpacePattern = RegExp(r'^\d{1,2}:\d{2}　(.+?)　');

  // [午前HH:MM] 名前 （古いiOS形式）
  static final _ampmBracketPattern = RegExp(r'^\[午[前後]\d{1,2}:\d{2}\] (.+)$');

  // 日付行（除外対象）
  static final _dateLine = RegExp(r'^\d{4}[/年]\d{1,2}[/月]\d{1,2}|^[月火水木金土日]曜日');

  static LineParseResult parse(String text) {
    final names = <String>{};

    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (_dateLine.hasMatch(trimmed)) continue;

      final name = _extractName(trimmed);
      if (name != null && name.isNotEmpty) {
        names.add(name);
      }
    }

    if (names.length == 2) {
      return LineDuoResult(names.toList());
    }
    if (names.length > 2) {
      return LineGroupResult(names.toList());
    }
    return const LineUnknownResult();
  }

  static String? _extractName(String line) {
    // タブ区切り
    final tabMatch = _tabPattern.firstMatch(line);
    if (tabMatch != null) return tabMatch.group(1)?.trim();

    // 全角スペース区切り
    final wideMatch = _wideSpacePattern.firstMatch(line);
    if (wideMatch != null) return wideMatch.group(1)?.trim();

    // 古いiOS形式 [午前HH:MM] 名前
    final ampmMatch = _ampmBracketPattern.firstMatch(line);
    if (ampmMatch != null) return ampmMatch.group(1)?.trim();

    return null;
  }
}
