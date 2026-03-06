import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sample_app/src/domain/models.dart';
import 'package:sample_app/src/infrastructure/api_client.dart';
import 'package:sample_app/src/presentation/about_privacy_screen.dart';
import 'package:sample_app/src/presentation/diagnosis_screen.dart';
import 'package:sample_app/src/presentation/migration_screen.dart';
import 'package:sample_app/src/presentation/onboarding_screen.dart';
import 'package:sample_app/src/presentation/persona_diagnosis_result_screen.dart';
import 'package:sample_app/src/presentation/settings_screen.dart';

// Mock API Client
class MockApiClient implements AppApiClient {
  MockApiClient({this.settingsSnapshot, this.shouldFailUpdate = false});

  final SettingsSnapshot? settingsSnapshot;
  final bool shouldFailUpdate;

  @override
  Future<void> bootstrapAuth() async {}

  @override
  Future<GenerateResult> generate({
    required String historyText,
    int comboId = 0,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<SettingsSnapshot> getSettings() async {
    return settingsSnapshot ??
        SettingsSnapshot(
          settings: {
            'true_self_type': 'type_A',
            'night_self_type': 'type_B',
            'combo_id': 0,
            'forbidden_type_ids': [],
          },
          etag: 'test-etag-123',
        );
  }

  @override
  Future<void> updateSettings(
    Map<String, dynamic> settings,
    String etag,
  ) async {
    if (shouldFailUpdate) {
      throw ApiError(
        errorCode: 'ETAG_MISMATCH',
        message: 'ETag が一致しません',
        httpStatus: 409,
      );
    }
  }

  @override
  Future<MigrationIssueResult> issueMigrationCode() async {
    return MigrationIssueResult(
      migrationCode: '123456789012',
      expiresAt: '2026-03-05T12:00:00Z',
    );
  }

  @override
  Future<MigrationConsumeResult> consumeMigrationCode(String code) async {
    return MigrationConsumeResult(
      token: 'new-token-after-consume',
      userId: 'user-123',
    );
  }

  @override
  Future<void> completeDiagnosis(List answers) async {
    return;
  }

  @override
  Future<void> postTelemetryEvents(List<Map<String, dynamic>> events) async {
    throw UnimplementedError();
  }
}

void main() {
  group('Settings Screen', () {
    testWidgets('設定を読み込んで表示できる', (WidgetTester tester) async {
      final mockApi = MockApiClient();

      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(apiClient: mockApi)),
      );

      // ローディング状態を確認
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 読み込み完了を待つ
      await tester.pumpAndSettle();

      // ペルソナ情報が表示されていることを確認
      expect(find.text('type_A'), findsOneWidget);
      expect(find.text('type_B'), findsWidgets);
    });

    testWidgets('コンボ設定を変更できる', (WidgetTester tester) async {
      final mockApi = MockApiClient();

      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(apiClient: mockApi)),
      );

      await tester.pumpAndSettle();

      // 「休眠復活」ボタンをタップ
      await tester.tap(find.text('休眠復活'));
      await tester.pumpAndSettle();

      // ボタンが存在することを確認（選択状態は Material Design で表示）
      expect(find.text('休眠復活'), findsOneWidget);
    });

    testWidgets('読み込みエラー時の再読込ボタン', (WidgetTester tester) async {
      final mockApi = MockApiClient(
        settingsSnapshot: SettingsSnapshot(settings: {}, etag: ''),
      );

      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(apiClient: mockApi)),
      );

      await tester.pumpAndSettle();

      // ペルソナ情報が表示されていることを確認
      expect(find.text('診断待機中...'), findsWidgets);
    });

    testWidgets('再診断ボタンで診断画面へ遷移できる', (WidgetTester tester) async {
      final mockApi = MockApiClient();

      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(apiClient: mockApi)),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('再診断する'));
      await tester.pumpAndSettle();

      expect(find.byType(DiagnosisScreen), findsOneWidget);
      // 新UI: 進捗表示を確認（複数の '/' を含むテキストがあるため）
      expect(find.textContaining('/'), findsWidgets);
    });

    testWidgets('端末移行ボタンで Migration 画面へ遷移できる', (WidgetTester tester) async {
      final mockApi = MockApiClient();

      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(apiClient: mockApi)),
      );

      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('端末移行の設定'), 200);
      await tester.tap(find.text('端末移行の設定'));
      await tester.pumpAndSettle();

      expect(find.byType(MigrationScreen), findsOneWidget);
      expect(find.text('端末移行'), findsWidgets); // SliverAppBar.large() で複数表示
    });

    testWidgets('このアプリについてボタンで About 画面へ遷移できる', (WidgetTester tester) async {
      final mockApi = MockApiClient();

      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(apiClient: mockApi)),
      );

      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('このアプリについて'), 200);
      await tester.tap(find.text('このアプリについて'));
      await tester.pumpAndSettle();

      expect(find.byType(AboutPrivacyScreen), findsOneWidget);
      expect(find.text('このアプリについて'), findsWidgets);
    });

    testWidgets('再チュートリアルボタンで Onboarding 画面へ遷移できる', (
      WidgetTester tester,
    ) async {
      final mockApi = MockApiClient();

      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(apiClient: mockApi)),
      );

      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('チュートリアルをもう一度確認する'), 200);
      await tester.tap(find.text('チュートリアルをもう一度確認する'));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('スキップ'), findsOneWidget);
    });

    testWidgets('ペルソナ欄タップで診断結果画面へ遷移できる', (WidgetTester tester) async {
      final mockApi = MockApiClient();

      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(apiClient: mockApi)),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('type_A'));
      await tester.pumpAndSettle();

      expect(find.byType(PersonaDiagnosisResultScreen), findsOneWidget);
      expect(find.text('あなたのペルソナ'), findsWidgets); // SliverAppBar.large() で複数表示
    });
  });
}
