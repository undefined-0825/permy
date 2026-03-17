from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.db import get_db
from app.errors import err
from app.models import User, PlanStatus
from app.schemas import BillingVerifyRequest, BillingVerifyResponse
from app.services.billing_verifier import (
    BillingVerifyInput,
    MockBillingVerifier,
)
from app.security import AuthContext, get_auth_context

router = APIRouter()

_ALLOWED_PRODUCT_IDS = {
    "android": {"permy_pro_monthly"},
}


@router.post("/billing/verify", response_model=BillingVerifyResponse)
async def billing_verify(
    req: BillingVerifyRequest,
    db: AsyncSession = Depends(get_db),
    auth: AuthContext = Depends(get_auth_context),
):
    """
    ストア購入の検証結果を反映する。

    注意:
    - 現時点は mock モードでのみ有効化。
    - 本番ではストアサーバ検証の実装に置き換える。
    """
    if settings.app_env.lower() == "prod":
        raise err("BILLING_NOT_CONFIGURED", "課金検証が未設定です", status_code=503)

    allowed = _ALLOWED_PRODUCT_IDS.get(req.platform, set())
    if req.product_id not in allowed:
        raise err("BILLING_PRODUCT_INVALID", "商品IDが不正です", status_code=400)

    if not req.purchase_token.strip():
        raise err("BILLING_RECEIPT_INVALID", "購入情報が不正です", status_code=400)

    verifier = MockBillingVerifier()
    result = await verifier.verify(
        BillingVerifyInput(
            platform=req.platform,
            product_id=req.product_id,
            purchase_token=req.purchase_token,
        )
    )
    if not result.verified:
        raise err("BILLING_RECEIPT_INVALID", "購入情報が不正です", status_code=400)

    row = await db.execute(select(User).where(User.user_id == auth.user_id))
    user = row.scalar_one_or_none()
    if not user:
        raise err("AUTH_INVALID", "認証が無効です", status_code=401)

    user.feature_tier = "plus"
    user.billing_tier = "pro_store"

    plan_row = await db.execute(select(PlanStatus).where(PlanStatus.user_id == auth.user_id))
    plan_status = plan_row.scalar_one_or_none()
    if plan_status:
        plan_status.plan = "pro"
    else:
        db.add(PlanStatus(user_id=auth.user_id, plan="pro"))

    await db.commit()

    return BillingVerifyResponse(plan="pro", verified=True)
