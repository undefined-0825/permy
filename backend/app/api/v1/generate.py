from __future__ import annotations

import datetime as dt
from fastapi import APIRouter, Depends, Header, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db import get_db
from app.schemas import GenerateRequest, GenerateResponse, Candidate, DailyInfo
from app.security import get_auth_context, AuthContext
from app.config import settings as config_settings
from app.ratelimit import fixed_window_limit
from app.errors import err
from app.safety_gate import check as safety_check
from app.ai_client import get_ai_client, GenerateContext
from app.models import UserSettings
from app.services.usage import get_or_create_usage
from app.services.idempotency import acquire
from app.utils_time import jst_today_ymd
from app.followup_helper import check_missing_setting

router = APIRouter()

def _daily_limit(plan: str) -> int:
    return config_settings.pro_generate_daily_limit if plan == "pro" else config_settings.free_generate_daily_limit

def _to_list(v) -> list[str]:
    if v is None:
        return []
    if isinstance(v, list):
        return [str(x) for x in v]
    return [str(v)]

def _blocked_candidates(reason: str) -> list[str]:
    a = (
        "ごめんね、その内容はこのアプリでは手伝えないよ。"
        "でも、伝え方や別の言い回しなら一緒に考えられるから、"
        "目的だけ教えてくれたら安全な形で作るね。"
    )
    b = "ごめん、その内容は対応できない…！目的だけ教えてくれたら、言い方を変えて一緒に考えるよ。"
    c = "無理のない範囲で大丈夫。今いちばん困ってるポイントだけ、短く教えて？そこから整えるね。"
    return [a, b, c]

@router.post("/generate", response_model=GenerateResponse)
async def generate(
    req: GenerateRequest,
    request: Request,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    db: AsyncSession = Depends(get_db),
    auth: AuthContext = Depends(get_auth_context),
):
    rid = getattr(request.state, "request_id", None) or ""

    if len(req.history_text) > config_settings.generate_max_chars:
        raise err("VALIDATION_FAILED", "入力が長すぎます", {"max_chars": config_settings.generate_max_chars}, status_code=422)

    if auth.plan != "pro" and req.combo_id not in (0, 1):
        raise err("PLAN_REQUIRED", "有料版のみ対応しています", {"combo_id": req.combo_id}, status_code=403)

    await fixed_window_limit(
        f"rl:generate:user:{auth.user_id}:1m",
        config_settings.rl_generate_minute_limit,
        config_settings.rl_generate_minute_window_seconds,
    )

    if idempotency_key:
        ok = await acquire(auth.user_id, idempotency_key)
        if not ok:
            raise err("RATE_LIMITED", "同じリクエストが処理中です", {"idempotency": "replay"}, status_code=429)

    usage = await get_or_create_usage(db, auth.user_id, auth.plan)
    limit = _daily_limit(auth.plan)
    used = int(usage.generate_count)
    if used >= limit:
        raise err("DAILY_LIMIT_REACHED", "本日の上限に達しました", {"limit": limit, "used": used}, status_code=429)

    # Settings取得（followup判定とNG判定に使用）
    row = await db.execute(select(UserSettings).where(UserSettings.user_id == auth.user_id))
    st = row.scalar_one_or_none()
    settings = st.settings_json if st else {}

    # Followup判定（設定不足チェック）
    followup = check_missing_setting(settings)

    why = safety_check(req.history_text)
    if why:
        texts = _blocked_candidates(why)
        daily = DailyInfo(date=jst_today_ymd(), limit=limit, used=used, remaining=max(0, limit - used))
        candidates = [
            Candidate(label="A", text=texts[0]),
            Candidate(label="B", text=texts[1]),
            Candidate(label="C", text=texts[2]),
        ]
        return GenerateResponse(
            request_id=rid,
            plan=auth.plan,
            daily=daily,
            candidates=candidates,
            followup=followup,  # NGゲートでブロックされてもfollowup返す
            model_hint="blocked",
            timestamp=dt.datetime.now(dt.timezone.utc).isoformat(),
            meta_pro=None,
        )

    try:
        ai_client = get_ai_client()
        ctx = GenerateContext(
            true_self_type=None,
            night_self_type=None,
            relationship_type=None,
            reply_length_pref=None,
            combo_id=req.combo_id,
            ng_tags=[],
            ng_free_phrases=[],
            tuning=None,
        )
        candidates = await ai_client.generate_abc(req.history_text, ctx)
        daily = DailyInfo(date=jst_today_ymd(), limit=limit, used=used, remaining=max(0, limit - used))
        return GenerateResponse(
            request_id=rid,
            plan=auth.plan,
            daily=daily,
            candidates=[
                Candidate(label="A", text=candidates[0] if len(candidates) > 0 else ""),
                Candidate(label="B", text=candidates[1] if len(candidates) > 1 else ""),
                Candidate(label="C", text=candidates[2] if len(candidates) > 2 else ""),
            ],
            followup=followup,  # 不足があればfollowupを返す
            model_hint=None,
            timestamp=dt.datetime.now(dt.timezone.utc).isoformat(),
            meta_pro=None,
        )
    except Exception as e:
        from fastapi.responses import JSONResponse
        import traceback
        return JSONResponse(
            status_code=500,
            content={
                "error": {
                    "code": "INTERNAL_ERROR",
                    "message": "AI応答生成中にエラーが発生しました",
                    "detail": {"exception": str(e), "trace": traceback.format_exc()}
                }
            }
        )
