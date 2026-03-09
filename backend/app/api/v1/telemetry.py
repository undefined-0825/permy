from __future__ import annotations

import datetime as dt
import uuid
from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import get_db
from app.schemas import TelemetryEventRequest, TelemetryEventResponse
from app.security import get_auth_context, AuthContext
from app.models import TelemetryEvent
from app.utils import user_id_hash
from app.config import settings

router = APIRouter()


@router.post("/telemetry/events", response_model=TelemetryEventResponse)
async def post_telemetry_events(
    req: TelemetryEventRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
    auth: AuthContext = Depends(get_auth_context),
):
    """
    Telemetryイベントを受信して保存（本文ゼロ厳守）
    
    - サーバでserver_time_utc, hour_bucket_utc, dow_utc, user_id_hashを付与
    - 会話本文/生成本文は絶対に含めない
    - event_data には各イベント固有のフィールドをJSON保存
    """
    request_id = getattr(request.state, "request_id", None) or str(uuid.uuid4())
    now_utc = dt.datetime.now(dt.timezone.utc)
    hour_bucket = now_utc.hour  # 0..23
    dow = now_utc.weekday()  # 月曜=0, 日曜=6
    
    # user_id_hash生成（HMAC-SHA256でハッシュ化）
    hashed_user_id = user_id_hash(auth.user_id, settings.telemetry_hash_secret)
    
    saved_count = 0
    for event in req.events:
        event_id = str(uuid.uuid4())
        
        # イベント固有データを抽出（event_nameは共通フィールドなので除外）
        event_data = event.model_dump(exclude={"event_name", "app_version", "os", "device_class"})
        
        telemetry_event = TelemetryEvent(
            event_id=event_id,
            event_name=event.event_name,
            server_time_utc=now_utc,
            hour_bucket_utc=hour_bucket,
            dow_utc=dow,
            user_id_hash=hashed_user_id,
            plan=auth.plan,
            app_version=event.app_version,
            os=event.os,
            device_class=event.device_class,
            event_data=event_data,
        )
        db.add(telemetry_event)
        saved_count += 1
    
    await db.commit()
    
    return TelemetryEventResponse(received=saved_count, request_id=request_id)
