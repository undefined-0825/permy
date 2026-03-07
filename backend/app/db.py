from __future__ import annotations

from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import DeclarativeBase

from app.config import settings


class Base(DeclarativeBase):
    pass


def normalize_database_url(database_url: str) -> str:
    """Normalize DATABASE_URL for SQLAlchemy async engine.

    Render's Postgres connection string is usually `postgresql://...`.
    SQLAlchemy async engine requires an explicit async-capable driver.
    """
    if database_url.startswith("postgres://"):
        database_url = database_url.replace("postgres://", "postgresql://", 1)
    if database_url.startswith("postgresql://"):
        return database_url.replace("postgresql://", "postgresql+psycopg://", 1)
    return database_url


engine = create_async_engine(
    normalize_database_url(settings.database_url),
    echo=False,
    future=True,
)
SessionLocal = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)


async def get_db() -> AsyncSession:
    async with SessionLocal() as session:
        yield session
