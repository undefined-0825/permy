import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sample_app/src/domain/models.dart';
import 'package:sample_app/src/domain/persona_diagnosis.dart';
import 'package:sample_app/src/infrastructure/api_client.dart';
import 'package:sample_app/src/infrastructure/customer_generate_selection_store.dart';
import 'package:sample_app/src/presentation/customer_detail_screen.dart';
import 'package:sample_app/src/presentation/customer_list_screen.dart';
import 'package:sample_app/src/presentation/customer_search_results_screen.dart';

class MockCustomerApiClient implements AppApiClient {
  MockCustomerApiClient({
    List<CustomerSummary> initialCustomers = const <CustomerSummary>[],
    List<CustomerReminder> initialReminders = const <CustomerReminder>[],
    this.shouldFailList = false,
  }) : _customers = List<CustomerSummary>.from(initialCustomers),
       _reminders = List<CustomerReminder>.from(initialReminders);

  final bool shouldFailList;
  final List<CustomerSummary> _customers;
  final List<CustomerReminder> _reminders;

  int listCallCount = 0;
  int remindersCallCount = 0;
  int createCallCount = 0;
  int detailCallCount = 0;
  int replaceTagsCallCount = 0;
  int createVisitLogCallCount = 0;
  int createEventCallCount = 0;
  int updateEventReminderCallCount = 0;
  int updateCustomerCallCount = 0;

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
  Future<CustomerSummary> updateCustomer(
    String customerId,
    UpdateCustomerInput input,
  ) async {
    updateCustomerCallCount += 1;
    final index = _customers.indexWhere((c) => c.customerId == customerId);
    final updated = CustomerSummary(
      customerId: customerId,
      displayName: input.displayName,
      relationshipStage: input.relationshipStage,
      nickname: input.nickname,
      callName: input.callName,
      areaTag: input.areaTag,
      jobTag: input.jobTag,
      memoSummary: input.memoSummary,
      lastVisitAt: index >= 0 ? _customers[index].lastVisitAt : null,
      lastContactAt: index >= 0 ? _customers[index].lastContactAt : null,
      isArchived: input.isArchived,
    );
    if (index >= 0) {
      _customers[index] = updated;
    }
    return updated;
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

  @override
  Future<List<CustomerTag>> replaceCustomerTags(
    String customerId,
    ReplaceCustomerTagsInput input,
  ) async {
    replaceTagsCallCount += 1;
    return input.tags
        .asMap()
        .entries
        .map(
          (e) => CustomerTag(
            tagId: 'tag-${e.key}',
            category: e.value.category,
            value: e.value.value,
          ),
        )
        .toList();
  }

  @override
  Future<CustomerVisitLog> createCustomerVisitLog(
    String customerId,
    CreateVisitLogInput input,
  ) async {
    createVisitLogCallCount += 1;
    return CustomerVisitLog(
      visitLogId: 'visit-new',
      visitedOn: input.visitedOn,
      visitType: input.visitType,
      memoShort: input.memoShort,
      spendLevel: input.spendLevel,
      moodTag: input.moodTag,
    );
  }

  @override
  Future<CustomerEvent> createCustomerEvent(
    String customerId,
    CreateCustomerEventInput input,
  ) async {
    createEventCallCount += 1;
    return CustomerEvent(
      eventId: 'event-new',
      eventType: input.eventType,
      eventDate: input.eventDate,
      title: input.title,
      note: input.note,
    );
  }

  @override
  Future<CustomerEvent> updateCustomerEventReminder(
    String customerId,
    String eventId,
    UpdateCustomerEventReminderInput input,
  ) async {
    updateEventReminderCallCount += 1;
    return CustomerEvent(
      eventId: eventId,
      eventType: 'birthday',
      eventDate: '2026-04-20',
      title: '次回提案日',
      note: null,
      remindDaysBefore: input.remindDaysBefore,
      isActive: true,
    );
  }

  @override
  Future<List<CustomerReminder>> getCustomerReminders({int daysAhead = 14}) async {
    remindersCallCount += 1;
    return List<CustomerReminder>.from(_reminders);
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
    expect(find.textContaining('常連'), findsWidgets);
  });

  testWidgets('検索入力はdebounce後にAPIを呼び出す', (tester) async {
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

    expect(apiClient.listCallCount, 1);

    await tester.enterText(find.byType(TextField).first, '山田');
    await tester.pump(const Duration(milliseconds: 200));
    expect(apiClient.listCallCount, 1);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(apiClient.listCallCount, 2);
  });

  testWidgets('検索アイコンで顧客検索結果専用画面へ遷移できる', (tester) async {
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

    await tester.enterText(find.byType(TextField).first, '山田');
    await tester.tap(find.byIcon(Icons.search).first);
    await tester.pumpAndSettle();

    expect(find.byType(CustomerSearchResultsScreen), findsOneWidget);
    expect(find.text('顧客検索結果'), findsOneWidget);
    expect(find.text('山田さん'), findsOneWidget);
  });

  testWidgets('関係性チップで一覧を絞り込める', (tester) async {
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
        CustomerSummary(
          customerId: 'c2',
          displayName: '新規客',
          relationshipStage: 'new',
          memoSummary: '初来店',
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

    expect(find.text('山田さん'), findsOneWidget);
    expect(find.text('新規客'), findsOneWidget);

    await tester.tap(find.text('常連'));
    await tester.pumpAndSettle();

    expect(find.text('山田さん'), findsOneWidget);
    expect(find.text('新規客'), findsNothing);
  });

  testWidgets('通知リマインドからこの顧客で返信を作る導線を実行できる', (tester) async {
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
      initialReminders: [
        CustomerReminder(
          reminderId: 'r1',
          reminderType: 'event',
          title: '誕生日（山田さん）',
          dueDate: '2026-04-15',
          daysDelta: 0,
          customer: CustomerSummary(
            customerId: 'c1',
            displayName: '山田さん',
            relationshipStage: 'regular',
            memoSummary: null,
            lastVisitAt: null,
            lastContactAt: null,
            isArchived: false,
          ),
        ),
      ],
    );

    CustomerGenerateSelectionStore.instance.clear();

    await tester.pumpWidget(
      MaterialApp(home: CustomerListScreen(apiClient: apiClient)),
    );
    await tester.pumpAndSettle();

    expect(find.text('通知リマインド'), findsOneWidget);
    expect(apiClient.remindersCallCount, 1);

    await tester.tap(find.byTooltip('この顧客で返信を作る').first);
    await tester.pumpAndSettle();

    final selected = CustomerGenerateSelectionStore.instance.current;
    expect(selected, isNotNull);
    expect(selected!.customerId, 'c1');
    expect(selected.displayName, '山田さん');

    CustomerGenerateSelectionStore.instance.clear();
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

  testWidgets('顧客詳細から編集画面で基本情報を更新できる', (tester) async {
    final apiClient = MockCustomerApiClient(
      initialCustomers: [
        CustomerSummary(
          customerId: 'c1',
          displayName: '山田さん',
          relationshipStage: 'regular',
          nickname: 'やまだ',
          callName: 'やまださん',
          areaTag: '梅田',
          jobTag: '営業',
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

    await tester.tap(find.widgetWithText(OutlinedButton, '顧客情報を編集'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, '表示名 *'), '山田太郎さん');
    await tester.enterText(find.widgetWithText(TextFormField, '要約メモ'), '誕生日週に再来店見込み');
    final saveButton = find.text('保存する');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(apiClient.updateCustomerCallCount, 1);
    expect(find.text('山田太郎さん'), findsOneWidget);
    expect(find.textContaining('誕生日週に再来店見込み'), findsOneWidget);
  });

  testWidgets('詳細画面でタグ更新・来店ログ追加・イベント追加を実行できる', (tester) async {
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

    await tester.enterText(
      find.widgetWithText(TextField, 'タグをカンマ区切りで入力（例: 誕生日,転職）'),
      '転職,誕生日',
    );
    final updateTagsButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'タグを更新'),
    );
    updateTagsButton.onPressed!.call();
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, '来店日（YYYY-MM-DD）'),
      '2026-04-02',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'メモ（任意）').first,
      '同伴あり',
    );
    final addVisitLogButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '来店ログを追加'),
    );
    addVisitLogButton.onPressed!.call();
    await tester.pumpAndSettle();

    final eventDateFinder = find.widgetWithText(TextField, 'イベント日（YYYY-MM-DD）');
    await tester.ensureVisible(eventDateFinder);
    await tester.enterText(
      eventDateFinder,
      '2026-04-20',
    );
    final eventTitleFinder = find.widgetWithText(TextField, 'タイトル');
    await tester.ensureVisible(eventTitleFinder);
    await tester.enterText(eventTitleFinder, '次回提案日');
    await tester.enterText(
      find.widgetWithText(TextField, 'メモ（任意）').last,
      '前日に連絡',
    );
    final addEventButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'イベントを追加'),
    );
    addEventButton.onPressed!.call();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, '通知日数を更新').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '何日前に通知するか（0-365）'), '5');
    await tester.tap(find.text('更新する'));
    await tester.pumpAndSettle();

    expect(apiClient.replaceTagsCallCount, 1);
    expect(apiClient.createVisitLogCallCount, 1);
    expect(apiClient.createEventCallCount, 1);
    expect(apiClient.updateEventReminderCallCount, 1);
  });

  testWidgets('詳細画面からこの顧客で返信を作る導線で選択を保持する', (tester) async {
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

    CustomerGenerateSelectionStore.instance.clear();

    await tester.pumpWidget(
      MaterialApp(home: CustomerListScreen(apiClient: apiClient)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('山田さん'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('この顧客で返信を作る'));
    await tester.pumpAndSettle();

    final selected = CustomerGenerateSelectionStore.instance.current;
    expect(selected, isNotNull);
    expect(selected!.customerId, 'c1');
    expect(selected.displayName, '山田さん');

    CustomerGenerateSelectionStore.instance.clear();
  });
}
