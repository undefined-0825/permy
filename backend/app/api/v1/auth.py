from __future__ import annotations

from fastapi import APIRouter, Request, Header, Depends
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.db import get_db
from app.models import User, UserSettings, PlanStatus, UsageDaily
from app.schemas import AuthAnonymousResponse
from app.security import create_session, get_auth_context, AuthContext, invalidate_all_sessions
from app.ratelimit import fixed_window_limit
from app.settings_defaults import with_default_settings
from app.utils import etag_for_json

router = APIRouter()

def _client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"

@router.post("/auth/anonymous", response_model=AuthAnonymousResponse)
async def auth_anonymous(
    request: Request,
    db: AsyncSession = Depends(get_db),
    device_fingerprint: str | None = Header(default=None, alias="X-Device-Fingerprint"),
):
    ip = _client_ip(request)
    # TODO: 開発中は一時的にレート制限を無効化
    # await fixed_window_limit(f"rl:auth:ip:{ip}:10m", settings.rl_auth_ip_limit, settings.rl_auth_ip_window_seconds)
    # if device_fingerprint:
    #     await fixed_window_limit(f"rl:auth:df:{device_fingerprint}:10m", settings.rl_auth_df_limit, settings.rl_auth_df_window_seconds)

    user = User()
    db.add(user)
    await db.flush()

    # feature_tier/billing_tier初期化（SSOT）
    # beta_all_pro=True のテスト期間中は全員Proで作成する
    if settings.beta_all_pro:
        user.feature_tier = "pro"
        user.billing_tier = "pro_store"
    else:
        user.feature_tier = "free"
        user.billing_tier = "free"

    # plan_status（後方互換のため残す）
    db.add(PlanStatus(user_id=user.user_id, plan="pro" if settings.beta_all_pro else "free"))

    # 初期settings（未知フィールド許容のため JSONそのまま）
    initial = with_default_settings({})
    etag = etag_for_json(initial)
    db.add(UserSettings(user_id=user.user_id, settings_json=initial, settings_schema_version=1, etag=etag))

    await db.commit()

    token = await create_session(user.user_id)
    return AuthAnonymousResponse(user_id=user.user_id, access_token=token)


@router.delete("/auth/me", status_code=204)
async def delete_account(
    auth: AuthContext = Depends(get_auth_context),
    db: AsyncSession = Depends(get_db),
):
    """
    アカウント削除（取り消し不可）
    - ユーザーデータ（settings含む）を削除
    - 日次カウントを削除
    - セッションを無効化
    """
    user_id = auth.user_id

    # 関連データを削除
    await db.execute(delete(UserSettings).where(UserSettings.user_id == user_id))
    await db.execute(delete(PlanStatus).where(PlanStatus.user_id == user_id))
    await db.execute(delete(UsageDaily).where(UsageDaily.user_id == user_id))
    await db.execute(delete(User).where(User.user_id == user_id))

    await db.commit()

    # セッションを無効化
    await invalidate_all_sessions(user_id)

    return None  # 204 No Content
