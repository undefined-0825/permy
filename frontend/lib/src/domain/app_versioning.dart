int compareAppVersions(String left, String right) {
  final leftParts = _parseVersionParts(left);
  final rightParts = _parseVersionParts(right);

  final len = leftParts.length > rightParts.length
      ? leftParts.length
      : rightParts.length;

  for (var i = 0; i < len; i++) {
    final l = i < leftParts.length ? leftParts[i] : 0;
    final r = i < rightParts.length ? rightParts[i] : 0;
    if (l < r) return -1;
    if (l > r) return 1;
  }
  return 0;
}

List<int> _parseVersionParts(String value) {
  final normalized = value.split('+').first;
  final tokens = RegExp(r'\d+').allMatches(normalized);
  if (tokens.isEmpty) return const [0];
  return tokens
      .map((match) => int.tryParse(match.group(0) ?? '') ?? 0)
      .toList();
}
