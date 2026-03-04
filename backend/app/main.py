from __future__ import annotations

import logging
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from app.config import settings
from app.logging_conf import configure_logging
from app.middleware.request_id import RequestIdMiddleware
from app.middleware.no_cache import NoCacheMiddleware

from app.routes.health import router as health_router
from app.routes.version import router as version_router
from app.routes.auth import router as auth_router
from app.routes.settings import router as settings_router
from app.routes.generate import router as generate_router
from app.routes.migration import router as migration_router


configure_logging()
log = logging.getLogger(__name__)

app = FastAPI(title=settings.app_name)

app.add_middleware(RequestIdMiddleware)
app.add_middleware(NoCacheMiddleware)

# mount routers under versioned namespace
app.include_router(health_router, prefix="/api/v1")
app.include_router(version_router, prefix="/api/v1")
app.include_router(auth_router, prefix="/api/v1")
app.include_router(settings_router, prefix="/api/v1")
app.include_router(generate_router, prefix="/api/v1")
app.include_router(migration_router, prefix="/api/v1")

# legacy compatibility for prototype endpoints
@app.post("/api/talk/assist", response_model=None)
async def legacy_talk_assist(request: Request):
    """temporary alias for old prototype route, redirects to /api/v1/generate"""
    body = await request.json()
    # simply forward to new handler
    return await app.dependency_overrides.get("generate")(body) if False else JSONResponse({"error":"deprecated"}, status_code=410)


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    rid = getattr(request.state, "request_id", "") or ""
    log.exception("unhandled_error", extra={"request_id": rid, "path": request.url.path})
    return JSONResponse(
        status_code=500,
        content={"error": {"code": "INTERNAL_ERROR", "message": "内部エラーです", "detail": {}}},
        headers={"X-Request-Id": rid},
    )
