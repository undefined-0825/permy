import 'package:flutter_test/flutter_test.dart';
import 'package:sample_app/src/domain/app_versioning.dart';

void main() {
  test('同一バージョンは 0 を返す', () {
    expect(compareAppVersions('1.2.3', '1.2.3'), 0);
  });

  test('左が古いと -1 を返す', () {
    expect(compareAppVersions('1.2.3', '1.3.0'), -1);
  });

  test('左が新しいと 1 を返す', () {
    expect(compareAppVersions('2.0.0', '1.9.9'), 1);
  });

  test('build番号付きでも比較できる', () {
    expect(compareAppVersions('1.2.3+4', '1.2.4+1'), -1);
    expect(compareAppVersions('1.2.3+4', '1.2.3+99'), 0);
  });

  test('桁数が違っても比較できる', () {
    expect(compareAppVersions('1.2', '1.2.0'), 0);
    expect(compareAppVersions('1.2.1', '1.2'), 1);
  });
}
