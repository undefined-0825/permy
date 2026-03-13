import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sample_app/src/presentation/about_privacy_screen.dart';

void main() {
  group('About/Privacy Screen', () {
    testWidgets('初期画面でタイトルが表示される', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: AboutPrivacyScreen()));

      expect(find.text('このアプリについて'), findsWidgets);
    });

    testWidgets('Permyについてセクションが表示される', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: AboutPrivacyScreen()));

      expect(find.text('Permyについて'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('プライバシーセクションが表示される', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: AboutPrivacyScreen()));

      expect(find.text('プライバシーとセキュリティ'), findsOneWidget);
      expect(find.text('本文を保存しません'), findsOneWidget);
    });

    testWidgets('連絡先が表示される', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: AboutPrivacyScreen()));

      expect(find.text('お問い合わせ'), findsOneWidget);
      expect(find.text('sukima.lab.nakanoya@gmail.com'), findsWidgets);
    });

    testWidgets('発行者情報が表示される', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: AboutPrivacyScreen()));

      expect(find.text('発行者'), findsOneWidget);
      expect(find.text('隙間産業ラボ 中野家'), findsOneWidget);
    });
  });
}
