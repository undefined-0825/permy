from __future__ import annotations

import datetime as dt
import uuid
from sqlalchemy import String, DateTime, JSON, Integer
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class User(Base):
    __tablename__ = "users"

    user_id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    feature_tier: Mapped[str] = mapped_column(String(16), default="free")  # free/pro
    billing_tier: Mapped[str] = mapped_column(String(16), default="free")  # free/pro_store/pro_comp
    failed_pro_comp_attempts: Mapped[int] = mapped_column(Integer, default=0)  # pro_comp申請失敗回数
    is_locked: Mapped[bool] = mapped_column(default=False)  # 不正アクセスロック
    created_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), default=lambda: dt.datetime.now(dt.timezone.utc))
    updated_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), default=lambda: dt.datetime.now(dt.timezone.utc))


class PlanStatus(Base):
    __tablename__ = "plan_status"

    user_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    plan: Mapped[str] = mapped_column(String(16), default="free")  # free/pro
    updated_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), default=lambda: dt.datetime.now(dt.timezone.utc))


class UserSettings(Base):
    __tablename__ = "user_settings"

    user_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    settings_json: Mapped[dict] = mapped_column(JSON, default=dict)
    settings_schema_version: Mapped[int] = mapped_column(Integer, default=1)
    etag: Mapped[str] = mapped_column(String(128))
    updated_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), default=lambda: dt.datetime.now(dt.timezone.utc))


class UsageDaily(Base):
    __tablename__ = "usage_daily"

    user_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    date: Mapped[str] = mapped_column(String(10), primary_key=True)  # YYYY-MM-DD (JST)
    generate_count: Mapped[int] = mapped_column(Integer, default=0)
    plan_at_time: Mapped[str] = mapped_column(String(16), default="free")


class AppReleaseNote(Base):
    """バージョンごとのリリースノート。/api/v1/version で返す。"""

    __tablename__ = "app_release_notes"

    version: Mapped[str] = mapped_column(String(32), primary_key=True)
    title: Mapped[str] = mapped_column(String(256), default="バージョンアップのお知らせ")
    body: Mapped[str] = mapped_column(String(4096), default="")
    released_at: Mapped[dt.datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: dt.datetime.now(dt.timezone.utc)
    )


class ProCompGrantRequest(Base):
    __tablename__ = "pro_comp_grant_requests"

    email: Mapped[str] = mapped_column(String(320), primary_key=True)
    name: Mapped[str] = mapped_column(String(128), default="")
    request_count: Mapped[int] = mapped_column(Integer, default=0)
    approved_user_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    last_session_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    created_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), default=lambda: dt.datetime.now(dt.timezone.utc))
    updated_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), default=lambda: dt.datetime.now(dt.timezone.utc))


class TelemetryEvent(Base):
    __tablename__ = "telemetry_events"

    event_id: Mapped[str] = mapped_column(String(64), primary_key=True)
    event_name: Mapped[str] = mapped_column(String(64))
    server_time_utc: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True))
    hour_bucket_utc: Mapped[int] = mapped_column(Integer)  # 0..23
    dow_utc: Mapped[int] = mapped_column(Integer)  # 0..6, 月曜=0
    user_id_hash: Mapped[str] = mapped_column(String(128))
    plan: Mapped[str] = mapped_column(String(16))
    app_version: Mapped[str] = mapped_column(String(32))
    os: Mapped[str] = mapped_column(String(16))
    device_class: Mapped[str] = mapped_column(String(16))
    event_data: Mapped[dict] = mapped_column(JSON, default=dict)  # イベント固有フィールド
    created_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), default=lambda: dt.datetime.now(dt.timezone.utc))
