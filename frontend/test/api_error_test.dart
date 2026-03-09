import 'package:flutter_test/flutter_test.dart';
import 'package:sample_app/src/domain/models.dart';

void main() {
  test('detail.error.code 形式を正しく解釈する', () {
    final error = ApiError.fromBody(
      httpStatus: 409,
      body: {
        'detail': {
          'error': {'code': 'ETAG_MISMATCH', 'message': '設定が競合しました'},
        },
      },
    );

    expect(error.errorCode, 'ETAG_MISMATCH');
    expect(error.message, '設定が競合しました');
    expect(error.httpStatus, 409);
  });

  test('error_code 形式を正しく解釈する', () {
    final error = ApiError.fromBody(
      httpStatus: 429,
      body: {'error_code': 'DAILY_LIMIT_EXCEEDED', 'message': '本日の上限です'},
    );

    expect(error.errorCode, 'DAILY_LIMIT_EXCEEDED');
    expect(error.message, '本日の上限です');
  });
}
