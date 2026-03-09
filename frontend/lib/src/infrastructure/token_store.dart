import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class TokenStore {
  Future<String?> read();

  Future<void> write(String token);

  Future<void> delete();
}

class SecureTokenStore implements TokenStore {
  const SecureTokenStore();

  static const _key = 'permy_access_token';
  static const _storage = FlutterSecureStorage();

  @override
  Future<void> delete() async {
    await _storage.delete(key: _key);
  }

  @override
  Future<String?> read() async {
    return _storage.read(key: _key);
  }

  @override
  Future<void> write(String token) async {
    await _storage.write(key: _key, value: token);
  }
}
