from __future__ import annotations

import datetime as dt
import re

from fastapi import APIRouter, Depends, Header
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import get_db
from app.errors import err
from app.models import PlanStatus, PremiumCompGrantRequest, User, UserSettings
from app.schemas import PremiumCompGrantRequestRequest, PremiumCompGrantRequestResponse
from app.security import AuthContext, get_auth_context
from app.settings_defaults import with_default_settings
from app.utils import etag_for_json, sha256_hex

router = APIRouter()

_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
_MAX_FAILURES = 5  # この回数失敗でアカウントロック


def _normalize_email(email: str) -> str:
    return email.strip().lower()


def _session_id_from_authorization(authorization: str | None) -> str | None:
    if not authorization:
        return None
    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        return None
    token = parts[1].strip()
    if not token:
        return None
    return sha256_hex(token)


@router.post("/premium-comp/request", response_model=PremiumCompGrantRequestResponse)
async def request_premium_comp(
    req: PremiumCompGrantRequestRequest,
    db: AsyncSession = Depends(get_db),
    auth: AuthContext = Depends(get_auth_context),
    authorization: str | None = Header(default=None),
):
    email = _normalize_email(req.email)
    if not _EMAIL_RE.match(email):
        raise err("VALIDATION_FAILED", "メールアドレスの形式が不正です", status_code=422)

    # ユーザーを先に取得してロック確認
    user_row = await db.execute(select(User).where(User.user_id == auth.user_id))
    user = user_row.scalar_one_or_none()
    if not user:
        raise err("AUTH_INVALID", "認証が無効です", status_code=401)

    if user.is_locked:
        raise err("ACCOUNT_LOCKED", "このアカウントはロックされています", status_code=403)

    async def _record_failure(code: str, message: str, status: int) -> None:
        """失敗をカウントし、上限到達でアカウントロック。その後例外を送出する。"""
        new_count = int(user.failed_premium_comp_attempts or 0) + 1
        user.failed_premium_comp_attempts = new_count
        user.updated_at = dt.datetime.now(dt.timezone.utc)
        if new_count >= _MAX_FAILURES:
            user.is_locked = True
        await db.commit()
        remaining = max(0, _MAX_FAILURES - new_count)
        raise err(code, message, detail={"remaining_attempts": remaining}, status_code=status)

    row = await db.execute(
        select(PremiumCompGrantRequest).where(PremiumCompGrantRequest.email == email)
    )
    target = row.scalar_one_or_none()
    if not target:
        await _record_failure("PREMIUM_COMP_EMAIL_NOT_ALLOWED", "対象外のメールアドレスです", 403)

    current_count = int(target.request_count or 0)
    next_count = current_count + 1
    target.request_count = next_count
    target.last_session_id = _session_id_from_authorization(authorization)
    target.updated_at = dt.datetime.now(dt.timezone.utc)

    if target.approved_user_id:
        await _record_failure("PREMIUM_COMP_EMAIL_ALREADY_APPROVED", "このメールアドレスは既に承認済みです", 409)

    if current_count != 0:
        await _record_failure("PREMIUM_COMP_REQUEST_ALREADY_USED", "このメールアドレスの承認依頼は既に記録されています", 409)

    user.feature_tier = "premium"
    user.billing_tier = "premium_comp"

    plan_row = await db.execute(
        select(PlanStatus).where(PlanStatus.user_id == auth.user_id)
    )
    plan = plan_row.scalar_one_or_none()
    if plan:
        plan.plan = "premium"
        plan.updated_at = dt.datetime.now(dt.timezone.utc)
    else:
        db.add(PlanStatus(user_id=auth.user_id, plan="premium"))

    settings_row = await db.execute(
        select(UserSettings).where(UserSettings.user_id == auth.user_id)
    )
    user_settings = settings_row.scalar_one_or_none()
    settings_json = with_default_settings(
        dict(user_settings.settings_json) if user_settings else {}
    )
    settings_json["feature_tier"] = "premium"
    settings_json["billing_tier"] = "premium_comp"
    settings_json["plan"] = "premium"
    settings_json["status_tier"] = "special"
    new_etag = etag_for_json(settings_json)
    if user_settings:
        user_settings.settings_json = settings_json
        user_settings.etag = new_etag
        user_settings.settings_schema_version = int(
            settings_json.get("settings_schema_version") or 1
        )
        user_settings.updated_at = dt.datetime.now(dt.timezone.utc)
    else:
        db.add(
            UserSettings(
                user_id=auth.user_id,
                settings_json=settings_json,
                settings_schema_version=1,
                etag=new_etag,
            )
        )

    target.approved_user_id = auth.user_id

    await db.commit()

    return PremiumCompGrantRequestResponse(approved=True, request_count=next_count, remaining_attempts=None)
