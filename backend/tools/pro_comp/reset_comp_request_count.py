"""
reset_comp_request_count.py - pro_comp申請回数の管理者リセットツール

Usage:
    python tools/pro_comp/reset_comp_request_count.py <email>

Example:
    python tools/pro_comp/reset_comp_request_count.py target@example.com
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
from app.models import ProCompGrantRequest

_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def _normalize_email(email: str) -> str:
    return email.strip().lower()


async def reset_count(email: str) -> None:
    normalized_email = _normalize_email(email)
    if not _EMAIL_RE.match(normalized_email):
        print(f"[ERROR] Invalid email format: {email}")
        return

    engine = create_async_engine(settings.database_url, echo=False)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as db:
        row = await db.execute(
            select(ProCompGrantRequest).where(ProCompGrantRequest.email == normalized_email)
        )
        target = row.scalar_one_or_none()

        if not target:
            print(f"[ERROR] Email not found: {normalized_email}")
            return

        target.request_count = 0
        target.updated_at = dt.datetime.now(dt.timezone.utc)
        await db.commit()

        print(f"[OK] Reset request_count: {normalized_email}")
        print(
            f"  request_count={target.request_count}, approved_user_id={target.approved_user_id}"
        )


def main() -> None:
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    asyncio.run(reset_count(sys.argv[1]))


if __name__ == "__main__":
    main()
