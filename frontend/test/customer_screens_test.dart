import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sample_app/src/domain/models.dart';
import 'package:sample_app/src/domain/persona_diagnosis.dart';
import 'package:sample_app/src/infrastructure/api_client.dart';
import 'package:sample_app/src/presentation/customer_detail_screen.dart';
import 'package:sample_app/src/presentation/customer_list_screen.dart';

class MockCustomerApiClient implements AppApiClient {
  MockCustomerApiClient({
    List<CustomerSummary> initialCustomers = const <CustomerSummary>[],
    this.shouldFailList = false,
  }) : _customers = List<CustomerSummary>.from(initialCustomers);

  final bool shouldFailList;
  final List<CustomerSummary> _customers;

  int listCallCount = 0;
  int createCallCount = 0;
  int detailCallCount = 0;

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
    return SettingsSnapshot(settings: {'combo_id': 0}, etag: 'etag');
  }

  @override
  Future<void> updateSettings(Map<String, dynamic> settings, String etag) async {}

  @override
  Future<DiagnosisResult> completeDiagnosis(List<DiagnosisAnswer> answers) async {
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
    return MigrationIssueResult(migrationCode: '123456789012', expiresAt: '2026-03-06T12:00:00Z');
  }

  @override
  Future<MigrationConsumeResult> consumeMigrationCode(String code) async {
    return MigrationConsumeResult(token: 'token', userId: 'user');
  }

  @override
  Future<void> postTelemetryEvents(List<Map<String, dynamic>> events) async {}

  @override
  Future<AppVersionInfo> getAppVersionInfo() async {
    return AppVersionInfo(
      latestVersion: '1.0.0',
      minSupportedVersion: '1.0.0',
      androidStoreUrl: '',
      iosStoreUrl: '',
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
  Future<void> deleteAccount() async {}

  @override
  Future<List<CustomerSummary>> getCustomers({String? query}) async {
    listCallCount += 1;
    if (shouldFailList) {
      throw ApiError(
        errorCode: 'UPSTREAM_UNAVAILABLE',
        message: 'network error',
        httpStatus: 503,
      );
    }
    if (query == null || query.trim().isEmpty) {
      return List<CustomerSummary>.from(_customers);
    }
    final q = query.trim();
    return _customers
        .where(
          (c) => c.displayName.contains(q) || (c.memoSummary ?? '').contains(q),
        )
        .toList();
  }

  @override
  Future<CustomerSummary> createCustomer(CreateCustomerInput input) async {
    createCallCount += 1;
    final created = CustomerSummary(
      customerId: 'customer-${createCallCount + _customers.length}',
      displayName: input.displayName,
      relationshipStage: input.relationshipStage,
      memoSummary: input.memoSummary,
      lastVisitAt: null,
      lastContactAt: null,
      isArchived: false,
    );
    _customers.insert(0, created);
    return created;
  }

  @override
  Future<CustomerDetail> getCustomerDetail(String customerId) async {
    detailCallCount += 1;
    final target = _customers.firstWhere((c) => c.customerId == customerId);
    return CustomerDetail(
      customer: target,
      tags: [CustomerTag(tagId: 't1', category: 'topic', value: '誕生日')],
      visitLogs: [
        CustomerVisitLog(
          visitLogId: 'v1',
          visitedOn: '2026-04-01',
          visitType: 'store',
          memoShort: '終電前に退店',
          spendLevel: 'middle',
          moodTag: 'good',
        ),
      ],
      events: [
        CustomerEvent(
          eventId: 'e1',
          eventType: 'birthday',
          eventDate: '2026-04-15',
          title: '誕生日',
          note: '前日に連絡',
        ),
      ],
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

  testWidgets('顧客一覧を表示できる', (tester) async {
    final apiClient = MockCustomerApiClient(
      initialCustomers: [
        CustomerSummary(
          customerId: 'c1',
          displayName: '山田さん',
          relationshipStage: 'regular',
          memoSummary: '終電前に帰る',
          lastVisitAt: null,
          lastContactAt: null,
          isArchived: false,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: CustomerListScreen(apiClient: apiClient)),
    );
    await tester.pumpAndSettle();

    expect(find.text('顧客一覧'), findsOneWidget);
    expect(find.text('山田さん'), findsOneWidget);
    expect(find.textContaining('常連'), findsOneWidget);
  });

  testWidgets('顧客追加で一覧に反映される', (tester) async {
    final apiClient = MockCustomerApiClient();

    await tester.pumpWidget(
      MaterialApp(home: CustomerListScreen(apiClient: apiClient)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('顧客を追加'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, '表示名 *'), '田中さん');
    await tester.enterText(find.widgetWithText(TextFormField, '要約メモ'), '誕生日が近い');

    final submitFinder = find.text('登録する');
    await tester.ensureVisible(submitFinder);
    await tester.tap(submitFinder);
    await tester.pumpAndSettle();

    expect(apiClient.createCallCount, 1);
    expect(find.text('田中さん'), findsOneWidget);
    expect(find.textContaining('誕生日が近い'), findsOneWidget);
  });

  testWidgets('顧客一覧から詳細画面へ遷移できる', (tester) async {
    final apiClient = MockCustomerApiClient(
      initialCustomers: [
        CustomerSummary(
          customerId: 'c1',
          displayName: '山田さん',
          relationshipStage: 'regular',
          memoSummary: '終電前に帰る',
          lastVisitAt: null,
          lastContactAt: null,
          isArchived: false,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: CustomerListScreen(apiClient: apiClient)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('山田さん'));
    await tester.pumpAndSettle();

    expect(apiClient.detailCallCount, 1);
    expect(find.byType(CustomerDetailScreen), findsOneWidget);
    expect(find.text('基本情報'), findsOneWidget);
    expect(find.textContaining('関係性: 常連'), findsOneWidget);
    expect(find.text('タグ'), findsOneWidget);
  });
}
