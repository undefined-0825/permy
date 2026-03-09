import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/telemetry_event.dart';
import 'api_client.dart';

/// Telemetryイベントキュー管理（最大100件、10件で自動送信）
class TelemetryQueue {
  TelemetryQueue({required this.apiClient});

  final AppApiClient apiClient;

  static const String _queueKey = 'telemetry_queue';
  static const int _maxQueueSize = 100;
  static const int _batchSize = 10;

  /// イベントを追加してキューイング
  Future<void> enqueue(TelemetryEvent event) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = _loadQueue(prefs);

    queue.add(event.toJson());

    // 上限を超えたら古いものから削除
    while (queue.length > _maxQueueSize) {
      queue.removeAt(0);
    }

    await prefs.setString(_queueKey, jsonEncode(queue));

    // 10件溜まったら自動送信
    if (queue.length >= _batchSize) {
      await flush();
    }
  }

  /// キュー内のイベントをすべて送信
  Future<void> flush() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = _loadQueue(prefs);

    if (queue.isEmpty) return;

    // 最大100件までバッチ送信
    final batch = queue.take(100).toList();

    try {
      await apiClient.postTelemetryEvents(batch);
      // 成功したら送信済みを削除
      queue.removeRange(0, batch.length);
      await prefs.setString(_queueKey, jsonEncode(queue));
    } catch (_) {
      // 失敗時はキューを保持（次回リトライ）
      // ログは出さない（Telemetryエラーでユーザー体験を妨げない）
    }
  }

  List<Map<String, dynamic>> _loadQueue(SharedPreferences prefs) {
    final raw = prefs.getString(_queueKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
