/// Telemetry イベント（本文ゼロ厳守）
abstract class TelemetryEvent {
  const TelemetryEvent({
    required this.eventName,
    required this.appVersion,
    required this.os,
    this.deviceClass = 'unknown',
  });

  final String eventName;
  final String appVersion;
  final String os;
  final String deviceClass;

  Map<String, dynamic> toJson();
}

/// generate_requested: 生成リクエスト開始
class GenerateRequestedEvent extends TelemetryEvent {
  const GenerateRequestedEvent({
    required super.appVersion,
    required super.os,
    super.deviceClass,
    required this.dailyUsed,
    required this.dailyRemaining,
    required this.hasNgSetting,
    required this.personaVersion,
  }) : super(eventName: 'generate_requested');

  final int dailyUsed;
  final int dailyRemaining;
  final bool hasNgSetting;
  final int personaVersion;

  @override
  Map<String, dynamic> toJson() => {
    'event_name': eventName,
    'app_version': appVersion,
    'os': os,
    'device_class': deviceClass,
    'daily_used': dailyUsed,
    'daily_remaining': dailyRemaining,
    'has_ng_setting': hasNgSetting,
    'persona_version': personaVersion,
  };
}

/// generate_succeeded: 生成成功
class GenerateSucceededEvent extends TelemetryEvent {
  const GenerateSucceededEvent({
    required super.appVersion,
    required super.os,
    super.deviceClass,
    required this.latencyMs,
    required this.ngGateTriggered,
    required this.followupReturned,
  }) : super(eventName: 'generate_succeeded');

  final int latencyMs;
  final bool ngGateTriggered;
  final bool followupReturned;

  @override
  Map<String, dynamic> toJson() => {
    'event_name': eventName,
    'app_version': appVersion,
    'os': os,
    'device_class': deviceClass,
    'latency_ms': latencyMs,
    'ng_gate_triggered': ngGateTriggered,
    'followup_returned': followupReturned,
  };
}

/// generate_failed: 生成失敗
class GenerateFailedEvent extends TelemetryEvent {
  const GenerateFailedEvent({
    required super.appVersion,
    required super.os,
    super.deviceClass,
    this.latencyMs,
    required this.errorCode,
  }) : super(eventName: 'generate_failed');

  final int? latencyMs;
  final String errorCode;

  @override
  Map<String, dynamic> toJson() => {
    'event_name': eventName,
    'app_version': appVersion,
    'os': os,
    'device_class': deviceClass,
    if (latencyMs != null) 'latency_ms': latencyMs,
    'error_code': errorCode,
  };
}

/// candidate_copied: 候補コピー
class CandidateCopiedEvent extends TelemetryEvent {
  const CandidateCopiedEvent({
    required super.appVersion,
    required super.os,
    super.deviceClass,
    required this.candidateId,
  }) : super(eventName: 'candidate_copied');

  final String candidateId;

  @override
  Map<String, dynamic> toJson() => {
    'event_name': eventName,
    'app_version': appVersion,
    'os': os,
    'device_class': deviceClass,
    'candidate_id': candidateId,
  };
}

/// app_opened: アプリ起動
class AppOpenedEvent extends TelemetryEvent {
  const AppOpenedEvent({
    required super.appVersion,
    required super.os,
    super.deviceClass,
  }) : super(eventName: 'app_opened');

  @override
  Map<String, dynamic> toJson() => {
    'event_name': eventName,
    'app_version': appVersion,
    'os': os,
    'device_class': deviceClass,
  };
}
