import 'package:shared_preferences/shared_preferences.dart';

/// ユーザー自身のLINE名をローカルに保存・読み込みする
class LineNameStore {
  static const _key = 'my_line_name';

  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  Future<void> write(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, name);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
