String trimHistoryForGenerate(String input, {required String plan}) {
  const freeLineLimit = 120;
  const freeCharLimit = 8000;
  const proLineLimit = 300;
  const proCharLimit = 18000;

  final isPro = plan == 'pro' || plan == 'premium';
  final maxLines = isPro ? proLineLimit : freeLineLimit;
  final maxChars = isPro ? proCharLimit : freeCharLimit;

  final normalized = input
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('\u0000', '')
      .trim();

  if (normalized.isEmpty) {
    return '';
  }

  final lines = normalized.split('\n');
  final recentLines = lines.length <= maxLines
      ? lines
      : lines.sublist(lines.length - maxLines);

  final joined = recentLines.join('\n').trim();
  if (joined.length <= maxChars) {
    return joined;
  }

  // 仕様に合わせて末尾（最新）優先で文字数トリムする。
  return joined.substring(joined.length - maxChars).trim();
}
