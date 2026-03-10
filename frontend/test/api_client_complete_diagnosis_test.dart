import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sample_app/src/domain/persona_diagnosis.dart';
import 'package:sample_app/src/infrastructure/api_client.dart';
import 'package:sample_app/src/infrastructure/token_store.dart';

class _MemoryTokenStore implements TokenStore {
  _MemoryTokenStore(this._token);

  String? _token;

  @override
  Future<void> delete() async {
    _token = null;
  }

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async {
    _token = token;
  }
}

void main() {
  test('completeDiagnosis はリクエスト/レスポンスログを出力する', () async {
    final logs = <String>[];

    final client = MockClient((http.Request request) async {
      if (request.url.path == '/api/v1/me/diagnosis' &&
          request.method == 'POST') {
        return http.Response(
          jsonEncode({
            'persona_version': 3,
            'true_self_type': 'Stability',
            'night_self_type': 'Balance',
            'persona_goal_primary': 'relationship_keep',
            'persona_goal_secondary': 'next_visit',
            'style_assertiveness': 60,
            'style_warmth': 70,
            'style_risk_guard': 80,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (request.url.path == '/api/v1/me/settings' &&
          request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'settings': {'settings_schema_version': 1},
          }),
          200,
          headers: {'content-type': 'application/json', 'etag': 'etag-1'},
        );
      }

      if (request.url.path == '/api/v1/me/settings' &&
          request.method == 'PUT') {
        return http.Response(
          jsonEncode({
            'settings': {'settings_schema_version': 1, 'persona_version': 3},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return http.Response('not found', 404);
    });

    final apiClient = ApiClient(
      baseUrl: 'https://example.test',
      tokenStore: _MemoryTokenStore('token-1'),
      httpClient: client,
      debugLog: logs.add,
    );

    final answers = <DiagnosisAnswer>[
      const DiagnosisAnswer(
        questionId: 'true_priority',
        choiceId: 'life_balance',
      ),
      const DiagnosisAnswer(
        questionId: 'true_decision_axis',
        choiceId: 'low_stress',
      ),
      const DiagnosisAnswer(
        questionId: 'night_goal_primary',
        choiceId: 'next_visit',
      ),
      const DiagnosisAnswer(
        questionId: 'night_temperature',
        choiceId: 'calm_safe',
      ),
      const DiagnosisAnswer(
        questionId: 'night_game_tolerance',
        choiceId: 'avoid_game',
      ),
      const DiagnosisAnswer(
        questionId: 'night_customer_allocation',
        choiceId: 'wide_touchpoints',
      ),
      const DiagnosisAnswer(
        questionId: 'night_risk_response',
        choiceId: 'firefighting_safe',
      ),
    ];

    await apiClient.completeDiagnosis(answers);

    expect(
      logs.any(
        (line) =>
            line.contains('"stage":"request"') &&
            line.contains('"path":"/api/v1/me/diagnosis"') &&
            line.contains('"answersCount":7'),
      ),
      isTrue,
    );
    expect(
      logs.any(
        (line) =>
            line.contains('"stage":"response"') &&
            line.contains('"path":"/api/v1/me/diagnosis"') &&
            line.contains('"status":200'),
      ),
      isTrue,
    );
    expect(
      logs.any(
        (line) => line.contains('"event":"save_diagnosis_settings_success"'),
      ),
      isTrue,
    );
  });

  test('completeDiagnosis は settings 競合時に1回リトライする', () async {
    var getSettingsCount = 0;
    var putSettingsCount = 0;

    final client = MockClient((http.Request request) async {
      if (request.url.path == '/api/v1/me/diagnosis' &&
          request.method == 'POST') {
        return http.Response(
          jsonEncode({
            'persona_version': 3,
            'true_self_type': 'Stability',
            'night_self_type': 'Balance',
            'persona_goal_primary': 'relationship_keep',
            'persona_goal_secondary': 'next_visit',
            'style_assertiveness': 60,
            'style_warmth': 70,
            'style_risk_guard': 80,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (request.url.path == '/api/v1/me/settings' &&
          request.method == 'GET') {
        getSettingsCount += 1;
        final etag = getSettingsCount == 1 ? 'etag-1' : 'etag-2';
        return http.Response(
          jsonEncode({
            'settings': {'settings_schema_version': 1},
          }),
          200,
          headers: {'content-type': 'application/json', 'etag': etag},
        );
      }

      if (request.url.path == '/api/v1/me/settings' &&
          request.method == 'PUT') {
        putSettingsCount += 1;
        if (putSettingsCount == 1) {
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'SETTINGS_VERSION_CONFLICT',
                'message': 'conflict',
              },
            }),
            409,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({
            'settings': {'settings_schema_version': 1, 'persona_version': 3},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return http.Response('not found', 404);
    });

    final apiClient = ApiClient(
      baseUrl: 'https://example.test',
      tokenStore: _MemoryTokenStore('token-1'),
      httpClient: client,
    );

    final answers = <DiagnosisAnswer>[
      const DiagnosisAnswer(
        questionId: 'true_priority',
        choiceId: 'life_balance',
      ),
      const DiagnosisAnswer(
        questionId: 'true_decision_axis',
        choiceId: 'low_stress',
      ),
      const DiagnosisAnswer(
        questionId: 'night_goal_primary',
        choiceId: 'next_visit',
      ),
      const DiagnosisAnswer(
        questionId: 'night_temperature',
        choiceId: 'calm_safe',
      ),
      const DiagnosisAnswer(
        questionId: 'night_game_tolerance',
        choiceId: 'avoid_game',
      ),
      const DiagnosisAnswer(
        questionId: 'night_customer_allocation',
        choiceId: 'wide_touchpoints',
      ),
      const DiagnosisAnswer(
        questionId: 'night_risk_response',
        choiceId: 'firefighting_safe',
      ),
    ];

    final result = await apiClient.completeDiagnosis(answers);

    expect(result.trueSelfType, 'Stability');
    expect(result.nightSelfType, 'Balance');
    expect(getSettingsCount, 2);
    expect(putSettingsCount, 2);
  });

  test('getSettings はヘッダ未設定時にボディのetagを使う', () async {
    String? observedIfMatch;

    final client = MockClient((http.Request request) async {
      if (request.url.path == '/api/v1/me/settings' &&
          request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'settings': {'settings_schema_version': 1},
            'etag': 'etag-from-body',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (request.url.path == '/api/v1/me/settings' &&
          request.method == 'PUT') {
        observedIfMatch = request.headers['if-match'];
        return http.Response(
          jsonEncode({
            'settings': {'settings_schema_version': 1},
            'etag': 'etag-next',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (request.url.path == '/api/v1/me/diagnosis' &&
          request.method == 'POST') {
        return http.Response(
          jsonEncode({
            'persona_version': 3,
            'true_self_type': 'Stability',
            'night_self_type': 'Balance',
            'persona_goal_primary': 'relationship_keep',
            'persona_goal_secondary': 'next_visit',
            'style_assertiveness': 60,
            'style_warmth': 70,
            'style_risk_guard': 80,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return http.Response('not found', 404);
    });

    final apiClient = ApiClient(
      baseUrl: 'https://example.test',
      tokenStore: _MemoryTokenStore('token-1'),
      httpClient: client,
    );

    final answers = <DiagnosisAnswer>[
      const DiagnosisAnswer(
        questionId: 'true_priority',
        choiceId: 'life_balance',
      ),
      const DiagnosisAnswer(
        questionId: 'true_decision_axis',
        choiceId: 'low_stress',
      ),
      const DiagnosisAnswer(
        questionId: 'night_goal_primary',
        choiceId: 'next_visit',
      ),
      const DiagnosisAnswer(
        questionId: 'night_temperature',
        choiceId: 'calm_safe',
      ),
      const DiagnosisAnswer(
        questionId: 'night_game_tolerance',
        choiceId: 'avoid_game',
      ),
      const DiagnosisAnswer(
        questionId: 'night_customer_allocation',
        choiceId: 'wide_touchpoints',
      ),
      const DiagnosisAnswer(
        questionId: 'night_risk_response',
        choiceId: 'firefighting_safe',
      ),
    ];

    await apiClient.completeDiagnosis(answers);

    expect(observedIfMatch, 'etag-from-body');
  });
}
