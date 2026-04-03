from __future__ import annotations

# 日次上限は運用確定値として固定する（環境変数では変更しない）
FREE_GENERATE_DAILY_LIMIT = 3
PRO_GENERATE_DAILY_LIMIT = 100
PREMIUM_GENERATE_DAILY_LIMIT = 200


def generate_daily_limit(plan: str) -> int:
    if plan == "premium":
        return PREMIUM_GENERATE_DAILY_LIMIT
    if plan == "pro":
        return PRO_GENERATE_DAILY_LIMIT
    return FREE_GENERATE_DAILY_LIMIT
