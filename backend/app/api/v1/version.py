from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.config import settings
from app.db import get_db
from app.models import AppReleaseNote

router = APIRouter()


@router.get("/version")
async def version(db: AsyncSession = Depends(get_db)):
    latest = settings.app_version

    # 最新バージョンのリリースノートを取得
    row = await db.scalar(
        select(AppReleaseNote).where(AppReleaseNote.version == latest)
    )
    release_note_title = row.title if row else ""
    release_note_body = row.body if row else ""

    return {
        "app": settings.app_name,
        "version": settings.app_version,
        "latest_version": latest,
        "min_supported_version": settings.app_min_supported_version,
        "android_store_url": settings.app_android_store_url,
        "ios_store_url": settings.app_ios_store_url,
        "release_note_title": release_note_title,
        "release_note_body": release_note_body,
        "commit": settings.commit_sha,
        "env": settings.app_env,
    }
