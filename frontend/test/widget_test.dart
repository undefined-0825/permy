import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sample_app/core/widgets/app_button.dart';
import 'package:sample_app/src/domain/models.dart';
import 'package:sample_app/src/domain/persona_diagnosis.dart';
import 'package:sample_app/src/domain/telemetry_event.dart';
import 'package:sample_app/src/infrastructure/api_client.dart';
import 'package:sample_app/src/infrastructure/purchase_service.dart';
import 'package:sample_app/src/infrastructure/share_receiver.dart';
import 'package:sample_app/src/infrastructure/telemetry_queue.dart';
import 'package:sample_app/src/presentation/generate_screen.dart';

class _FakePurchaseService extends PurchaseService {
  _FakePurchaseService() : super(storage: const FlutterSecureStorage());

  @override
  bool get isPro => false;

  @override
  Future<void> initialize() async {}

  @override
  void dispose() {}

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> purchase() async {}

  @override
  Future<void> restorePurchases() async {}
}

class _FakeApiClient implements AppApiClient {
  _FakeApiClient({
    this.generateResult,
    this.generateError,
    List<GenerateResult>? generateResults,
  }) : _generateResults = List<GenerateResult>.from(
         generateResults ?? const [],
       );

  final GenerateResult? generateResult;
  final ApiError? generateError;
  final List<GenerateResult> _generateResults;
  int generateCallCount = 0;
  Map<String, dynamic> lastUpdatedSettings = <String, dynamic>{};

  @override
  Future<void> bootstrapAuth() async {}

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
  Future<SettingsSnapshot> getSettings() async {
    return SettingsSnapshot(
      settings: <String, dynamic>{
        'relationship_type': 'new',
        'reply_length_pref': 'standard',
        'ng_tags': <String>[],
        'ng_free_phrases': <String>[],
      },
      etag: 'test',
    );
  }

  @override
  Future<void> updateSettings(
    Map<String, dynamic> settings,
    String etag,
  ) async {
    lastUpdatedSettings = Map<String, dynamic>.from(settings);
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
  Future<GenerateResult> generate({
    required String historyText,
    int comboId = 0,
  }) async {
    generateCallCount += 1;

    if (generateError != null) {
      throw generateError!;
    }

    if (_generateResults.isNotEmpty) {
      return _generateResults.removeAt(0);
    }

    if (generateResult != null) {
      return generateResult!;
    }

    return GenerateResult(
      candidates: [
        Candidate(label: 'A', text: '返信案A'),
        Candidate(label: 'B', text: '返信案B'),
        Candidate(label: 'C', text: '返信案C'),
      ],
      plan: 'free',
      daily: DailyInfo(limit: 3, used: 1, remaining: 2),
    );
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
}

class _FakeTelemetryQueue extends TelemetryQueue {
  _FakeTelemetryQueue() : super(apiClient: _FakeApiClient());

  @override
  Future<void> enqueue(TelemetryEvent event) async {}

  @override
  Future<void> flush() async {}
}

class _FakeShareInput implements ShareInput {
  _FakeShareInput(this.initialPayload);

  final SharePayload? initialPayload;

  @override
  Future<SharePayload?> getInitialPayload() async {
    return initialPayload;
  }

  @override
  Stream<SharePayload> get payloadStream => const Stream<SharePayload>.empty();
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

  testWidgets('共有前はResultエリアに待機表示を出す', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GenerateScreen(
          apiClient: _FakeApiClient(),
          shareReceiver: _FakeShareInput(null),
          telemetryQueue: _FakeTelemetryQueue(),
          purchaseService: _FakePurchaseService(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('返信案'), findsNothing);
    expect(find.text('まずは、LINEからトーク履歴を共有してね♪'), findsOneWidget);
    expect(find.text('返信案の調整'), findsOneWidget);
    expect(find.text('現在のペルソナ情報'), findsOneWidget);
  });

  testWidgets('Generate画面でお客様との関係を変更できる', (WidgetTester tester) async {
    final apiClient = _FakeApiClient();

    await tester.pumpWidget(
      MaterialApp(
        home: GenerateScreen(
          apiClient: apiClient,
          shareReceiver: _FakeShareInput(null),
          telemetryQueue: _FakeTelemetryQueue(),
          purchaseService: _FakePurchaseService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final relationshipDropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>).first,
    );
    relationshipDropdown.onChanged?.call('regular');
    await tester.pumpAndSettle();

    expect(apiClient.lastUpdatedSettings['relationship_type'], 'regular');
  });

  testWidgets('共有済みなら生成でA/B/Cを表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GenerateScreen(
          apiClient: _FakeApiClient(),
          shareReceiver: _FakeShareInput(
            SharePayload(text: '共有本文', fileName: 'line.txt'),
          ),
          telemetryQueue: _FakeTelemetryQueue(),
          purchaseService: _FakePurchaseService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final generateButton = find.widgetWithText(AppButton, 'ぼくが返信案を考えるよ');
    await tester.ensureVisible(generateButton);
    await tester.tap(generateButton);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(find.text('A案'), findsOneWidget);
    expect(find.text('返信案A'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('B案'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('B案'), findsOneWidget);
    expect(find.text('返信案B'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('C案'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('C案'), findsOneWidget);
    expect(find.text('返信案C'), findsOneWidget);
  });

  testWidgets('共有済みなら確認用トーク履歴テキストボックスを表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GenerateScreen(
          apiClient: _FakeApiClient(),
          shareReceiver: _FakeShareInput(
            SharePayload(text: '共有本文1\n共有本文2', fileName: 'line.txt'),
          ),
          telemetryQueue: _FakeTelemetryQueue(),
          purchaseService: _FakePurchaseService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('共有されたトーク履歴（確認用）'), findsOneWidget);
    expect(find.text('返信案'), findsNothing);
    expect(
      find.byKey(const Key('shared_history_preview_textfield')),
      findsNothing,
    );

    await tester.tap(find.text('共有されたトーク履歴（確認用）'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('shared_history_preview_textfield')),
      findsOneWidget,
    );
    expect(find.textContaining('共有本文1'), findsOneWidget);
  });

  testWidgets('Followup選択でsettingsを保存して返信案を更新できる', (WidgetTester tester) async {
    final apiClient = _FakeApiClient(
      generateResults: [
        GenerateResult(
          candidates: [
            Candidate(label: 'A', text: '補足前の返信案A'),
            Candidate(label: 'B', text: '補足前の返信案B'),
            Candidate(label: 'C', text: '補足前の返信案C'),
          ],
          plan: 'free',
          daily: DailyInfo(limit: 3, used: 1, remaining: 2),
          followup: FollowupInfo(
            key: 'relationship_type',
            question: 'お客様との関係を教えてね',
            choices: [FollowupChoice(id: 'repeat', label: '常連')],
          ),
        ),
        GenerateResult(
          candidates: [
            Candidate(label: 'A', text: '補足後の返信案A'),
            Candidate(label: 'B', text: '補足後の返信案B'),
            Candidate(label: 'C', text: '補足後の返信案C'),
          ],
          plan: 'free',
          daily: DailyInfo(limit: 3, used: 2, remaining: 1),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GenerateScreen(
          apiClient: apiClient,
          shareReceiver: _FakeShareInput(
            SharePayload(text: '共有本文', fileName: 'line.txt'),
          ),
          telemetryQueue: _FakeTelemetryQueue(),
          purchaseService: _FakePurchaseService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final generateButton = find.widgetWithText(AppButton, 'ぼくが返信案を考えるよ');
    await tester.ensureVisible(generateButton);
    await tester.tap(generateButton);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(find.text('情報補足'), findsOneWidget);
    await tester.tap(find.text('常連'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(apiClient.lastUpdatedSettings['relationship_type'], 'repeat');
    expect(apiClient.generateCallCount, 2);
    expect(find.text('情報を反映したよ。返信案を更新するね'), findsOneWidget);
    expect(find.text('補足後の返信案A'), findsOneWidget);
    expect(find.text('補足前の返信案A'), findsNothing);
  });

  testWidgets('FreeでPlus項目選択時に購買案内を表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GenerateScreen(
          apiClient: _FakeApiClient(),
          shareReceiver: _FakeShareInput(
            SharePayload(text: '共有本文', fileName: 'line.txt'),
          ),
          telemetryQueue: _FakeTelemetryQueue(),
          purchaseService: _FakePurchaseService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dropdown = tester.widget<DropdownButton<int>>(
      find.byType(DropdownButton<int>),
    );
    dropdown.onChanged?.call(2);
    await tester.pumpAndSettle();

    expect(find.text('有料版のみ'), findsOneWidget);
    expect(find.text('このモードはPlusで使える機能だよ。'), findsOneWidget);
  });

  testWidgets('生成方針のPro項目にPlusバッジを表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GenerateScreen(
          apiClient: _FakeApiClient(),
          shareReceiver: _FakeShareInput(
            SharePayload(text: '共有本文', fileName: 'line.txt'),
          ),
          telemetryQueue: _FakeTelemetryQueue(),
          purchaseService: _FakePurchaseService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();

    expect(find.text('Plus'), findsWidgets);
  });

  testWidgets('生成失敗時にエラーコード付きメッセージボックスを表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GenerateScreen(
          apiClient: _FakeApiClient(
            generateError: ApiError(
              errorCode: 'VALIDATION_FAILED',
              message: 'history_text が長すぎます',
              httpStatus: 422,
            ),
          ),
          shareReceiver: _FakeShareInput(
            SharePayload(text: '共有本文', fileName: 'line.txt'),
          ),
          telemetryQueue: _FakeTelemetryQueue(),
          purchaseService: _FakePurchaseService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final generateButton = find.widgetWithText(AppButton, 'ぼくが返信案を考えるよ');
    await tester.ensureVisible(generateButton);
    await tester.tap(generateButton);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(find.text('エラーが発生したよ'), findsOneWidget);
    expect(find.text('エラーコード: VALIDATION_FAILED'), findsOneWidget);
    expect(find.textContaining('history_text が長すぎます'), findsOneWidget);
  });
}
