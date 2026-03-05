#!/usr/bin/env python3
"""
set_usage_count.py - Set daily usage count for testing
Usage: python set_usage_count.py <user_id> <count>
"""
import sys
import asyncio
from sqlalchemy import select, update

sys.path.insert(0, ".")

from app.db import get_db, SessionLocal
from app.models import UsageDaily
from app.utils_time import jst_today_ymd


async def set_usage_count(user_id: str, count: int):
    """Set the generate_count for a user for today."""
    today = jst_today_ymd()
    
    async with SessionLocal() as db:
        # Check if usage record exists
        result = await db.execute(
            select(UsageDaily).where(
                UsageDaily.user_id == user_id,
                UsageDaily.date == today
            )
        )
        usage = result.scalar_one_or_none()
        
        if usage:
            # Update existing record
            usage.generate_count = count
            print(f"✓ Updated usage for user {user_id[:8]}... on {today}: {count} generations")
        else:
            # Create new record
            usage = UsageDaily(
                user_id=user_id,
                date=today,
                generate_count=count,
                plan_at_time="free"
            )
            db.add(usage)
            print(f"✓ Created usage record for user {user_id[:8]}... on {today}: {count} generations")
        
        await db.commit()


async def get_usage_count(user_id: str):
    """Get the current usage count for a user."""
    today = jst_today_ymd()
    
    async with SessionLocal() as db:
        result = await db.execute(
            select(UsageDaily).where(
                UsageDaily.user_id == user_id,
                UsageDaily.date == today
            )
        )
        usage = result.scalar_one_or_none()
        
        if usage:
            print(f"Current usage for user {user_id[:8]}... on {today}: {usage.generate_count} generations")
            return usage.generate_count
        else:
            print(f"No usage record found for user {user_id[:8]}... on {today}")
            return 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage:")
        print("  Get usage:  python set_usage_count.py <user_id>")
        print("  Set usage:  python set_usage_count.py <user_id> <count>")
        sys.exit(1)
    
    user_id = sys.argv[1]
    
    if len(sys.argv) == 2:
        # Get usage
        asyncio.run(get_usage_count(user_id))
    else:
        # Set usage
        try:
            count = int(sys.argv[2])
            asyncio.run(set_usage_count(user_id, count))
        except ValueError:
            print(f"Error: count must be an integer, got '{sys.argv[2]}'")
            sys.exit(1)
