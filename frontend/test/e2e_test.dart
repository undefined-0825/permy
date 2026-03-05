import 'package:flutter_test/flutter_test.dart';
import 'package:sample_app/src/domain/models.dart';
import 'package:sample_app/src/domain/persona_diagnosis.dart';
import 'package:sample_app/src/infrastructure/api_client.dart';
import 'package:sample_app/src/infrastructure/token_store.dart';

// モックトークンストア（テスト用）
class MockTokenStore implements TokenStore {
  String? _token;

  @override
  Future<void> delete() async {
    _token = null;
  }

  @override
  Future<String?> read() async {
    return _token;
  }

  @override
  Future<void> write(String token) async {
    _token = token;
  }
}

void main() {
  group('E2E: バックエンド統合テスト', () {
    late ApiClient apiClient;
    late MockTokenStore tokenStore;

    setUpAll(() async {
      // モックトークンストア初期化
      tokenStore = MockTokenStore();

      // APIクライアント初期化（localhost:8000）
      apiClient = ApiClient(
        baseUrl: 'http://localhost:8000',
        tokenStore: tokenStore,
      );
    });

    test('認証: anonymous token取得', () async {
      // bootstrap時にtoken取得が行われることを想定
      await apiClient.bootstrapAuth();
      // token保持の確認
      final token = await tokenStore.read();
      expect(token, isNotEmpty);
    });

    test('生成: 返信案取得（Free可能）', () async {
      final result = await apiClient.generate(historyText: 'こんにちは');

      expect(result.candidates, isNotEmpty);
      expect(result.daily, isNotNull);
      expect(result.plan, anyOf('free', 'pro'));
    });

    test('生成: comboId指定', () async {
      final result = await apiClient.generate(
        historyText: 'お疲れ様です',
        comboId: 1,
      );

      expect(result.candidates.length, equals(3));
      expect(result.candidates[0].label, 'A');
    });

    test('設定: getSettings取得', () async {
      final settings = await apiClient.getSettings();

      expect(settings.settings, isNotNull);
      expect(settings.etag, isNotEmpty);
    });

    test('診断: completeDiagnosis投入', () async {
      // 有効な診断データ（診断に必要な7項目）
      final answers = [
        DiagnosisAnswer(questionId: 'true_priority', choiceId: 'life_balance'),
        DiagnosisAnswer(
          questionId: 'true_decision_axis',
          choiceId: 'low_stress',
        ),
        DiagnosisAnswer(
          questionId: 'night_goal_primary',
          choiceId: 'next_visit',
        ),
        DiagnosisAnswer(questionId: 'night_temperature', choiceId: 'calm_safe'),
        DiagnosisAnswer(
          questionId: 'night_game_tolerance',
          choiceId: 'avoid_game',
        ),
        DiagnosisAnswer(
          questionId: 'night_customer_allocation',
          choiceId: 'wide_touchpoints',
        ),
        DiagnosisAnswer(
          questionId: 'night_risk_response',
          choiceId: 'firefighting_safe',
        ),
      ];

      await apiClient.completeDiagnosis(answers);
      // 成功時は例外が出ないことを確認
    });

    test('テレメトリ: イベント送信', () async {
      final events = [
        {'event_name': 'app_opened', 'app_version': '1.0.0', 'os': 'android'},
      ];

      await apiClient.postTelemetryEvents(events);
      // 成功時は例外が出ないことを確認
    });
  });
}
