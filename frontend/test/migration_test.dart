import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sample_app/src/domain/models.dart';
import 'package:sample_app/src/domain/persona_diagnosis.dart';
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
    String? myLineName,
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
  Future<DiagnosisResult> completeDiagnosis(
    List<DiagnosisAnswer> answers,
  ) async {
    return DiagnosisResult(
      trueSelfType: 'Stability',
      nightSelfType: 'VisitPush',
      personaGoalPrimary: 'romance',
      personaGoalSecondary: null,
      styleAssertiveness: 50,
      styleWarmth: 60,
      styleRiskGuard: 70,
    );
  }

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

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<AppVersionInfo> getAppVersionInfo() async {
    return AppVersionInfo(
      latestVersion: '1.0.0',
      minSupportedVersion: '1.0.0',
      androidStoreUrl: 'https://play.google.com/store',
      iosStoreUrl: 'https://apps.apple.com/app',
    );
  }

  @override
  Future<void> verifyBilling({
    required String platform,
    required String productId,
    required String purchaseToken,
  }) async {}

  @override
  Future<PremiumCompRequestResult> requestPremiumComp(String email) async {
    return PremiumCompRequestResult(approved: true, requestCount: 1);
  }

  @override
  Future<List<CustomerSummary>> getCustomers({String? query}) async {
    return <CustomerSummary>[];
  }

  @override
  Future<CustomerDetail> getCustomerDetail(String customerId) async {
    return CustomerDetail(
      customer: CustomerSummary(
        customerId: customerId,
        displayName: '顧客',
        relationshipStage: 'new',
        memoSummary: null,
        lastVisitAt: null,
        lastContactAt: null,
        isArchived: false,
      ),
      tags: <CustomerTag>[],
      visitLogs: <CustomerVisitLog>[],
      events: <CustomerEvent>[],
    );
  }

  @override
  Future<CustomerSummary> createCustomer(CreateCustomerInput input) async {
    return CustomerSummary(
      customerId: 'customer-1',
      displayName: input.displayName,
      relationshipStage: input.relationshipStage,
      memoSummary: input.memoSummary,
      lastVisitAt: null,
      lastContactAt: null,
      isArchived: false,
    );
  }
}

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

    testWidgets('発行済みコードを共有できる', (WidgetTester tester) async {
      final mockApi = MockMigrationApiClient();
      String? sharedText;

      await tester.pumpWidget(
        MaterialApp(
          home: MigrationScreen(
            apiClient: mockApi,
            shareCodeHandler: (text) async {
              sharedText = text;
            },
          ),
        ),
      );

      await tester.tap(find.text('この端末から移行コードを発行'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('共有する'));
      await tester.pumpAndSettle();

      expect(sharedText, isNotNull);
      expect(sharedText, contains('123456789012'));
      expect(find.text('共有シートを開きました'), findsOneWidget);
    });
  });
}
