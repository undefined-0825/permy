"""Initialize database tables."""
import asyncio
from app.db import engine, Base


async def init_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    print("[OK] Database tables created successfully")


if __name__ == "__main__":
    asyncio.run(init_db())
