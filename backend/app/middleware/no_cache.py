from __future__ import annotations

"""Permyバックエンド共通ミドルウェア

本ミドルウェアは応答ヘッダにキャッシュ禁止を追加するだけの
シンプルなものだが、

- **SSOT による読み取り優先順位** の一部であるという明示
  がまだファイル内にないため追記する。
- **Starlette**アプリケーションのヘッダ整合性を担保する役割

Spec (docs/ssot/SSOT.md) ではキャッシュ禁止関連ルールが直接
言及されていないが、HTTP APIではデフォルトで no-store を
付与する方針である。
"""

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request


class NoCacheMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        resp = await call_next(request)
        resp.headers.setdefault("Cache-Control", "no-store")
        return resp
