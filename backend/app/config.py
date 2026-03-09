from __future__ import annotations

from typing import Any

from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import field_validator


def normalize_database_url(database_url: str) -> str:
    """Normalize DATABASE_URL for SQLAlchemy usage.

    Render commonly provides `postgresql://...` or `postgres://...`.
    Use psycopg driver explicitly to avoid fallback to psycopg2.
    """
    if database_url.startswith("postgres://"):
        database_url = database_url.replace("postgres://", "postgresql://", 1)
    if database_url.startswith("postgresql://"):
        return database_url.replace("postgresql://", "postgresql+psycopg://", 1)
    return database_url


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = "permy-serverside"
    app_env: str = "dev"
    app_version: str = "0.1.0"
    app_min_supported_version: str = "0.1.0"
    commit_sha: str = "dev"
    app_android_store_url: str = ""
    app_ios_store_url: str = ""

    session_ttl_seconds: int = 30 * 24 * 3600

    migration_code_ttl_seconds: int = 10 * 60
    migration_ticket_ttl_seconds: int = 15 * 60
    migration_lock_ttl_seconds: int = 60 * 60
    idempotency_ttl_seconds: int = 24 * 3600

    # Telemetry
    telemetry_hash_secret: str = "changeme_telemetry_hash_secret"

    generate_max_chars: int = 20000

    rl_auth_ip_limit: int = 100  # 開発中は制限緩和
    rl_auth_ip_window_seconds: int = 600
    rl_auth_df_limit: int = 30  # 開発中は制限緩和
    rl_auth_df_window_seconds: int = 600

    rl_generate_minute_limit: int = 5
    rl_generate_minute_window_seconds: int = 60

    rl_mig_start_user_limit: int = 3
    rl_mig_start_user_window_seconds: int = 86400
    rl_mig_start_ip_limit: int = 10
    rl_mig_start_ip_window_seconds: int = 86400

    rl_mig_complete_ip_limit: int = 5
    rl_mig_complete_ip_window_seconds: int = 60
    mig_complete_max_tries: int = 10

    free_generate_daily_limit: int = 3
    pro_generate_daily_limit: int = 100


    # AI
    ai_provider: str = "dummy"  # dummy/openai
    openai_api_key: str | None = None
    openai_model: str = "gpt-5.2"
    openai_instructions: str = (
        "あなたは夜職ユーザー向けのLINE返信案を作るアシスタント。"
        "必ずA/B/Cの3案を作り、過度に短文にしない。断定しない。"
        "ユーザーが最終決定する前提で提案する。"
        "NGワードやNG表現が指定されていれば絶対に含めない。"
    )

    database_url: str = "sqlite+aiosqlite:///./permy.db"
    redis_url: str = "redis://localhost:6379/0"

    uvicorn_access_log: bool = False

    @field_validator("database_url", mode="before")
    @classmethod
    def _normalize_database_url(cls, value: Any) -> Any:
        if isinstance(value, str):
            return normalize_database_url(value)
        return value


settings = Settings()
