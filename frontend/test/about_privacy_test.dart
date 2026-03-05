import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sample_app/src/presentation/about_privacy_screen.dart';

void main() {
  group('About/Privacy Screen', () {
    testWidgets('初期画面でタイトルが表示される', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AboutPrivacyScreen()),
      );

      expect(find.text('このアプリについて'), findsWidgets);
    });

    testWidgets('Permyについてセクションが表示される', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AboutPrivacyScreen()),
      );

      expect(find.text('Permyについて'), findsOneWidget);
      // ScrollView内のテキストは find.byType で Widget の存在確認
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('プライバシーセクションが表示される', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AboutPrivacyScreen()),
      );

      expect(find.text('プライバシーとセキュリティ'), findsOneWidget);
      expect(find.text('本文を保存しません'), findsOneWidget);
    });

    testWidgets('連絡先が表示される', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AboutPrivacyScreen()),
      );

      expect(find.text('お問い合わせ'), findsOneWidget);
      expect(find.text('support@permy.jp'), findsOneWidget);
    });
  });
}
