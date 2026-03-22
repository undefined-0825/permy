import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import '../domain/persona_diagnosis.dart';
import 'token_store.dart';

abstract class AppApiClient {
  Future<void> bootstrapAuth();

  Future<GenerateResult> generate({
    required String historyText,
    int comboId,
    String? myLineName,
  });

  Future<SettingsSnapshot> getSettings();

  Future<void> updateSettings(Map<String, dynamic> settings, String etag);

  Future<DiagnosisResult> completeDiagnosis(List<DiagnosisAnswer> answers);

  Future<MigrationIssueResult> issueMigrationCode();

  Future<MigrationConsumeResult> consumeMigrationCode(String code);

  Future<void> postTelemetryEvents(List<Map<String, dynamic>> events);

  Future<AppVersionInfo> getAppVersionInfo();

  Future<void> verifyBilling({
    required String platform,
    required String productId,
    required String purchaseToken,
  });

  Future<ProCompRequestResult> requestProComp(String email);

  Future<void> deleteAccount();
}

class ApiClient implements AppApiClient {
  ApiClient({
    required this.baseUrl,
    required this.tokenStore,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 30),
    this.debugLog,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final TokenStore tokenStore;
  final http.Client _httpClient;
  final Duration requestTimeout;
  final Uuid _uuid = const Uuid();
  final void Function(String message)? debugLog;

  @override
  Future<void> bootstrapAuth() async {
    final token = await tokenStore.read();
    if (token == null || token.isEmpty) {
      await _authenticateAnonymous();
    }
  }

  @override
  Future<GenerateResult> generate({
    required String historyText,
    int comboId = 0,
    String? myLineName,
  }) async {
    await bootstrapAuth();
    return _runWithAuthRetry(() async {
      final token = await tokenStore.read();
      final response = await _sendWithTimeout(
        () => _httpClient.post(
          Uri.parse('$baseUrl/api/v1/generate'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'Idempotency-Key': _uuid.v4(),
          },
          body: jsonEncode({
            'history_text': historyText,
            'combo_id': comboId,
            'tuning': null,
            if (myLineName != null) 'my_line_name': myLineName,
          }),
        ),
        method: 'POST',
        path: '/api/v1/generate',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return GenerateResult.fromJson(body);
      }

      throw ApiError.fromBody(
        httpStatus: response.statusCode,
        body: _tryJson(response.body),
      );
    });
  }

  @override
  Future<SettingsSnapshot> getSettings() async {
    await bootstrapAuth();
    return _runWithAuthRetry(() async {
      final token = await tokenStore.read();
      _logHttpRequest('GET', '/api/v1/me/settings');
      final response = await _sendWithTimeout(
        () => _httpClient.get(
          Uri.parse('$baseUrl/api/v1/me/settings'),
          headers: {'Authorization': 'Bearer $token'},
        ),
        method: 'GET',
        path: '/api/v1/me/settings',
      );
      _logHttpResponse('GET', '/api/v1/me/settings', response.statusCode);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = _tryJson(response.body) ?? <String, dynamic>{};
        final settings = body['settings'];
        final bodyEtag = body['etag']?.toString() ?? '';
        final responseEtag = response.headers['etag'] ?? '';
        return SettingsSnapshot(
          settings: settings is Map<String, dynamic>
              ? Map<String, dynamic>.from(settings)
              : <String, dynamic>{},
          etag: responseEtag.isNotEmpty ? responseEtag : bodyEtag,
        );
      }

      throw ApiError.fromBody(
        httpStatus: response.statusCode,
        body: _tryJson(response.body),
      );
    });
  }

  @override
  Future<void> updateSettings(
    Map<String, dynamic> settings,
    String etag,
  ) async {
    await bootstrapAuth();
    return _runWithAuthRetry(() async {
      final token = await tokenStore.read();
      _logHttpRequest(
        'PUT',
        '/api/v1/me/settings',
        extra: {
          'ifMatchPresent': etag.isNotEmpty,
          'settingsKeys': settings.keys.length,
        },
      );
      final response = await _sendWithTimeout(
        () => _httpClient.put(
          Uri.parse('$baseUrl/api/v1/me/settings'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'If-Match': etag,
          },
          body: jsonEncode({'settings': settings}),
        ),
        method: 'PUT',
        path: '/api/v1/me/settings',
      );
      _logHttpResponse('PUT', '/api/v1/me/settings', response.statusCode);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }

      throw ApiError.fromBody(
        httpStatus: response.statusCode,
        body: _tryJson(response.body),
      );
    });
  }

  @override
  Future<DiagnosisResult> completeDiagnosis(
    List<DiagnosisAnswer> answers,
  ) async {
    await bootstrapAuth();

    final diagnosis = await _runWithAuthRetry(() async {
      final token = await tokenStore.read();
      _logHttpRequest(
        'POST',
        '/api/v1/me/diagnosis',
        extra: {'answersCount': answers.length},
      );
      final response = await _sendWithTimeout(
        () => _httpClient.post(
          Uri.parse('$baseUrl/api/v1/me/diagnosis'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'answers': answers.map((answer) => answer.toJson()).toList(),
          }),
        ),
        method: 'POST',
        path: '/api/v1/me/diagnosis',
      );
      _logHttpResponse('POST', '/api/v1/me/diagnosis', response.statusCode);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = _tryJson(response.body) ?? <String, dynamic>{};
        final fallback = inferDiagnosis(answers);
        return DiagnosisResult(
          trueSelfType:
              body['true_self_type']?.toString() ?? fallback.trueSelfType,
          nightSelfType:
              body['night_self_type']?.toString() ?? fallback.nightSelfType,
          personaGoalPrimary:
              body['persona_goal_primary']?.toString() ??
              fallback.personaGoalPrimary,
          personaGoalSecondary: body['persona_goal_secondary']?.toString(),
          styleAssertiveness:
              (body['style_assertiveness'] as num?)?.toInt() ??
              fallback.styleAssertiveness,
          styleWarmth:
              (body['style_warmth'] as num?)?.toInt() ?? fallback.styleWarmth,
          styleRiskGuard:
              (body['style_risk_guard'] as num?)?.toInt() ??
              fallback.styleRiskGuard,
        );
      }

      if (response.statusCode == 404) {
        return inferDiagnosis(answers);
      }

      throw ApiError.fromBody(
        httpStatus: response.statusCode,
        body: _tryJson(response.body),
      );
    });

    await _saveDiagnosisSettingsWithRetry(diagnosis);

    return diagnosis;
  }

  Future<void> _saveDiagnosisSettingsWithRetry(
    DiagnosisResult diagnosis,
  ) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      _logClientEvent('save_diagnosis_settings_attempt', {
        'attempt': attempt + 1,
      });
      final current = await getSettings();
      final updated = Map<String, dynamic>.from(current.settings)
        ..['settings_schema_version'] =
            (current.settings['settings_schema_version'] as num?)?.toInt() ?? 1
        ..['persona_version'] = 3
        ..['true_self_type'] = diagnosis.trueSelfType
        ..['night_self_type'] = diagnosis.nightSelfType
        ..['persona_goal_primary'] = diagnosis.personaGoalPrimary
        ..['persona_goal_secondary'] = diagnosis.personaGoalSecondary
        ..['style_assertiveness'] = diagnosis.styleAssertiveness
        ..['style_warmth'] = diagnosis.styleWarmth
        ..['style_risk_guard'] = diagnosis.styleRiskGuard;

      try {
        await updateSettings(updated, current.etag);
        _logClientEvent('save_diagnosis_settings_success', {
          'attempt': attempt + 1,
        });
        return;
      } on ApiError catch (e) {
        final isRetryableConflict =
            e.errorCode == 'SETTINGS_VERSION_CONFLICT' ||
            e.errorCode == 'VALIDATION_FAILED';
        _logClientEvent('save_diagnosis_settings_error', {
          'attempt': attempt + 1,
          'httpStatus': e.httpStatus,
          'errorCode': e.errorCode,
          'retryable': isRetryableConflict,
        });
        if (!isRetryableConflict || attempt == 1) {
          rethrow;
        }
      }
    }
  }

  @override
  Future<MigrationIssueResult> issueMigrationCode() async {
    await bootstrapAuth();
    return _runWithAuthRetry(() async {
      final token = await tokenStore.read();
      final response = await _sendWithTimeout(
        () => _httpClient.post(
          Uri.parse('$baseUrl/api/v1/migration/issue'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: '{}',
        ),
        method: 'POST',
        path: '/api/v1/migration/issue',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = _tryJson(response.body) ?? <String, dynamic>{};
        return MigrationIssueResult.fromJson(body);
      }

      throw ApiError.fromBody(
        httpStatus: response.statusCode,
        body: _tryJson(response.body),
      );
    });
  }

  @override
  Future<MigrationConsumeResult> consumeMigrationCode(String code) async {
    final response = await _sendWithTimeout(
      () => _httpClient.post(
        Uri.parse('$baseUrl/api/v1/migration/consume'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'migration_code': code}),
      ),
      method: 'POST',
      path: '/api/v1/migration/consume',
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = _tryJson(response.body) ?? <String, dynamic>{};
      final result = MigrationConsumeResult.fromJson(body);
      // token を保存
      await tokenStore.write(result.token);
      return result;
    }

    throw ApiError.fromBody(
      httpStatus: response.statusCode,
      body: _tryJson(response.body),
    );
  }

  @override
  Future<void> postTelemetryEvents(List<Map<String, dynamic>> events) async {
    await bootstrapAuth();
    return _runWithAuthRetry(() async {
      final token = await tokenStore.read();
      final response = await _sendWithTimeout(
        () => _httpClient.post(
          Uri.parse('$baseUrl/api/v1/telemetry/events'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'events': events}),
        ),
        method: 'POST',
        path: '/api/v1/telemetry/events',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }

      throw ApiError.fromBody(
        httpStatus: response.statusCode,
        body: _tryJson(response.body),
      );
    });
  }

  @override
  Future<AppVersionInfo> getAppVersionInfo() async {
    final response = await _sendWithTimeout(
      () => _httpClient.get(Uri.parse('$baseUrl/api/v1/version')),
      method: 'GET',
      path: '/api/v1/version',
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = _tryJson(response.body) ?? <String, dynamic>{};
      return AppVersionInfo.fromJson(body);
    }

    throw ApiError.fromBody(
      httpStatus: response.statusCode,
      body: _tryJson(response.body),
    );
  }

  @override
  Future<void> verifyBilling({
    required String platform,
    required String productId,
    required String purchaseToken,
  }) async {
    await bootstrapAuth();
    return _runWithAuthRetry(() async {
      final token = await tokenStore.read();
      final response = await _sendWithTimeout(
        () => _httpClient.post(
          Uri.parse('$baseUrl/api/v1/billing/verify'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'platform': platform,
            'product_id': productId,
            'purchase_token': purchaseToken,
          }),
        ),
        method: 'POST',
        path: '/api/v1/billing/verify',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }

      throw ApiError.fromBody(
        httpStatus: response.statusCode,
        body: _tryJson(response.body),
      );
    });
  }

  @override
  Future<ProCompRequestResult> requestProComp(String email) async {
    await bootstrapAuth();
    return _runWithAuthRetry(() async {
      final token = await tokenStore.read();
      final response = await _sendWithTimeout(
        () => _httpClient.post(
          Uri.parse('$baseUrl/api/v1/pro-comp/request'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'email': email}),
        ),
        method: 'POST',
        path: '/api/v1/pro-comp/request',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = _tryJson(response.body) ?? <String, dynamic>{};
        return ProCompRequestResult.fromJson(body);
      }

      throw ApiError.fromBody(
        httpStatus: response.statusCode,
        body: _tryJson(response.body),
      );
    });
  }

  @override
  Future<void> deleteAccount() async {
    await bootstrapAuth();
    return _runWithAuthRetry(() async {
      final token = await tokenStore.read();
      final response = await _sendWithTimeout(
        () => _httpClient.delete(
          Uri.parse('$baseUrl/api/v1/auth/me'),
          headers: {'Authorization': 'Bearer $token'},
        ),
        method: 'DELETE',
        path: '/api/v1/auth/me',
      );

      if (response.statusCode == 204) {
        await tokenStore.delete();
        return;
      }

      throw ApiError.fromBody(
        httpStatus: response.statusCode,
        body: _tryJson(response.body),
      );
    });
  }

  Future<T> _runWithAuthRetry<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiError catch (error) {
      if (error.httpStatus != 401) rethrow;
      await tokenStore.delete();
      await _authenticateAnonymous();
      return action();
    }
  }

  Future<void> _authenticateAnonymous() async {
    _logHttpRequest('POST', '/api/v1/auth/anonymous');
    final response = await _sendWithTimeout(
      () => _httpClient.post(
        Uri.parse('$baseUrl/api/v1/auth/anonymous'),
        headers: {'Content-Type': 'application/json'},
        body: '{}',
      ),
      method: 'POST',
      path: '/api/v1/auth/anonymous',
    );
    _logHttpResponse('POST', '/api/v1/auth/anonymous', response.statusCode);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final token = body['access_token']?.toString() ?? '';
      if (token.isEmpty) {
        throw ApiError(
          errorCode: 'AUTH_INVALID',
          message: '認証を始められなかった',
          httpStatus: 500,
        );
      }
      await tokenStore.write(token);
      return;
    }

    throw ApiError.fromBody(
      httpStatus: response.statusCode,
      body: _tryJson(response.body),
    );
  }

  Future<http.Response> _sendWithTimeout(
    Future<http.Response> Function() request, {
    required String method,
    required String path,
  }) async {
    try {
      return await request().timeout(requestTimeout);
    } on TimeoutException {
      _logClientEvent('http', {
        'stage': 'error',
        'method': method,
        'path': path,
        'error': 'timeout',
        'timeoutMs': requestTimeout.inMilliseconds,
      });
      throw ApiError(
        errorCode: 'UPSTREAM_TIMEOUT',
        message: '通信がタイムアウトしたよ',
        httpStatus: 504,
      );
    } on SocketException {
      _logClientEvent('http', {
        'stage': 'error',
        'method': method,
        'path': path,
        'error': 'socket',
      });
      throw ApiError(
        errorCode: 'UPSTREAM_UNAVAILABLE',
        message: 'ネットワークに接続できないよ',
        httpStatus: 503,
      );
    } on http.ClientException {
      _logClientEvent('http', {
        'stage': 'error',
        'method': method,
        'path': path,
        'error': 'client_exception',
      });
      throw ApiError(
        errorCode: 'UPSTREAM_UNAVAILABLE',
        message: '通信に失敗したよ',
        httpStatus: 503,
      );
    }
  }

  Map<String, dynamic>? _tryJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void _logHttpRequest(
    String method,
    String path, {
    Map<String, Object?>? extra,
  }) {
    final fields = <String, Object?>{
      'stage': 'request',
      'method': method,
      'path': path,
    };
    if (extra != null) {
      fields.addAll(extra);
    }
    _logClientEvent('http', fields);
  }

  void _logHttpResponse(String method, String path, int statusCode) {
    _logClientEvent('http', {
      'stage': 'response',
      'method': method,
      'path': path,
      'status': statusCode,
    });
  }

  void _logClientEvent(String event, Map<String, Object?> fields) {
    if (debugLog == null) return;
    final payload = <String, Object?>{'event': event, ...fields};
    debugLog!('[ApiClient] ${jsonEncode(payload)}');
  }
}
