import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sample_app/src/presentation/persona_diagnosis_result_screen.dart';

void main() {
  group('Persona Diagnosis Result Screen', () {
    testWidgets('True タイプが正しく表示される', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PersonaDiagnosisResultScreen(
            trueType: 'Stability',
            nightType: 'Balance',
          ),
        ),
      );

      expect(find.text('普段の自分'), findsOneWidget);
      expect(find.text('安定重視タイプ'), findsOneWidget);
      expect(find.text('夜の私'), findsOneWidget);
    });

    testWidgets('Night タイプが正しく表示される', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PersonaDiagnosisResultScreen(
            trueType: 'Independence',
            nightType: 'Heal',
          ),
        ),
      );

      expect(find.text('癒し系タイプ'), findsOneWidget);
    });

    testWidgets('ペルソナパラメータが表示される', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PersonaDiagnosisResultScreen(
            trueType: 'Romance',
            nightType: 'LittleDevil',
            assertiveness: 75,
            warmth: 60,
            riskGuard: 40,
          ),
        ),
      );

      expect(find.text('ペルソナパラメータ'), findsOneWidget);
      expect(find.text('主張度'), findsOneWidget);
      expect(find.text('温かみ'), findsOneWidget);
      expect(find.text('リスク回避'), findsOneWidget);
    });

    testWidgets('AppBar にタイトルが表示される', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PersonaDiagnosisResultScreen(
            trueType: 'Realism',
            nightType: 'BigClient',
          ),
        ),
      );

      expect(find.text('きみのペルソナはこれだよ'), findsOneWidget);
    });
  });
}
