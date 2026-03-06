import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sample_app/src/domain/models.dart';
import 'package:sample_app/src/domain/persona_diagnosis.dart';
import 'package:sample_app/src/infrastructure/api_client.dart';
import 'package:sample_app/src/presentation/diagnosis_screen.dart';

void main() {
  group('DiagnosisScreen エラーハンドリング', () {
    testWidgets('API エラー時に error_code ベースのメッセージを表示', (
      WidgetTester tester,
    ) async {
      // セットアップ：UPSTREAM_UNAVAILABLE エラーをシミュレート
      Future<DiagnosisResult> onCompletedWithError(
        List<DiagnosisAnswer> answers,
      ) async {
        throw ApiError(
          httpStatus: 503,
          errorCode: 'UPSTREAM_UNAVAILABLE',
          message: 'Service unavailable',
        );
      }

      await tester.pumpWidget(
        MaterialApp(home: DiagnosisScreen(onCompleted: onCompletedWithError)),
      );

      // すべての質問に回答
      for (var i = 0; i < diagnosisQuestions.length; i++) {
        final question = diagnosisQuestions[i];
        final choiceButton = find.text(question.choices.first.label);
        await tester.tap(choiceButton);
        await tester.pumpAndSettle();
      }

      // エラーメッセージが表示されることを確認
      expect(find.text('今は不安定みたい。少し待って、もう一度'), findsWidgets);

      // "もう一度" ボタンが表示されることを確認
      expect(find.text('もう一度'), findsWidgets);
    });

    testWidgets('RATE_LIMITED エラー時の適切なメッセージ', (WidgetTester tester) async {
      Future<DiagnosisResult> onCompletedWithRateLimit(
        List<DiagnosisAnswer> answers,
      ) async {
        throw ApiError(
          httpStatus: 429,
          errorCode: 'RATE_LIMITED',
          message: 'Rate limited',
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: DiagnosisScreen(onCompleted: onCompletedWithRateLimit),
        ),
      );

      // すべての質問に回答
      for (var i = 0; i < diagnosisQuestions.length; i++) {
        final question = diagnosisQuestions[i];
        final choiceButton = find.text(question.choices.first.label);
        await tester.tap(choiceButton);
        await tester.pumpAndSettle();
      }

      // RATE_LIMITED 用のメッセージを確認
      expect(find.text('少し混み合ってるみたい。少し待って、もう一度'), findsWidgets);
    });

    testWidgets('AUTH_INVALID エラー時の適切なメッセージ', (WidgetTester tester) async {
      Future<DiagnosisResult> onCompletedWithAuthError(
        List<DiagnosisAnswer> answers,
      ) async {
        throw ApiError(
          httpStatus: 401,
          errorCode: 'AUTH_INVALID',
          message: 'Auth invalid',
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: DiagnosisScreen(onCompleted: onCompletedWithAuthError),
        ),
      );

      // すべての質問に回答
      for (var i = 0; i < diagnosisQuestions.length; i++) {
        final question = diagnosisQuestions[i];
        final choiceButton = find.text(question.choices.first.label);
        await tester.tap(choiceButton);
        await tester.pumpAndSettle();
      }

      // AUTH エラー用のメッセージを確認
      expect(find.text('認証を更新したよ。もう一度ためしてね'), findsWidgets);
    });

    testWidgets('複数の error_code でのメッセージング', (WidgetTester tester) async {
      Future<DiagnosisResult> onCompletedWithValidationError(
        List<DiagnosisAnswer> answers,
      ) async {
        throw ApiError(
          httpStatus: 400,
          errorCode: 'VALIDATION_ERROR',
          message: 'Validation error',
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: DiagnosisScreen(onCompleted: onCompletedWithValidationError),
        ),
      );

      // すべての質問に回答
      for (var i = 0; i < diagnosisQuestions.length; i++) {
        final question = diagnosisQuestions[i];
        final choiceButton = find.text(question.choices.first.label);
        await tester.tap(choiceButton);
        await tester.pumpAndSettle();
      }

      // VALIDATION_ERROR 用のメッセージを確認
      expect(find.text('うまく読めなかった。もう一度ためしてね'), findsWidgets);
    });
  });
}
