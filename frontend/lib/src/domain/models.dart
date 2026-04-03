class ApiError implements Exception {
  ApiError({
    required this.errorCode,
    required this.message,
    required this.httpStatus,
    this.remainingAttempts,
  });

  final String errorCode;
  final String message;
  final int httpStatus;
  // premium_comp失敗時のロックまでの残り回数（null = 関係なし）
  final int? remainingAttempts;

  factory ApiError.fromBody({
    required int httpStatus,
    required Map<String, dynamic>? body,
  }) {
    final rootCode = body?['error_code']?.toString();
    final rootMessage = body?['message']?.toString();

    final error = body?['error'];
    String? errorCode;
    String? message;
    int? remainingAttempts;
    if (error is Map<String, dynamic>) {
      errorCode = error['code']?.toString() ?? error['error_code']?.toString();
      message = error['message']?.toString();
      final errorDetail = error['detail'];
      if (errorDetail is Map<String, dynamic>) {
        remainingAttempts = (errorDetail['remaining_attempts'] as num?)
            ?.toInt();
      }
    }

    final detail = body?['detail'];
    if (detail is Map<String, dynamic>) {
      final detailError = detail['error'];
      if (detailError is Map<String, dynamic>) {
        errorCode ??= detailError['code']?.toString();
        message ??= detailError['message']?.toString();
        final detailErrorDetail = detailError['detail'];
        if (detailErrorDetail is Map<String, dynamic>) {
          remainingAttempts ??=
              (detailErrorDetail['remaining_attempts'] as num?)?.toInt();
        }
      }
      errorCode ??= detail['error_code']?.toString();
      message ??= detail['message']?.toString();
    }

    return ApiError(
      errorCode: rootCode ?? errorCode ?? _fallbackCode(httpStatus),
      message: rootMessage ?? message ?? 'うまくつながらなかった',
      httpStatus: httpStatus,
      remainingAttempts: remainingAttempts,
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
      token:
          json['access_token']?.toString() ?? json['token']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
    );
  }
}

class PremiumCompRequestResult {
  PremiumCompRequestResult({
    required this.approved,
    required this.requestCount,
    this.remainingAttempts,
  });

  final bool approved;
  final int requestCount;
  final int? remainingAttempts;

  factory PremiumCompRequestResult.fromJson(Map<String, dynamic> json) {
    return PremiumCompRequestResult(
      approved: json['approved'] == true,
      requestCount: (json['request_count'] as num?)?.toInt() ?? 0,
      remainingAttempts: (json['remaining_attempts'] as num?)?.toInt(),
    );
  }
}

class CustomerSummary {
  CustomerSummary({
    required this.customerId,
    required this.displayName,
    required this.relationshipStage,
    this.nickname,
    this.callName,
    this.areaTag,
    this.jobTag,
    this.memoSummary,
    this.lastVisitAt,
    this.lastContactAt,
    required this.isArchived,
  });

  final String customerId;
  final String displayName;
  final String relationshipStage;
  final String? nickname;
  final String? callName;
  final String? areaTag;
  final String? jobTag;
  final String? memoSummary;
  final String? lastVisitAt;
  final String? lastContactAt;
  final bool isArchived;

  factory CustomerSummary.fromJson(Map<String, dynamic> json) {
    return CustomerSummary(
      customerId: json['customer_id']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      relationshipStage: json['relationship_stage']?.toString() ?? 'new',
      nickname: json['nickname']?.toString(),
      callName: json['call_name']?.toString(),
      areaTag: json['area_tag']?.toString(),
      jobTag: json['job_tag']?.toString(),
      memoSummary: json['memo_summary']?.toString(),
      lastVisitAt: json['last_visit_at']?.toString(),
      lastContactAt: json['last_contact_at']?.toString(),
      isArchived: json['is_archived'] == true,
    );
  }
}

class CreateCustomerInput {
  CreateCustomerInput({
    required this.displayName,
    this.nickname,
    this.callName,
    this.areaTag,
    this.jobTag,
    this.memoSummary,
    this.relationshipStage = 'new',
  });

  final String displayName;
  final String? nickname;
  final String? callName;
  final String? areaTag;
  final String? jobTag;
  final String? memoSummary;
  final String relationshipStage;

  Map<String, dynamic> toJson() {
    return {
      'display_name': displayName,
      'nickname': nickname,
      'call_name': callName,
      'area_tag': areaTag,
      'job_tag': jobTag,
      'memo_summary': memoSummary,
      'relationship_stage': relationshipStage,
    };
  }
}

class UpdateCustomerInput {
  UpdateCustomerInput({
    required this.displayName,
    this.nickname,
    this.callName,
    this.areaTag,
    this.jobTag,
    this.memoSummary,
    this.relationshipStage = 'new',
    this.isArchived = false,
  });

  final String displayName;
  final String? nickname;
  final String? callName;
  final String? areaTag;
  final String? jobTag;
  final String? memoSummary;
  final String relationshipStage;
  final bool isArchived;

  Map<String, dynamic> toJson() {
    return {
      'display_name': displayName,
      'nickname': nickname,
      'call_name': callName,
      'area_tag': areaTag,
      'job_tag': jobTag,
      'memo_summary': memoSummary,
      'relationship_stage': relationshipStage,
      'is_archived': isArchived,
    };
  }
}

class CustomerTag {
  CustomerTag({required this.tagId, required this.category, required this.value});

  final String tagId;
  final String category;
  final String value;

  factory CustomerTag.fromJson(Map<String, dynamic> json) {
    return CustomerTag(
      tagId: json['tag_id']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
    );
  }
}

class CustomerVisitLog {
  CustomerVisitLog({
    required this.visitLogId,
    required this.visitedOn,
    required this.visitType,
    this.memoShort,
    this.spendLevel,
    this.moodTag,
  });

  final String visitLogId;
  final String visitedOn;
  final String visitType;
  final String? memoShort;
  final String? spendLevel;
  final String? moodTag;

  factory CustomerVisitLog.fromJson(Map<String, dynamic> json) {
    return CustomerVisitLog(
      visitLogId: json['visit_log_id']?.toString() ?? '',
      visitedOn: json['visited_on']?.toString() ?? '',
      visitType: json['visit_type']?.toString() ?? '',
      memoShort: json['memo_short']?.toString(),
      spendLevel: json['spend_level']?.toString(),
      moodTag: json['mood_tag']?.toString(),
    );
  }
}

class CustomerEvent {
  CustomerEvent({
    required this.eventId,
    required this.eventType,
    required this.eventDate,
    required this.title,
    this.note,
    this.remindDaysBefore = 0,
    this.isActive = true,
  });

  final String eventId;
  final String eventType;
  final String eventDate;
  final String title;
  final String? note;
  final int remindDaysBefore;
  final bool isActive;

  factory CustomerEvent.fromJson(Map<String, dynamic> json) {
    return CustomerEvent(
      eventId: json['event_id']?.toString() ?? '',
      eventType: json['event_type']?.toString() ?? '',
      eventDate: json['event_date']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      note: json['note']?.toString(),
      remindDaysBefore: (json['remind_days_before'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] != false,
    );
  }
}

class CustomerDetail {
  CustomerDetail({
    required this.customer,
    required this.tags,
    required this.visitLogs,
    required this.events,
  });

  final CustomerSummary customer;
  final List<CustomerTag> tags;
  final List<CustomerVisitLog> visitLogs;
  final List<CustomerEvent> events;

  factory CustomerDetail.fromJson(Map<String, dynamic> json) {
    final tagsRaw = json['tags'];
    final visitLogsRaw = json['visit_logs'];
    final eventsRaw = json['events'];
    return CustomerDetail(
      customer: CustomerSummary.fromJson(
        (json['customer'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      tags: tagsRaw is List
          ? tagsRaw.whereType<Map<String, dynamic>>().map(CustomerTag.fromJson).toList()
          : <CustomerTag>[],
      visitLogs: visitLogsRaw is List
          ? visitLogsRaw
                .whereType<Map<String, dynamic>>()
                .map(CustomerVisitLog.fromJson)
                .toList()
          : <CustomerVisitLog>[],
      events: eventsRaw is List
          ? eventsRaw
                .whereType<Map<String, dynamic>>()
                .map(CustomerEvent.fromJson)
                .toList()
          : <CustomerEvent>[],
    );
  }
}

class CustomerReminder {
  CustomerReminder({
    required this.reminderId,
    required this.reminderType,
    required this.title,
    required this.dueDate,
    required this.daysDelta,
    required this.customer,
  });

  final String reminderId;
  final String reminderType;
  final String title;
  final String dueDate;
  final int daysDelta;
  final CustomerSummary customer;

  factory CustomerReminder.fromJson(Map<String, dynamic> json) {
    final customerRaw = json['customer'];
    return CustomerReminder(
      reminderId: json['reminder_id']?.toString() ?? '',
      reminderType: json['reminder_type']?.toString() ?? 'event',
      title: json['title']?.toString() ?? '',
      dueDate: json['due_date']?.toString() ?? '',
      daysDelta: (json['days_delta'] as num?)?.toInt() ?? 0,
      customer: CustomerSummary.fromJson(
        customerRaw is Map<String, dynamic> ? customerRaw : <String, dynamic>{},
      ),
    );
  }
}

class ReplaceCustomerTagsInput {
  ReplaceCustomerTagsInput({required this.tags});

  final List<CustomerTagInput> tags;

  Map<String, dynamic> toJson() {
    return {
      'tags': tags.map((e) => e.toJson()).toList(),
    };
  }
}

class CustomerTagInput {
  CustomerTagInput({required this.category, required this.value});

  final String category;
  final String value;

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'value': value,
    };
  }
}

class CreateVisitLogInput {
  CreateVisitLogInput({
    required this.visitedOn,
    required this.visitType,
    this.stayMinutes,
    this.spendLevel,
    this.drinkAmountTag,
    this.moodTag,
    this.memoShort,
  });

  final String visitedOn;
  final String visitType;
  final int? stayMinutes;
  final String? spendLevel;
  final String? drinkAmountTag;
  final String? moodTag;
  final String? memoShort;

  Map<String, dynamic> toJson() {
    return {
      'visited_on': visitedOn,
      'visit_type': visitType,
      'stay_minutes': stayMinutes,
      'spend_level': spendLevel,
      'drink_amount_tag': drinkAmountTag,
      'mood_tag': moodTag,
      'memo_short': memoShort,
    };
  }
}

class CreateCustomerEventInput {
  CreateCustomerEventInput({
    required this.eventType,
    required this.eventDate,
    required this.title,
    this.note,
    this.remindDaysBefore = 0,
    this.isActive = true,
  });

  final String eventType;
  final String eventDate;
  final String title;
  final String? note;
  final int remindDaysBefore;
  final bool isActive;

  Map<String, dynamic> toJson() {
    return {
      'event_type': eventType,
      'event_date': eventDate,
      'title': title,
      'note': note,
      'remind_days_before': remindDaysBefore,
      'is_active': isActive,
    };
  }
}

class UpdateCustomerEventReminderInput {
  UpdateCustomerEventReminderInput({required this.remindDaysBefore});

  final int remindDaysBefore;

  Map<String, dynamic> toJson() {
    return {
      'remind_days_before': remindDaysBefore,
    };
  }
}
