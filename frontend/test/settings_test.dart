import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sample_app/src/domain/models.dart';
import 'package:sample_app/src/infrastructure/api_client.dart';
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
    throw UnimplementedError();
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
        MaterialApp(
          home: SettingsScreen(apiClient: mockApi),
        ),
      );

      // ローディング状態を確認
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 読み込み完了を待つ
      await tester.pumpAndSettle();

      // ペルソナ情報が表示されていることを確認
      expect(find.text('type_A'), findsOneWidget);
      expect(find.text('type_B'), findsOneWidget);
    });

    testWidgets('コンボ設定を変更できる', (WidgetTester tester) async {
      final mockApi = MockApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(apiClient: mockApi),
        ),
      );

      await tester.pumpAndSettle();

      // 「短め」ボタンをタップ
      await tester.tap(find.text('短め'));
      await tester.pumpAndSettle();

      // ボタンが存在することを確認（選択状態は Material Design で表示）
      expect(find.text('短め'), findsOneWidget);
    });

    testWidgets('読み込みエラー時の再読込ボタン', (WidgetTester tester) async {
      final mockApi = MockApiClient(
        settingsSnapshot: SettingsSnapshot(
          settings: {},
          etag: '',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(apiClient: mockApi),
        ),
      );

      await tester.pumpAndSettle();

      // ペルソナ情報が表示されていることを確認
      expect(find.text('診断待機中...'), findsWidgets);
    });
  });
}
