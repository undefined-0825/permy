import 'package:flutter_test/flutter_test.dart';
import 'package:sample_app/src/domain/history_text.dart';

void main() {
  test('Freeは末尾120行かつ8000文字にトリムする', () {
    final lines = List<String>.generate(150, (index) => 'line-${index + 1}');
    final longLine = List<String>.filled(8200, 'A').join();
    final source = '${lines.join('\n')}\n$longLine';

    final trimmed = trimHistoryForGenerate(source, plan: 'free');

    expect(trimmed.length, lessThanOrEqualTo(8000));
    expect(trimmed.contains('line-1'), isFalse);
  });

  test('Proは末尾300行かつ18000文字にトリムする', () {
    final lines = List<String>.generate(360, (index) => 'line-${index + 1}');
    final source = lines.join('\n');

    final trimmed = trimHistoryForGenerate(source, plan: 'pro');

    expect(trimmed.split('\n').length, lessThanOrEqualTo(300));
    expect(trimmed.contains('line-1'), isFalse);
    expect(trimmed.contains('line-360'), isTrue);
  });

  test('空白だけの入力は空文字を返す', () {
    final trimmed = trimHistoryForGenerate('  \n\r\n  ', plan: 'free');

    expect(trimmed, '');
  });
}
