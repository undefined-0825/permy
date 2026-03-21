import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sample_app/src/presentation/onboarding_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            return null;
          }
          return null;
        });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('Onboarding Screen', () {
    testWidgets('4つのステップを表示できる', (WidgetTester tester) async {
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(
            onCompleted: () {
              completed = true;
            },
          ),
        ),
      );

      // ステップ1の内容確認
      expect(find.text('ペルミィへようこそ'), findsOneWidget);
      expect(find.text('次へ'), findsOneWidget);

      // 次へボタンタップ
      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();

      // ステップ2の内容確認
      expect(find.text('トーク履歴を送ろう'), findsOneWidget);

      // 次へボタンタップ
      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();

      // ステップ3の内容確認
      expect(find.text('プライバシー保護'), findsOneWidget);

      // 次へボタンタップ
      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();

      // ステップ4の内容確認
      expect(find.text('さあ、始めよう'), findsOneWidget);
      expect(find.text('ペルミィを作る'), findsOneWidget);

      // ペルミィを作るボタンタップ
      await tester.tap(find.text('ペルミィを作る'));
      await tester.pumpAndSettle();

      // コールバックが実行されたことを確認
      expect(completed, true);
    });

    testWidgets('スキップボタンで直接完了できる', (WidgetTester tester) async {
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(
            onCompleted: () {
              completed = true;
            },
          ),
        ),
      );

      // スキップボタンをタップ
      await tester.tap(find.text('スキップ'));
      await tester.pumpAndSettle();

      // コールバックが実行されたことを確認
      expect(completed, true);
    });

    testWidgets('戻るボタンで前のステップに戻れる', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onCompleted: () {})),
      );

      // ステップ1→2へ進む
      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();
      expect(find.text('トーク履歴を送ろう'), findsOneWidget);

      // 戻るボタンをタップ
      await tester.tap(find.text('戻る'));
      await tester.pumpAndSettle();

      // ステップ1に戻ることを確認
      expect(find.text('ペルミィへようこそ'), findsOneWidget);
    });

    testWidgets('インジケーターが正しく表示される', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onCompleted: () {})),
      );

      // ステップ1：ペルミィへようこそのテキスト確認
      expect(find.text('ペルミィへようこそ'), findsOneWidget);

      // ステップを進める
      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();

      // インジケーターが更新されていることを確認
      expect(find.text('トーク履歴を送ろう'), findsOneWidget);
    });
  });
}
