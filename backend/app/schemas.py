from __future__ import annotations

from pydantic import BaseModel, Field
from typing import Any, Literal


class ErrorEnvelope(BaseModel):
    error: dict


class AuthAnonymousResponse(BaseModel):
    user_id: str
    access_token: str


class SettingsResponse(BaseModel):
    settings: dict
    etag: str | None = None


class SettingsUpdateRequest(BaseModel):
    settings: dict = Field(default_factory=dict)


class DiagnosisAnswer(BaseModel):
    question_id: str
    choice_id: str


class DiagnosisRequest(BaseModel):
    answers: list[DiagnosisAnswer] = Field(..., min_length=7, max_length=7)


class DiagnosisResponse(BaseModel):
    persona_version: int
    true_self_type: Literal["Stability", "Independence", "Approval", "Realism", "Romance"]
    night_self_type: Literal["VisitPush", "Heal", "LittleDevil", "BigClient", "Balance"]
    persona_goal_primary: Literal[
        "next_visit",
        "relationship_keep",
        "long_term_growth",
        "firefighting",
        "special_distance",
    ]
    persona_goal_secondary: str | None = None
    style_assertiveness: int = Field(..., ge=0, le=100)
    style_warmth: int = Field(..., ge=0, le=100)
    style_risk_guard: int = Field(..., ge=0, le=100)


class GenerateRequest(BaseModel):
    history_text: str = Field(..., description="トーク履歴の原文（本文保存なし）")
    combo_id: int = Field(..., ge=0, le=5)
    tuning: dict | None = None  # Proのみ（クライアントが付与）
    my_line_name: str | None = None  # ユーザー自身のLINE名（フロントが付与）
    customer_context: dict[str, Any] | None = None  # 顧客由来コンテキスト（任意）


class Candidate(BaseModel):
    label: str
    text: str


class DailyInfo(BaseModel):
    date: str
    limit: int
    used: int
    remaining: int


class FollowupChoice(BaseModel):
    """Followup選択肢"""
    id: str
    label: str


class Followup(BaseModel):
    """入力不足時の聞き返し（0または1件）"""
    key: Literal["relationship_type", "reply_length_pref", "emoji_amount_pref", "reaction_level_pref", "ng_tags", "ng_free_phrases"]
    question: str
    choices: list[FollowupChoice] = Field(..., min_length=1, max_length=3)


class GenerateResponse(BaseModel):
    request_id: str
    plan: str
    daily: DailyInfo
    candidates: list[Candidate]
    followup: Followup | None = None  # 不足1点があれば返す
    model_hint: str | None = None
    timestamp: str | None = None
    meta_pro: dict | None = None


class MigrationStartResponse(BaseModel):
    migration_code: str
    ticket_id: str


class MigrationCompleteRequest(BaseModel):
    migration_code: str


class MigrationCompleteResponse(BaseModel):
    user_id: str
    access_token: str


class BillingVerifyRequest(BaseModel):
    platform: Literal["android", "ios"]
    product_id: str = Field(..., min_length=1, max_length=128)
    purchase_token: str = Field(..., max_length=4096)


class BillingVerifyResponse(BaseModel):
    plan: Literal["free", "pro", "premium"]
    verified: bool


class PremiumCompGrantRequestRequest(BaseModel):
    email: str = Field(..., min_length=3, max_length=320)


class PremiumCompGrantRequestResponse(BaseModel):
    approved: bool
    request_count: int = Field(..., ge=0)
    remaining_attempts: int | None = None  # 失敗時: ロックまでの残り回数、承認時: None


# Telemetry Schemas（本文ゼロ厳守）
class TelemetryEventBase(BaseModel):
    """クライアントから送信される共通フィールド"""
    event_name: Literal[
        "generate_requested",
        "generate_succeeded", 
        "generate_failed",
        "candidate_copied",
        "app_opened"
    ]
    app_version: str
    os: Literal["android", "ios"]
    device_class: Literal["phone", "tablet", "unknown"] = "unknown"


class GenerateRequestedEvent(TelemetryEventBase):
    event_name: Literal["generate_requested"] = "generate_requested"
    daily_used: int
    daily_remaining: int
    has_ng_setting: bool
    persona_version: int


class GenerateSucceededEvent(TelemetryEventBase):
    event_name: Literal["generate_succeeded"] = "generate_succeeded"
    latency_ms: int
    ng_gate_triggered: bool
    followup_returned: bool


class GenerateFailedEvent(TelemetryEventBase):
    event_name: Literal["generate_failed"] = "generate_failed"
    latency_ms: int | None = None
    error_code: str  # 本文なし、コードのみ


class CandidateCopiedEvent(TelemetryEventBase):
    event_name: Literal["candidate_copied"] = "candidate_copied"
    candidate_id: Literal["A", "B", "C"]


class AppOpenedEvent(TelemetryEventBase):
    event_name: Literal["app_opened"] = "app_opened"


class TelemetryEventRequest(BaseModel):
    """POST /api/v1/telemetry/events のリクエスト"""
    events: list[
        GenerateRequestedEvent |
        GenerateSucceededEvent |
        GenerateFailedEvent |
        CandidateCopiedEvent |
        AppOpenedEvent
    ] = Field(..., min_length=1, max_length=100)


class TelemetryEventResponse(BaseModel):
    """POST /api/v1/telemetry/events のレスポンス"""
    received: int
    request_id: str | None = None


CustomerAgeRange = Literal["unknown", "20s_early", "20s_late", "30s", "40s", "50s_or_more"]
CustomerRelationshipStage = Literal["new", "regular", "important", "caution", "inactive"]
CustomerVisitFrequencyTag = Literal["unknown", "weekly", "biweekly", "monthly", "rare"]
CustomerDrinkStyleTag = Literal["unknown", "light", "normal", "heavy", "gets_drunk_fast"]
CustomerTagCategory = Literal[
    "personality",
    "topic",
    "ng",
    "lifestyle",
    "relationship",
    "sales_hint",
    "event",
]
CustomerVisitType = Literal["store", "douhan", "after", "other"]
CustomerSpendLevel = Literal["unknown", "low", "middle", "high", "very_high"]
CustomerDrinkAmountTag = Literal["light", "normal", "heavy"]
CustomerMoodTag = Literal["good", "normal", "bad", "unstable"]
CustomerEventType = Literal["birthday", "first_visit_anniversary", "last_visit_reminder", "special_day", "custom"]
CustomerReminderType = Literal["event", "contact_gap", "visit_gap"]


class CustomerBase(BaseModel):
    display_name: str = Field(..., min_length=1, max_length=80)
    nickname: str | None = Field(default=None, max_length=80)
    call_name: str | None = Field(default=None, max_length=80)
    area_tag: str | None = Field(default=None, max_length=64)
    age_range: CustomerAgeRange | None = None
    job_tag: str | None = Field(default=None, max_length=64)
    relationship_stage: CustomerRelationshipStage = "new"
    visit_frequency_tag: CustomerVisitFrequencyTag | None = None
    drink_style_tag: CustomerDrinkStyleTag | None = None
    last_visit_at: str | None = None
    last_contact_at: str | None = None
    memo_summary: str | None = Field(default=None, max_length=120)
    is_archived: bool = False


class CustomerCreateRequest(CustomerBase):
    pass


class CustomerUpdateRequest(BaseModel):
    display_name: str | None = Field(default=None, min_length=1, max_length=80)
    nickname: str | None = Field(default=None, max_length=80)
    call_name: str | None = Field(default=None, max_length=80)
    area_tag: str | None = Field(default=None, max_length=64)
    age_range: CustomerAgeRange | None = None
    job_tag: str | None = Field(default=None, max_length=64)
    relationship_stage: CustomerRelationshipStage | None = None
    visit_frequency_tag: CustomerVisitFrequencyTag | None = None
    drink_style_tag: CustomerDrinkStyleTag | None = None
    last_visit_at: str | None = None
    last_contact_at: str | None = None
    memo_summary: str | None = Field(default=None, max_length=120)
    is_archived: bool | None = None


class CustomerResponse(CustomerBase):
    customer_id: str
    created_at: str
    updated_at: str


class CustomerTagItem(BaseModel):
    category: CustomerTagCategory
    value: str = Field(..., min_length=1, max_length=64)


class CustomerTagReplaceRequest(BaseModel):
    tags: list[CustomerTagItem] = Field(default_factory=list, max_length=64)


class CustomerTagResponse(BaseModel):
    tag_id: str
    category: CustomerTagCategory
    value: str


class CustomerVisitLogCreateRequest(BaseModel):
    visited_on: str
    visit_type: CustomerVisitType
    stay_minutes: int | None = Field(default=None, ge=0, le=1440)
    spend_level: CustomerSpendLevel | None = None
    drink_amount_tag: CustomerDrinkAmountTag | None = None
    mood_tag: CustomerMoodTag | None = None
    memo_short: str | None = Field(default=None, max_length=80)


class CustomerVisitLogResponse(BaseModel):
    visit_log_id: str
    customer_id: str
    visited_on: str
    visit_type: CustomerVisitType
    stay_minutes: int | None
    spend_level: CustomerSpendLevel | None
    drink_amount_tag: CustomerDrinkAmountTag | None
    mood_tag: CustomerMoodTag | None
    memo_short: str | None
    created_at: str


class CustomerEventCreateRequest(BaseModel):
    event_type: CustomerEventType
    event_date: str
    title: str = Field(..., min_length=1, max_length=80)
    note: str | None = Field(default=None, max_length=80)
    remind_days_before: int = Field(default=0, ge=0, le=365)
    is_active: bool = True


class CustomerEventReminderUpdateRequest(BaseModel):
    remind_days_before: int = Field(..., ge=0, le=365)


class CustomerEventResponse(BaseModel):
    event_id: str
    customer_id: str
    event_type: CustomerEventType
    event_date: str
    title: str
    note: str | None
    remind_days_before: int
    is_active: bool
    created_at: str


class CustomerReminderCustomer(BaseModel):
    customer_id: str
    display_name: str
    relationship_stage: CustomerRelationshipStage


class CustomerReminderResponse(BaseModel):
    reminder_id: str
    reminder_type: CustomerReminderType
    title: str
    due_date: str
    days_delta: int
    customer: CustomerReminderCustomer


class CustomerDetailResponse(BaseModel):
    customer: CustomerResponse
    tags: list[CustomerTagResponse]
    visit_logs: list[CustomerVisitLogResponse]
    events: list[CustomerEventResponse]
