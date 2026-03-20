import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sample_app/src/presentation/privacy_policy_screen.dart';
import 'package:sample_app/src/presentation/terms_of_service_screen.dart';

void main() {
  group('Legal Screens', () {
    testWidgets('利用規約の主要セクションが表示される', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: TermsOfServiceScreen()));

      expect(find.text('利用規約'), findsWidgets);
      expect(find.text('第1条（適用）'), findsOneWidget);
      expect(find.text('第10条（免責事項）'), findsOneWidget);
      expect(find.textContaining('隙間産業ラボ 中野家'), findsWidgets);
    });

    testWidgets('プライバシーポリシーの主要セクションが表示される', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrivacyPolicyScreen()));

      expect(find.text('プライバシーポリシー'), findsWidgets);
      expect(find.text('1. 基本方針'), findsOneWidget);
      expect(find.text('3. 保存しない情報（重要）'), findsOneWidget);
      expect(find.textContaining('本文および生成本文は永続保存しません'), findsOneWidget);
    });
  });
}
