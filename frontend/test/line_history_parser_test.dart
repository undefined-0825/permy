import 'package:flutter_test/flutter_test.dart';
import 'package:sample_app/src/domain/line_history_parser.dart';

void main() {
  group('LineHistoryParser', () {
    group('Android形式（タブ区切り）', () {
      test('2名のトークを正しく抽出する', () {
        const text = '''
2025/01/15(水)
12:34\t田中太郎\tこんにちは
12:35\t山田花子\tおはよう
12:36\t田中太郎\t今日どうする？
''';
        final result = LineHistoryParser.parse(text);
        expect(result, isA<LineDuoResult>());
        final duo = result as LineDuoResult;
        expect(duo.names, containsAll(['田中太郎', '山田花子']));
        expect(duo.names.length, 2);
      });

      test('3名以上はLineGroupResultを返す', () {
        const text = '''
12:00\t田中太郎\tメッセージA
12:01\t山田花子\tメッセージB
12:02\t鈴木一郎\tメッセージC
''';
        final result = LineHistoryParser.parse(text);
        expect(result, isA<LineGroupResult>());
      });
    });

    group('iOS形式（全角スペース区切り）', () {
      test('2名のトークを正しく抽出する', () {
        const text = '''
2025/01/15(水)
12:34　田中太郎　こんにちは
12:35　山田花子　おはよう
12:36　田中太郎　また明日
''';
        final result = LineHistoryParser.parse(text);
        expect(result, isA<LineDuoResult>());
        final duo = result as LineDuoResult;
        expect(duo.names, containsAll(['田中太郎', '山田花子']));
      });
    });

    group('古いiOS形式（[午前HH:MM]）', () {
      test('2名のトークを正しく抽出する', () {
        const text = '''
[午前12:34] 田中太郎
こんにちは
[午前12:35] 山田花子
おはよう
[午後1:00] 田中太郎
また明日
''';
        final result = LineHistoryParser.parse(text);
        expect(result, isA<LineDuoResult>());
        final duo = result as LineDuoResult;
        expect(duo.names, containsAll(['田中太郎', '山田花子']));
      });
    });

    group('エラーケース', () {
      test('空テキストはLineUnknownResultを返す', () {
        final result = LineHistoryParser.parse('');
        expect(result, isA<LineUnknownResult>());
      });

      test('名前が抽出できない場合はLineUnknownResultを返す', () {
        const text = '''
これはただのテキストです。
LINEのフォーマットではありません。
''';
        final result = LineHistoryParser.parse(text);
        expect(result, isA<LineUnknownResult>());
      });

      test('重複名は1人として数える', () {
        const text = '''
12:00\t田中太郎\tメッセージ1
12:01\t田中太郎\tメッセージ2
12:02\t山田花子\tメッセージ3
''';
        final result = LineHistoryParser.parse(text);
        expect(result, isA<LineDuoResult>());
      });
    });

    group('日付行の除外', () {
      test('YYYY/MM/DD形式の日付行は名前として抽出しない', () {
        const text = '''
2025/01/15(水)
12:34\t田中太郎\tこんにちは
12:35\t山田花子\tおはよう
''';
        final result = LineHistoryParser.parse(text);
        final duo = result as LineDuoResult;
        expect(duo.names, isNot(contains('2025/01/15(水)')));
      });
    });
  });
}
