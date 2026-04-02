from __future__ import annotations

from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy import inspect, text
from sqlalchemy.orm import DeclarativeBase

from app.config import settings, normalize_database_url


class Base(DeclarativeBase):
    pass

engine = create_async_engine(
    normalize_database_url(settings.database_url),
    echo=False,
    future=True,
)
SessionLocal = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)


def _ensure_backward_compatible_columns(sync_conn) -> None:
    inspector = inspect(sync_conn)
    tables = set(inspector.get_table_names())
    if "users" not in tables:
        return

    existing = {col["name"] for col in inspector.get_columns("users")}
    alter_statements: list[str] = []

    if "feature_tier" not in existing:
        alter_statements.append(
            "ALTER TABLE users ADD COLUMN feature_tier VARCHAR(16) NOT NULL DEFAULT 'free'"
        )
    if "billing_tier" not in existing:
        alter_statements.append(
            "ALTER TABLE users ADD COLUMN billing_tier VARCHAR(16) NOT NULL DEFAULT 'free'"
        )
    if "failed_premium_comp_attempts" not in existing:
        alter_statements.append(
            "ALTER TABLE users ADD COLUMN failed_premium_comp_attempts INTEGER NOT NULL DEFAULT 0"
        )
    if "is_locked" not in existing:
        alter_statements.append(
            "ALTER TABLE users ADD COLUMN is_locked BOOLEAN NOT NULL DEFAULT false"
        )

    for stmt in alter_statements:
        sync_conn.execute(text(stmt))

async def ensure_schema() -> None:
    """起動時に必要なテーブルを作成する。"""
    # create_all 前にモデルを読み込み、metadata を登録する
    import app.models  # noqa: F401

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        await conn.run_sync(_ensure_backward_compatible_columns)


async def get_db() -> AsyncSession:
    async with SessionLocal() as session:
        yield session
