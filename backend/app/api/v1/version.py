from __future__ import annotations

from fastapi import APIRouter
from app.config import settings

router = APIRouter()

@router.get("/version")
async def version():
    return {
        "app": settings.app_name,
        "version": settings.app_version,
        "latest_version": settings.app_version,
        "min_supported_version": settings.app_min_supported_version,
        "android_store_url": settings.app_android_store_url,
        "ios_store_url": settings.app_ios_store_url,
        "commit": settings.commit_sha,
        "env": settings.app_env,
    }
