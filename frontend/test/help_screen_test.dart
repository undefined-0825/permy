import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sample_app/src/presentation/help_screen.dart';

void main() {
  testWidgets('ヘルプ画面の主要セクションが表示される', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HelpScreen()));

    expect(find.text('ヘルプ（使い方）'), findsWidgets);
    expect(find.text('1. はじめに'), findsOneWidget);
    expect(find.text('2. 基本の使い方'), findsOneWidget);
    expect(find.text('5. プライバシーについて'), findsOneWidget);
  });
}
