import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sample_app/src/domain/models.dart';
import 'package:sample_app/src/infrastructure/api_client.dart';
import 'package:sample_app/src/infrastructure/token_store.dart';

class _FakeTokenStore implements TokenStore {
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
  test('通信がタイムアウトした場合はUPSTREAM_TIMEOUTを返す', () async {
    final client = MockClient((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return http.Response('{}', 200);
    });

    final apiClient = ApiClient(
      baseUrl: 'https://example.com',
      tokenStore: _FakeTokenStore(),
      httpClient: client,
      requestTimeout: const Duration(milliseconds: 10),
    );

    expect(
      () => apiClient.getAppVersionInfo(),
      throwsA(
        isA<ApiError>().having(
          (error) => error.errorCode,
          'errorCode',
          'UPSTREAM_TIMEOUT',
        ),
      ),
    );
  });
}
