from __future__ import annotations

from pydantic import BaseModel, Field
from typing import Literal


class ErrorEnvelope(BaseModel):
    error: dict


class AuthAnonymousResponse(BaseModel):
    user_id: str
    access_token: str


class SettingsResponse(BaseModel):
    settings: dict


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
    key: Literal["relationship_type", "reply_length_pref", "ng_tags", "ng_free_phrases"]
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
    platform: Literal["ios", "android"]
    product_id: str = Field(..., min_length=1, max_length=128)
    purchase_token: str = Field(..., min_length=1, max_length=4096)


class BillingVerifyResponse(BaseModel):
    plan: Literal["free", "pro"]
    verified: bool


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
