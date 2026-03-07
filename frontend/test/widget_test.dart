import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
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
  _FakeApiClient({this.generateResult});

  final GenerateResult? generateResult;
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
        'relationship_type': 'new_customer',
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
  testWidgets('共有前は共有待ち表示', (WidgetTester tester) async {
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
    expect(find.text('共有待ち'), findsOneWidget);
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
    await tester.pump();

    // スクロールしてボタンを見えるようにする
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -200),
    );
    await tester.pump();

    await tester.tap(find.text('ぼくが返信案を考えるよ'));
    await tester.pumpAndSettle();

    expect(find.textContaining('A: 返信案A'), findsOneWidget);
    expect(find.textContaining('B: 返信案B'), findsOneWidget);
    expect(find.textContaining('C: 返信案C'), findsOneWidget);
  });

  testWidgets('Followup選択でsettingsを保存できる', (WidgetTester tester) async {
    final apiClient = _FakeApiClient(
      generateResult: GenerateResult(
        candidates: [Candidate(label: 'A', text: '返信案A')],
        plan: 'free',
        daily: DailyInfo(limit: 3, used: 1, remaining: 2),
        followup: FollowupInfo(
          key: 'relationship_type',
          question: 'お客様との関係を教えてね',
          choices: [FollowupChoice(id: 'repeat', label: '常連')],
        ),
      ),
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
    await tester.pump();

    await tester.tap(find.text('ぼくが返信案を考えるよ'));
    await tester.pumpAndSettle();

    expect(find.text('情報補足'), findsOneWidget);
    await tester.tap(find.text('常連'));
    await tester.pumpAndSettle();

    expect(apiClient.lastUpdatedSettings['relationship_type'], 'repeat');
    expect(find.text('情報を反映したよ。もう一度生成してみてね'), findsOneWidget);
  });

  testWidgets('FreeでPro項目選択時に購買案内を表示する', (WidgetTester tester) async {
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
    await tester.pump();

    final dropdown = tester.widget<DropdownButton<int>>(
      find.byType(DropdownButton<int>),
    );
    dropdown.onChanged?.call(2);
    await tester.pumpAndSettle();

    expect(find.text('有料版のみ'), findsOneWidget);
    expect(find.text('このモードはProで使える機能だよ。'), findsOneWidget);
  });
}
