"""
register_comp_email.py - premium_comp対象メールの事前登録ツール

Usage:
    python tools/premium_comp/register_comp_email.py <email> <name>
    python tools/premium_comp/register_comp_email.py <email> <name> --force-reset

Examples:
    python tools/premium_comp/register_comp_email.py target@example.com 田中太郎
    python tools/premium_comp/register_comp_email.py target@example.com 田中太郎 --force-reset
"""

from __future__ import annotations

import asyncio
import datetime as dt
import re
import sys

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

sys.path.insert(0, ".")

from app.config import settings
from app.models import PremiumCompGrantRequest

_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def _normalize_email(email: str) -> str:
    return email.strip().lower()


async def register_email(email: str, name: str, force_reset: bool) -> None:
    normalized_email = _normalize_email(email)
    if not _EMAIL_RE.match(normalized_email):
        print(f"[ERROR] Invalid email format: {email}")
        return

    if not name.strip():
        print("[ERROR] Name is required")
        return

    engine = create_async_engine(settings.database_url, echo=False)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as db:
        row = await db.execute(
            select(PremiumCompGrantRequest).where(PremiumCompGrantRequest.email == normalized_email)
        )
        target = row.scalar_one_or_none()

        if target:
            target.name = name.strip()
            target.updated_at = dt.datetime.now(dt.timezone.utc)
            if force_reset:
                target.request_count = 0
                target.approved_user_id = None
                target.last_session_id = None
            await db.commit()
            print(f"[OK] Updated: {normalized_email}")
            print(
                f"  name={target.name}, request_count={target.request_count}, approved_user_id={target.approved_user_id}"
            )
            return

        db.add(
            PremiumCompGrantRequest(
                email=normalized_email,
                name=name.strip(),
                request_count=0,
            )
        )
        await db.commit()

    print(f"[OK] Registered: {normalized_email}")
    print(f"  name={name.strip()}, request_count=0")


def main() -> None:
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)

    email = sys.argv[1]
    name = sys.argv[2]
    force_reset = "--force-reset" in sys.argv[3:]
    asyncio.run(register_email(email, name, force_reset))


if __name__ == "__main__":
    main()
