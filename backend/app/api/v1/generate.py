from __future__ import annotations

import datetime as dt
from fastapi import APIRouter, Depends, Header, Request, HTTPException
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
from app.settings_defaults import with_default_settings
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


def _normalize_generate_settings_by_plan(settings: dict, plan: str) -> dict:
    if plan == "pro":
        return settings

    normalized = dict(settings)
    normalized["reply_length_pref"] = "short"
    normalized["line_break_pref"] = "few"
    normalized["emoji_amount_pref"] = "none"
    normalized["reaction_level_pref"] = "low"
    normalized["partner_name_usage_pref"] = "none"
    return normalized

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
    settings = with_default_settings(st.settings_json if st else {})
    settings_for_generate = _normalize_generate_settings_by_plan(settings, auth.plan)

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
            true_self_type=settings_for_generate.get("true_self_type"),
            night_self_type=settings_for_generate.get("night_self_type"),
            persona_goal_primary=settings_for_generate.get("persona_goal_primary"),
            persona_goal_secondary=settings_for_generate.get("persona_goal_secondary"),
            style_assertiveness=int(settings_for_generate.get("style_assertiveness", 0)) if settings_for_generate.get("style_assertiveness") is not None else None,
            style_warmth=int(settings_for_generate.get("style_warmth", 0)) if settings_for_generate.get("style_warmth") is not None else None,
            style_risk_guard=int(settings_for_generate.get("style_risk_guard", 0)) if settings_for_generate.get("style_risk_guard") is not None else None,
            relationship_type=settings_for_generate.get("relationship_type"),
            reply_length_pref=settings_for_generate.get("reply_length_pref"),
            line_break_pref=settings_for_generate.get("line_break_pref"),
            emoji_amount_pref=settings_for_generate.get("emoji_amount_pref"),
            reaction_level_pref=settings_for_generate.get("reaction_level_pref"),
            partner_name_usage_pref=settings_for_generate.get("partner_name_usage_pref"),
            combo_id=req.combo_id,
            ng_tags=_to_list(settings_for_generate.get("ng_tags")),
            ng_free_phrases=_to_list(settings_for_generate.get("ng_free_phrases")),
            tuning=req.tuning,
            my_line_name=req.my_line_name,
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
    except HTTPException:
        # AIクライアントが投げた業務エラーコード（AI_UPSTREAM_ERROR等）はそのまま返す。
        raise
    except Exception as e:
        raise err(
            "INTERNAL_ERROR",
            "AI応答生成中にエラーが発生しました",
            {"request_id": rid, "type": e.__class__.__name__},
            status_code=500,
        )
