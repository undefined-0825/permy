from __future__ import annotations

from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
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


async def ensure_schema() -> None:
    """起動時に必要なテーブルを作成する。"""
    # create_all 前にモデルを読み込み、metadata を登録する
    import app.models  # noqa: F401

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


async def get_db() -> AsyncSession:
    async with SessionLocal() as session:
        yield session
