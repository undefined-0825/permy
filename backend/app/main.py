from __future__ import annotations

import os
import pathlib
import logging
from fastapi import FastAPI, Request
from fastapi.responses import FileResponse, JSONResponse

# print("=== startup probe: before settings import ===")
# print("file =", __file__)
# print("cwd =", os.getcwd())
# print("OPENAI_API_KEY(before) =", os.environ.get("OPENAI_API_KEY"))
# print("OPENAI_KEY(before) =", os.environ.get("OPENAI_KEY"))
# print(".env exists? =", pathlib.Path(".env").exists())
# print("backend/.env exists? =", pathlib.Path("backend/.env").exists())

# from app.config import settings

# print("=== startup probe: after settings import ===")
# print("settings.openai_api_key =", settings.openai_api_key)
# print("OPENAI_API_KEY(after) =", os.environ.get("OPENAI_API_KEY"))
# print("OPENAI_KEY(after) =", os.environ.get("OPENAI_KEY"))


from app.config import settings
from app.db import ensure_schema
from app.logging_conf import configure_logging
from app.middleware.request_id import RequestIdMiddleware
from app.middleware.no_cache import NoCacheMiddleware

from app.api.v1.health import router as health_router
from app.api.v1.version import router as version_router
from app.api.v1.auth import router as auth_router
from app.api.v1.settings import router as settings_router
from app.api.v1.diagnosis import router as diagnosis_router
from app.api.v1.generate import router as generate_router
from app.api.v1.migration import router as migration_router
from app.api.v1.telemetry import router as telemetry_router
from app.api.v1.billing import router as billing_router
from app.api.v1.premium_comp import router as premium_comp_router


configure_logging()
log = logging.getLogger(__name__)

app = FastAPI(
    title="Permy API",
    description="接客返信文生成API（本文非保存・privacy-first）",
    version="1.1.0",
    openapi_url="/api/v1/openapi.json",
    docs_url="/docs",
    redoc_url="/redoc",
    contact={
        "name": "Permy Support",
    },
    license_info={
        "name": "Private",
    },
)

app.add_middleware(RequestIdMiddleware)
app.add_middleware(NoCacheMiddleware)

# mount routers under versioned namespace
app.include_router(health_router, prefix="/api/v1")
app.include_router(version_router, prefix="/api/v1")
app.include_router(auth_router, prefix="/api/v1")
app.include_router(settings_router, prefix="/api/v1")
app.include_router(diagnosis_router, prefix="/api/v1")
app.include_router(generate_router, prefix="/api/v1")
app.include_router(migration_router, prefix="/api/v1")
app.include_router(telemetry_router, prefix="/api/v1")
app.include_router(billing_router, prefix="/api/v1")
app.include_router(premium_comp_router, prefix="/api/v1")


@app.on_event("startup")
async def startup_initialize_schema() -> None:
    await ensure_schema()

_static_dir = pathlib.Path(__file__).resolve().parents[1] / "static"
_legal_dir = _static_dir / "legal"


def _legal_page(name: str) -> FileResponse:
    file_path = _legal_dir / f"{name}.html"
    if not file_path.exists():
        # 404相当として FastAPI の標準例外処理に流す
        raise FileNotFoundError(f"legal page not found: {name}")
    return FileResponse(file_path, media_type="text/html; charset=utf-8")


@app.get("/legal/terms")
async def legal_terms():
    return _legal_page("terms")


@app.get("/legal/privacy")
async def legal_privacy():
    return _legal_page("privacy")


@app.get("/legal/help")
async def legal_help():
    return _legal_page("help")

# legacy compatibility for prototype endpoints
@app.post("/api/talk/assist", response_model=None)
async def legacy_talk_assist(request: Request):
    """temporary alias for old prototype route, redirects to /api/v1/generate"""
    body = await request.json()
    # simply forward to new handler
    return await app.dependency_overrides.get("generate")(body) if False else JSONResponse({"error":"deprecated"}, status_code=410)


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    if isinstance(exc, FileNotFoundError):
        return JSONResponse(
            status_code=404,
            content={"error": {"code": "NOT_FOUND", "message": "ページが見つかりません", "detail": {}}},
        )
    rid = getattr(request.state, "request_id", "") or ""
    log.exception("unhandled_error", extra={"request_id": rid, "path": request.url.path})
    return JSONResponse(
        status_code=500,
        content={"error": {"code": "INTERNAL_ERROR", "message": "内部エラーです", "detail": {}}},
        headers={"X-Request-Id": rid},
    )
