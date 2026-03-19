class ApiError implements Exception {
  ApiError({
    required this.errorCode,
    required this.message,
    required this.httpStatus,
  });

  final String errorCode;
  final String message;
  final int httpStatus;

  factory ApiError.fromBody({
    required int httpStatus,
    required Map<String, dynamic>? body,
  }) {
    final rootCode = body?['error_code']?.toString();
    final rootMessage = body?['message']?.toString();

    final error = body?['error'];
    String? errorCode;
    String? message;
    if (error is Map<String, dynamic>) {
      errorCode = error['code']?.toString() ?? error['error_code']?.toString();
      message = error['message']?.toString();
    }

    final detail = body?['detail'];
    if (detail is Map<String, dynamic>) {
      final detailError = detail['error'];
      if (detailError is Map<String, dynamic>) {
        errorCode ??= detailError['code']?.toString();
        message ??= detailError['message']?.toString();
      }
      errorCode ??= detail['error_code']?.toString();
      message ??= detail['message']?.toString();
    }

    return ApiError(
      errorCode: rootCode ?? errorCode ?? _fallbackCode(httpStatus),
      message: rootMessage ?? message ?? 'うまくつながらなかった',
      httpStatus: httpStatus,
    );
  }

  static String _fallbackCode(int status) {
    if (status == 401) return 'AUTH_INVALID';
    if (status == 409) return 'SETTINGS_VERSION_CONFLICT';
    if (status == 429) return 'RATE_LIMITED';
    if (status == 503) return 'UPSTREAM_UNAVAILABLE';
    return 'INTERNAL_ERROR';
  }
}

class Candidate {
  Candidate({required this.label, required this.text});

  final String label;
  final String text;

  factory Candidate.fromJson(Map<String, dynamic> json) {
    return Candidate(
      label: json['label']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
    );
  }
}

class DailyInfo {
  DailyInfo({required this.limit, required this.used, required this.remaining});

  final int limit;
  final int used;
  final int remaining;

  factory DailyInfo.fromJson(Map<String, dynamic>? json) {
    final safe = json ?? <String, dynamic>{};
    return DailyInfo(
      limit: (safe['limit'] as num?)?.toInt() ?? 0,
      used: (safe['used'] as num?)?.toInt() ?? 0,
      remaining: (safe['remaining'] as num?)?.toInt() ?? 0,
    );
  }
}

class FollowupChoice {
  FollowupChoice({required this.id, required this.label});

  final String id;
  final String label;

  factory FollowupChoice.fromJson(Map<String, dynamic> json) {
    return FollowupChoice(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
    );
  }
}

class FollowupInfo {
  FollowupInfo({
    required this.key,
    required this.question,
    required this.choices,
  });

  final String key;
  final String question;
  final List<FollowupChoice> choices;

  factory FollowupInfo.fromJson(Map<String, dynamic> json) {
    final choicesRaw = json['choices'];
    final choices = choicesRaw is List
        ? choicesRaw
              .whereType<Map<String, dynamic>>()
              .map(FollowupChoice.fromJson)
              .toList()
        : <FollowupChoice>[];

    return FollowupInfo(
      key: json['key']?.toString() ?? '',
      question: json['question']?.toString() ?? '',
      choices: choices,
    );
  }
}

class GenerateResult {
  GenerateResult({
    required this.candidates,
    required this.plan,
    required this.daily,
    this.followup,
    this.modelHint,
    this.metaPro,
  });

  final List<Candidate> candidates;
  final String plan;
  final DailyInfo daily;
  final FollowupInfo? followup;
  final String? modelHint;
  final int? metaPro; // Proのみ：推定メーター（0..100）

  factory GenerateResult.fromJson(Map<String, dynamic> json) {
    final candidatesRaw = json['candidates'];
    final candidates = candidatesRaw is List
        ? candidatesRaw
              .whereType<Map<String, dynamic>>()
              .map(Candidate.fromJson)
              .toList()
        : <Candidate>[];

    final followupRaw = json['followup'];
    final followup = followupRaw is Map<String, dynamic>
        ? FollowupInfo.fromJson(followupRaw)
        : null;

    final metaProRaw = json['meta']?['pro'];
    final metaPro = metaProRaw is num ? metaProRaw.toInt() : null;

    return GenerateResult(
      candidates: candidates,
      plan: json['plan']?.toString() ?? 'free',
      daily: DailyInfo.fromJson(json['daily'] as Map<String, dynamic>?),
      followup: followup,
      modelHint: json['model_hint']?.toString(),
      metaPro: metaPro,
    );
  }
}

class SettingsSnapshot {
  SettingsSnapshot({required this.settings, required this.etag});

  final Map<String, dynamic> settings;
  final String etag;
}

class AppVersionInfo {
  AppVersionInfo({
    required this.latestVersion,
    required this.minSupportedVersion,
    required this.androidStoreUrl,
    required this.iosStoreUrl,
    this.releaseNoteTitle = '',
    this.releaseNoteBody = '',
  });

  final String latestVersion;
  final String minSupportedVersion;
  final String androidStoreUrl;
  final String iosStoreUrl;
  final String releaseNoteTitle;
  final String releaseNoteBody;

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      latestVersion:
          json['latest_version']?.toString() ??
          json['version']?.toString() ??
          '',
      minSupportedVersion:
          json['min_supported_version']?.toString() ??
          json['version']?.toString() ??
          '',
      androidStoreUrl: json['android_store_url']?.toString() ?? '',
      iosStoreUrl: json['ios_store_url']?.toString() ?? '',
      releaseNoteTitle: json['release_note_title']?.toString() ?? '',
      releaseNoteBody: json['release_note_body']?.toString() ?? '',
    );
  }
}

class MigrationIssueResult {
  MigrationIssueResult({required this.migrationCode, required this.expiresAt});

  final String migrationCode;
  final String expiresAt;

  factory MigrationIssueResult.fromJson(Map<String, dynamic> json) {
    return MigrationIssueResult(
      migrationCode: json['migration_code']?.toString() ?? '',
      expiresAt: json['expires_at']?.toString() ?? '',
    );
  }
}

class MigrationConsumeResult {
  MigrationConsumeResult({required this.token, required this.userId});

  final String token;
  final String userId;

  factory MigrationConsumeResult.fromJson(Map<String, dynamic> json) {
    return MigrationConsumeResult(
      token: json['token']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
    );
  }
}
