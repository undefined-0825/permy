import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sample_app/src/domain/models.dart';
import 'package:sample_app/src/infrastructure/api_client.dart';
import 'package:sample_app/src/presentation/migration_screen.dart';

// Mock API Client
class MockMigrationApiClient implements AppApiClient {
  MockMigrationApiClient({this.issueSucceed = true});

  final bool issueSucceed;

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
    return SettingsSnapshot(settings: {'combo_id': 0}, etag: 'test-etag');
  }

  @override
  Future<void> updateSettings(
    Map<String, dynamic> settings,
    String etag,
  ) async {}

  @override
  Future<void> completeDiagnosis(List answers) async {}

  @override
  Future<MigrationIssueResult> issueMigrationCode() async {
    if (!issueSucceed) {
      throw ApiError(
        errorCode: 'RATE_LIMITED',
        message: '試行回数が多すぎます',
        httpStatus: 429,
      );
    }
    return MigrationIssueResult(
      migrationCode: '123456789012',
      expiresAt: '2026-03-06T12:00:00Z',
    );
  }

  @override
  Future<MigrationConsumeResult> consumeMigrationCode(String code) async {
    return MigrationConsumeResult(token: 'new-token-123', userId: 'user-456');
  }

  @override
  Future<void> postTelemetryEvents(List<Map<String, dynamic>> events) async {}
}

void main() {
  group('Migration Screen', () {
    testWidgets('初期画面で選択肢が表示される', (WidgetTester tester) async {
      final mockApi = MockMigrationApiClient();

      await tester.pumpWidget(
        MaterialApp(home: MigrationScreen(apiClient: mockApi)),
      );

      expect(find.text('この端末から移行コードを発行'), findsOneWidget);
      expect(find.text('別の端末からコードを入力'), findsOneWidget);
    });

    testWidgets('コードを発行できる', (WidgetTester tester) async {
      final mockApi = MockMigrationApiClient();

      await tester.pumpWidget(
        MaterialApp(home: MigrationScreen(apiClient: mockApi)),
      );

      await tester.tap(find.text('この端末から移行コードを発行'));
      await tester.pumpAndSettle();

      expect(find.text('移行コードが発行されました'), findsOneWidget);
      expect(find.text('123456789012'), findsOneWidget);
    });

    testWidgets('コード入力画面に遷移できる', (WidgetTester tester) async {
      final mockApi = MockMigrationApiClient();

      await tester.pumpWidget(
        MaterialApp(home: MigrationScreen(apiClient: mockApi)),
      );

      await tester.tap(find.text('別の端末からコードを入力'));
      await tester.pumpAndSettle();

      expect(find.text('移行コードを入力'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
