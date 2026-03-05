import 'dart:convert';

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
  });

  Future<SettingsSnapshot> getSettings();

  Future<void> completeDiagnosis(List<int> answers);
}

class ApiClient implements AppApiClient {
  ApiClient({
    required this.baseUrl,
    required this.tokenStore,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final TokenStore tokenStore;
  final http.Client _httpClient;
  final Uuid _uuid = const Uuid();

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
  }) async {
    await bootstrapAuth();
    return _runWithAuthRetry(() async {
      final token = await tokenStore.read();
      final response = await _httpClient.post(
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
        }),
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
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/api/v1/me/settings'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = _tryJson(response.body) ?? <String, dynamic>{};
        final settings = body['settings'];
        return SettingsSnapshot(
          settings: settings is Map<String, dynamic>
              ? Map<String, dynamic>.from(settings)
              : <String, dynamic>{},
          etag: response.headers['etag'] ?? '',
        );
      }

      throw ApiError.fromBody(
        httpStatus: response.statusCode,
        body: _tryJson(response.body),
      );
    });
  }

  @override
  Future<void> completeDiagnosis(List<int> answers) async {
    await bootstrapAuth();

    final diagnosis = await _runWithAuthRetry(() async {
      final token = await tokenStore.read();
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/api/v1/me/diagnosis'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'answers': answers}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = _tryJson(response.body) ?? <String, dynamic>{};
        return DiagnosisResult(
          trueSelfType:
              body['true_self_type']?.toString() ?? inferDiagnosis(answers).trueSelfType,
          nightSelfType:
              body['night_self_type']?.toString() ?? inferDiagnosis(answers).nightSelfType,
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

    final current = await getSettings();
    final updated = Map<String, dynamic>.from(current.settings)
      ..['settings_schema_version'] =
          (current.settings['settings_schema_version'] as num?)?.toInt() ?? 1
      ..['persona_version'] = 2
      ..['true_self_type'] = diagnosis.trueSelfType
      ..['night_self_type'] = diagnosis.nightSelfType;

    await _runWithAuthRetry(() async {
      final token = await tokenStore.read();
      final response = await _httpClient.put(
        Uri.parse('$baseUrl/api/v1/me/settings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'If-Match': current.etag,
        },
        body: jsonEncode({'settings': updated}),
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
    final response = await _httpClient.post(
      Uri.parse('$baseUrl/api/v1/auth/anonymous'),
      headers: {'Content-Type': 'application/json'},
      body: '{}',
    );

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
}
