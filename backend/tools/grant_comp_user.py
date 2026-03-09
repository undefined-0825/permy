"""
grant_comp_user.py - 永続無料Pro（pro_comp）付与ツール

Usage:
    python grant_comp_user.py <user_id>              # pro_compに昇格
    python grant_comp_user.py <user_id> --revoke     # freeにダウングレード

Examples:
    python grant_comp_user.py abc12345-6789-...       # pro_comp付与
    python grant_comp_user.py abc12345-6789-... --revoke  # free復帰
"""

from __future__ import annotations

import sys
import asyncio
from sqlalchemy import select
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

# プロジェクトルートをパスに追加（backendディレクトリから実行想定）
sys.path.insert(0, ".")

from app.models import User
from app.config import settings


async def grant_comp(user_id: str) -> None:
    """指定user_idにpro_compを付与"""
    engine = create_async_engine(settings.database_url, echo=False)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as db:
        row = await db.execute(select(User).where(User.user_id == user_id))
        user = row.scalar_one_or_none()

        if not user:
            print(f"[ERROR] User not found: {user_id}")
            return

        # 現在のtier表示
        current_ft = getattr(user, "feature_tier", None) or "free"
        current_bt = getattr(user, "billing_tier", None) or "free"
        print(f"Current: feature_tier={current_ft}, billing_tier={current_bt}")

        # pro_comp付与
        user.feature_tier = "plus"
        user.billing_tier = "pro_comp"
        await db.commit()

        print(f"[OK] Granted pro_comp to user {user_id[:8]}...")
        print(f"  -> feature_tier=plus, billing_tier=pro_comp")


async def revoke_comp(user_id: str) -> None:
    """指定user_idからpro_compを剥奪（freeに戻す）"""
    engine = create_async_engine(settings.database_url, echo=False)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as db:
        row = await db.execute(select(User).where(User.user_id == user_id))
        user = row.scalar_one_or_none()

        if not user:
            print(f"[ERROR] User not found: {user_id}")
            return

        # 現在のtier表示
        current_ft = getattr(user, "feature_tier", None) or "free"
        current_bt = getattr(user, "billing_tier", None) or "free"
        print(f"Current: feature_tier={current_ft}, billing_tier={current_bt}")

        # free復帰
        user.feature_tier = "free"
        user.billing_tier = "free"
        await db.commit()

        print(f"[OK] Revoked pro_comp from user {user_id[:8]}...")
        print(f"  -> feature_tier=free, billing_tier=free")


async def show_status(user_id: str) -> None:
    """指定user_idの現在のtierを表示"""
    engine = create_async_engine(settings.database_url, echo=False)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as db:
        row = await db.execute(select(User).where(User.user_id == user_id))
        user = row.scalar_one_or_none()

        if not user:
            print(f"[ERROR] User not found: {user_id}")
            return

        feature_tier = getattr(user, "feature_tier", None) or "free"
        billing_tier = getattr(user, "billing_tier", None) or "free"
        print(f"\nUser: {user_id}")
        print(f"  feature_tier: {feature_tier}")
        print(f"  billing_tier: {billing_tier}")
        print(f"  -> external plan: {'pro' if feature_tier == 'plus' else 'free'}")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    user_id = sys.argv[1]

    if len(sys.argv) == 2:
        # grant mode
        asyncio.run(grant_comp(user_id))
    elif sys.argv[2] == "--revoke":
        asyncio.run(revoke_comp(user_id))
    elif sys.argv[2] == "--status":
        asyncio.run(show_status(user_id))
    else:
        print("Unknown option. Use: grant_comp_user.py <user_id> [--revoke|--status]")
        sys.exit(1)


if __name__ == "__main__":
    main()
