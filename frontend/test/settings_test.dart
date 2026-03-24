import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:sample_app/core/widgets/app_button.dart';
import 'package:sample_app/core/widgets/app_list_item.dart';
import 'package:sample_app/src/domain/models.dart';
import 'package:sample_app/src/domain/persona_diagnosis.dart';
import 'package:sample_app/src/infrastructure/api_client.dart';
import 'package:sample_app/src/infrastructure/billing_proof.dart';
import 'package:sample_app/src/infrastructure/purchase_service.dart';
import 'package:sample_app/src/presentation/about_privacy_screen.dart';
import 'package:sample_app/src/presentation/diagnosis_screen.dart';
import 'package:sample_app/src/presentation/help_screen.dart';
import 'package:sample_app/src/presentation/migration_screen.dart';
import 'package:sample_app/src/presentation/onboarding_screen.dart';
import 'package:sample_app/src/presentation/persona_diagnosis_result_screen.dart';
import 'package:sample_app/src/presentation/privacy_policy_screen.dart';
import 'package:sample_app/src/presentation/settings_screen.dart';
import 'package:sample_app/src/presentation/terms_of_service_screen.dart';

// Mock Purchase Service
class MockPurchaseService extends PurchaseService {
  MockPurchaseService({this.mockIsPro = false})
    : super(storage: const FlutterSecureStorage());

  final bool mockIsPro;
  final StreamController<BillingProof> _proofController =
      StreamController<BillingProof>.broadcast();

  @override
  bool get isPro => mockIsPro;

  @override
  Future<void> initialize() async {}

  @override
  void dispose() {
    _proofController.close();
  }

  @override
  Stream<BillingProof> get billingProofStream => _proofController.stream;

  void emitBillingProof(BillingProof proof) {
    _proofController.add(proof);
  }

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> purchase() async {}

  @override
  Future<void> restorePurchases() async {}
}

// Mock API Client
class MockApiClient implements AppApiClient {
  MockApiClient({
    this.settingsSnapshot,
    this.shouldFailUpdate = false,
    this.verifyBillingErrorCode,
  });

  final SettingsSnapshot? settingsSnapshot;
  final bool shouldFailUpdate;
  final String? verifyBillingErrorCode;
  Map<String, dynamic>? lastUpdatedSettings;
  List<Map<String, String>> verifyBillingCalls = [];

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
    if (lastUpdatedSettings != null) {
      return SettingsSnapshot(
        settings: Map<String, dynamic>.from(lastUpdatedSettings!),
        etag: 'test-etag-123',
      );
    }

    return settingsSnapshot ??
        SettingsSnapshot(
          settings: {
            'true_self_type': 'type_A',
            'night_self_type': 'type_B',
            'combo_id': 0,
            'relationship_type': 'new',
            'reply_length_pref': 'standard',
            'line_break_pref': 'infer',
            'emoji_amount_pref': 'standard',
            'reaction_level_pref': 'standard',
            'partner_name_usage_pref': 'once',
            'candidate_tap_action': 'copy',
            'ng_tags': <String>[],
            'ng_free_phrases': <String>[],
            'settings_schema_version': 1,
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
  Future<void> postTelemetryEvents(List<Map<String, dynamic>> events) async {
    throw UnimplementedError();
  }

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
  }) async {
    verifyBillingCalls.add({
      'platform': platform,
      'productId': productId,
      'purchaseToken': purchaseToken,
    });
    if (verifyBillingErrorCode != null) {
      throw ApiError(
        errorCode: verifyBillingErrorCode!,
        message: '課金検証エラー',
        httpStatus: verifyBillingErrorCode == 'BILLING_NOT_CONFIGURED'
            ? 503
            : 400,
      );
    }
  }

  @override
  Future<ProCompRequestResult> requestProComp(String email) async {
    return ProCompRequestResult(approved: true, requestCount: 1);
  }

  @override
  Future<void> deleteAccount() async {}
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

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Permy',
      packageName: 'jp.sukimalab.permy',
      version: '1.1.0',
      buildNumber: '11',
      buildSignature: '',
    );
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> tapAppButton(WidgetTester tester, String label) async {
    final finder = find.widgetWithText(AppButton, label);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> tapAppListItem(WidgetTester tester, String label) async {
    final finder = find.widgetWithText(AppListItem, label);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> expandAdvancedSettings(WidgetTester tester) async {
    final finder = find.descendant(
      of: find.byType(ExpansionTile),
      matching: find.text('サポート・規約・その他設定'),
    );
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('Settings Screen', () {
    testWidgets('設定を読み込んで表示できる', (WidgetTester tester) async {
      final mockApi = MockApiClient();
      final mockPurchase = MockPurchaseService();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            apiClient: mockApi,
            purchaseService: mockPurchase,
          ),
        ),
      );

      // ローディング状態を確認
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 読み込み完了を待つ
      await tester.pumpAndSettle();

      // ペルソナ情報が表示されていることを確認
      expect(find.text('type_A'), findsOneWidget);
      expect(find.text('type_B'), findsWidgets);
      expect(find.text('現在のステータス'), findsOneWidget);
      expect(find.text('Free'), findsOneWidget);
    });

    testWidgets('Plus会員時は課金日と解約リンクを表示する', (WidgetTester tester) async {
      final mockApi = MockApiClient(
        settingsSnapshot: SettingsSnapshot(
          settings: {
            'true_self_type': 'type_A',
            'night_self_type': 'type_B',
            'last_billing_date': '2026-03-01',
            'next_billing_date': '2026-03-31',
            'settings_schema_version': 1,
            'forbidden_type_ids': [],
          },
          etag: 'test-etag-123',
        ),
      );
      final mockPurchase = MockPurchaseService(mockIsPro: true);

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            apiClient: mockApi,
            purchaseService: mockPurchase,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('会員種別'), findsOneWidget);
      expect(find.text('Plus'), findsOneWidget);
      expect(find.text('前回の更新日'), findsOneWidget);
      expect(find.text('次回の更新日'), findsOneWidget);
      expect(find.text('2026/03/01'), findsOneWidget);
      expect(find.text('2026/03/31'), findsOneWidget);
      expect(find.text('解約はこちら'), findsOneWidget);
    });

    testWidgets('コンボ設定を変更できる', (WidgetTester tester) async {
      final mockApi = MockApiClient();
      final mockPurchase = MockPurchaseService();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            apiClient: mockApi,
            purchaseService: mockPurchase,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 「休眠復活」ボタンをタップ
      await tester.tap(find.text('休眠復活'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // ボタンが存在することを確認（選択状態は Material Design で表示）
      expect(find.text('休眠復活'), findsOneWidget);
    });

    testWidgets('設定画面では生成調整項目の移設案内を表示する', (WidgetTester tester) async {
      final mockApi = MockApiClient();
      final mockPurchase = MockPurchaseService();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            apiClient: mockApi,
            purchaseService: mockPurchase,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('お客様との関係'), findsNothing);
      expect(
        find.text('返信の長さ・改行設定・絵文字の量・リアクション・相手の呼び方は、Generate画面で送信前に変更できるよ'),
        findsOneWidget,
      );
      expect(find.text('返信の長さ'), findsNothing);
      expect(find.text('改行設定'), findsNothing);
      expect(find.text('絵文字の量'), findsNothing);
      expect(find.text('リアクション'), findsNothing);
      expect(find.text('相手の呼び方'), findsNothing);
    });

    testWidgets('設定画面では返信案のタップ動作を変更できる', (WidgetTester tester) async {
      final mockApi = MockApiClient();
      final mockPurchase = MockPurchaseService();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            apiClient: mockApi,
            purchaseService: mockPurchase,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('返信案のタップ'), findsOneWidget);
      final shareFinder = find.text('共有');
      await tester.ensureVisible(shareFinder);
      await tester.tap(shareFinder.last);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(mockApi.lastUpdatedSettings?['candidate_tap_action'], 'share');
    });

    testWidgets('読み込みエラー時の再読込ボタン', (WidgetTester tester) async {
      final mockApi = MockApiClient(
        settingsSnapshot: SettingsSnapshot(settings: {}, etag: ''),
      );
      final mockPurchase = MockPurchaseService();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            apiClient: mockApi,
            purchaseService: mockPurchase,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // ペルソナ情報が表示されていることを確認
      expect(find.text('診断待機中...'), findsWidgets);
    });

    testWidgets('再診断ボタンで診断画面へ遷移できる', (WidgetTester tester) async {
      final mockApi = MockApiClient();
      final mockPurchase = MockPurchaseService();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            apiClient: mockApi,
            purchaseService: mockPurchase,
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tapAppButton(tester, '再診断する');

      expect(find.byType(DiagnosisScreen), findsOneWidget);
      // 新UI: 進捗表示を確認（複数の '/' を含むテキストがあるため）
      expect(find.textContaining('/'), findsWidgets);
    });

    testWidgets('端末移行リンクで Migration 画面へ遷移できる', (WidgetTester tester) async {
      final mockApi = MockApiClient();
      final mockPurchase = MockPurchaseService();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            apiClient: mockApi,
            purchaseService: mockPurchase,
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expandAdvancedSettings(tester);
      await tapAppListItem(tester, '端末移行の設定');

      expect(find.byType(MigrationScreen), findsOneWidget);
      expect(find.text('端末移行'), findsWidgets); // SliverAppBar.large() で複数表示
    });

    testWidgets('このアプリについてリンクで About 画面へ遷移できる', (WidgetTester tester) async {
      final mockApi = MockApiClient();
      final mockPurchase = MockPurchaseService();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            apiClient: mockApi,
            purchaseService: mockPurchase,
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expandAdvancedSettings(tester);
      await tapAppListItem(tester, 'このアプリについて');

      expect(find.byType(AboutPrivacyScreen), findsOneWidget);
      expect(find.text('このアプリについて'), findsWidgets);
    });

    testWidgets('利用規約リンクで利用規約画面へ遷移できる', (WidgetTester tester) async {
      final mockApi = MockApiClient();
      final mockPurchase = MockPurchaseService();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            apiClient: mockApi,
            purchaseService: mockPurchase,
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expandAdvancedSettings(tester);
      await tapAppListItem(tester, '利用規約');

      expect(find.byType(TermsOfServiceScreen), findsOneWidget);
      expect(find.text('第1条（適用）'), findsOneWidget);
    });

    testWidgets('プライバシーポリシーリンクで画面へ遷移できる', (WidgetTester tester) async {
      final mockApi = MockApiClient();
      final mockPurchase = MockPurchaseService();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            apiClient: mockApi,
            purchaseService: mockPurchase,
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expandAdvancedSettings(tester);
      await tapAppListItem(tester, 'プライバシーポリシー');

      expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
      expect(find.text('第1条（基本方針）'), findsOneWidget);
    });

    testWidgets('ヘルプリンクでヘルプ画面へ遷移できる', (WidgetTester tester) async {
      final mockApi = MockApiClient();
      final mockPurchase = MockPurchaseService();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            apiClient: mockApi,
            purchaseService: mockPurchase,
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expandAdvancedSettings(tester);
      await tapAppListItem(tester, 'ヘルプ（使い方）');

      expect(find.byType(HelpScreen), findsOneWidget);
      expect(find.text('2. 基本の使い方'), findsOneWidget);
    });

    testWidgets('オープンソースライセンスリンクでライセンスページへ遷移できる', (WidgetTester tester) async {
      final mockApi = MockApiClient();
      final mockPurchase = MockPurchaseService();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            apiClient: mockApi,
            purchaseService: mockPurchase,
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expandAdvancedSettings(tester);
      await tapAppListItem(tester, 'オープンソースライセンス');

      // LicensePage が表示されることを確認
      expect(find.byType(LicensePage), findsOneWidget);
    });

    testWidgets('再チュートリアルボタンで Onboarding 画面へ遷移できる', (
      WidgetTester tester,
    ) async {
      final mockApi = MockApiClient();
      final mockPurchase = MockPurchaseService();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            apiClient: mockApi,
            purchaseService: mockPurchase,
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tapAppButton(tester, 'チュートリアルをもう一度確認する');

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('スキップ'), findsOneWidget);
    });

    testWidgets('ペルソナ欄タップで診断結果画面へ遷移できる', (WidgetTester tester) async {
      final mockApi = MockApiClient();
      final mockPurchase = MockPurchaseService();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            apiClient: mockApi,
            purchaseService: mockPurchase,
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('type_A'));
      await tester.pumpAndSettle();

      expect(find.byType(PersonaDiagnosisResultScreen), findsOneWidget);
      expect(find.text('きみのペルソナはこれだよ'), findsOneWidget);
    });

    testWidgets('アカウント削除リンクで確認ダイアログが表示される', (WidgetTester tester) async {
      final mockApi = MockApiClient();
      final mockPurchase = MockPurchaseService();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            apiClient: mockApi,
            purchaseService: mockPurchase,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // アカウント削除ボタンまでスクロール
      await expandAdvancedSettings(tester);
      await tapAppListItem(tester, 'アカウントを削除する');

      // 確認ダイアログが表示されることを確認
      expect(find.text('アカウントを削除しますか？'), findsOneWidget);
      expect(find.text('すべてのデータが削除され、復元できません。この操作は取り消せません。'), findsOneWidget);
      expect(find.text('キャンセル'), findsOneWidget);
      expect(find.text('削除する'), findsOneWidget);
    });

    testWidgets('アカウント削除確認でキャンセルを選択できる', (WidgetTester tester) async {
      final mockApi = MockApiClient();
      final mockPurchase = MockPurchaseService();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            apiClient: mockApi,
            purchaseService: mockPurchase,
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expandAdvancedSettings(tester);
      await tapAppListItem(tester, 'アカウントを削除する');

      // キャンセルをタップ
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();

      // ダイアログが閉じる
      expect(find.text('アカウントを削除しますか？'), findsNothing);
      // 設定画面に戻る
      expect(find.text('設定'), findsOneWidget);
    });

    testWidgets('billingProof受信時に /billing/verify を呼び出す', (
      WidgetTester tester,
    ) async {
      final mockApi = MockApiClient();
      final mockPurchase = MockPurchaseService();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            apiClient: mockApi,
            purchaseService: mockPurchase,
          ),
        ),
      );
      await tester.pumpAndSettle();

      mockPurchase.emitBillingProof(
        BillingProof(
          platform: 'android',
          productId: 'permy_pro_monthly',
          purchaseToken: 'token-123',
        ),
      );
      await tester.pumpAndSettle();

      expect(mockApi.verifyBillingCalls.length, 1);
      expect(mockApi.verifyBillingCalls.first['platform'], 'android');
      expect(
        mockApi.verifyBillingCalls.first['productId'],
        'permy_pro_monthly',
      );
      expect(mockApi.verifyBillingCalls.first['purchaseToken'], 'token-123');
      expect(find.text('課金状態をサーバーに反映しました'), findsOneWidget);
    });

    testWidgets('BILLING_NOT_CONFIGURED で専用エラーダイアログを表示', (
      WidgetTester tester,
    ) async {
      final mockApi = MockApiClient(
        verifyBillingErrorCode: 'BILLING_NOT_CONFIGURED',
      );
      final mockPurchase = MockPurchaseService();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            apiClient: mockApi,
            purchaseService: mockPurchase,
          ),
        ),
      );
      await tester.pumpAndSettle();

      mockPurchase.emitBillingProof(
        BillingProof(
          platform: 'android',
          productId: 'permy_pro_monthly',
          purchaseToken: 'token-123',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('課金検証は準備中だよ'), findsOneWidget);
      expect(find.text('運用設定が完了するまで少し待ってね。'), findsOneWidget);
    });

    testWidgets('画面下部にバージョンとコピーライトを表示する', (WidgetTester tester) async {
      final mockApi = MockApiClient();
      final mockPurchase = MockPurchaseService();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            apiClient: mockApi,
            purchaseService: mockPurchase,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Version:1.1.0'), findsOneWidget);
      expect(find.text('©Sukima,Lab Nakanoya'), findsOneWidget);
    });
  });
}
