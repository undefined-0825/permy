from __future__ import annotations

import os
import time
from typing import Any, Optional

try:
    import redis.asyncio as redis  # type: ignore
except Exception:
    redis = None  # type: ignore

from app.config import settings


class _MemoryRedis:
    def __init__(self):
        self._kv: dict[str, str] = {}
        self._set: dict[str, set[str]] = {}
        self._ttl: dict[str, int] = {}

    async def get(self, key: str) -> Optional[str]:
        return self._kv.get(key)

    async def set(self, key: str, value: str, ex: int | None = None, nx: bool = False) -> bool:
        if nx and key in self._kv:
            return False
        self._kv[key] = value
        if ex is not None:
            self._ttl[key] = ex
        return True

    async def delete(self, key: str) -> int:
        n = 1 if key in self._kv else 0
        self._kv.pop(key, None)
        self._ttl.pop(key, None)
        self._set.pop(key, None)
        return n

    async def incr(self, key: str) -> int:
        v = int(self._kv.get(key) or "0") + 1
        self._kv[key] = str(v)
        return v

    async def expire(self, key: str, seconds: int) -> bool:
        if key in self._kv or key in self._set:
            self._ttl[key] = seconds
            return True
        return False

    async def ttl(self, key: str) -> int:
        return self._ttl.get(key, -1)

    async def exists(self, key: str) -> int:
        return 1 if (key in self._kv or key in self._set) else 0

    async def sadd(self, key: str, member: str) -> int:
        s = self._set.setdefault(key, set())
        before = len(s)
        s.add(member)
        return 1 if len(s) > before else 0

    async def smembers(self, key: str) -> set[str]:
        return set(self._set.get(key, set()))

    def pipeline(self):
        return _MemoryPipeline(self)


class _MemoryPipeline:
    def __init__(self, r: _MemoryRedis):
        self._r = r
        self._ops: list[tuple[str, tuple[Any, ...], dict[str, Any]]] = []

    def incr(self, *a, **kw):
        self._ops.append(("incr", a, kw))
        return self

    def ttl(self, *a, **kw):
        self._ops.append(("ttl", a, kw))
        return self

    def expire(self, *a, **kw):
        self._ops.append(("expire", a, kw))
        return self

    def delete(self, *a, **kw):
        self._ops.append(("delete", a, kw))
        return self

    def set(self, *a, **kw):
        self._ops.append(("set", a, kw))
        return self

    async def execute(self):
        out = []
        for name, a, kw in self._ops:
            out.append(await getattr(self._r, name)(*a, **kw))
        self._ops.clear()
        return out


class _ResilientPipeline:
    def __init__(self, owner: "_ResilientRedis"):
        self._owner = owner
        self._ops: list[tuple[str, tuple[Any, ...], dict[str, Any]]] = []

    def incr(self, *a, **kw):
        self._ops.append(("incr", a, kw))
        return self

    def ttl(self, *a, **kw):
        self._ops.append(("ttl", a, kw))
        return self

    def expire(self, *a, **kw):
        self._ops.append(("expire", a, kw))
        return self

    def delete(self, *a, **kw):
        self._ops.append(("delete", a, kw))
        return self

    def set(self, *a, **kw):
        self._ops.append(("set", a, kw))
        return self

    async def execute(self):
        primary = self._owner._primary
        if primary is not None:
            try:
                pipe = primary.pipeline()
                for name, a, kw in self._ops:
                    getattr(pipe, name)(*a, **kw)
                return await pipe.execute()
            except Exception:
                self._owner._activate_fallback()

        fallback_pipe = self._owner._fallback.pipeline()
        for name, a, kw in self._ops:
            getattr(fallback_pipe, name)(*a, **kw)
        return await fallback_pipe.execute()


class _ResilientRedis:
    def __init__(
        self,
        primary: Any | None,
        fallback: _MemoryRedis,
        primary_factory: Any | None = None,
        reconnect_interval_seconds: float = 5.0,
    ):
        self._primary = primary
        self._fallback = fallback
        self._primary_factory = primary_factory
        self._reconnect_interval_seconds = reconnect_interval_seconds
        self._last_reconnect_attempt_at = 0.0

    def _activate_fallback(self) -> None:
        self._primary = None

    def _can_attempt_reconnect(self) -> bool:
        now = time.monotonic()
        if now - self._last_reconnect_attempt_at < self._reconnect_interval_seconds:
            return False
        self._last_reconnect_attempt_at = now
        return True

    def _try_reconnect(self) -> None:
        if self._primary is not None:
            return
        if self._primary_factory is None:
            return
        if not self._can_attempt_reconnect():
            return
        try:
            self._primary = self._primary_factory()
        except Exception:
            self._primary = None

    async def _call(self, method: str, *a, **kw):
        self._try_reconnect()
        if self._primary is not None:
            try:
                return await getattr(self._primary, method)(*a, **kw)
            except Exception:
                self._activate_fallback()
        return await getattr(self._fallback, method)(*a, **kw)

    async def get(self, key: str) -> Optional[str]:
        return await self._call("get", key)

    async def set(self, key: str, value: str, ex: int | None = None, nx: bool = False) -> bool:
        return await self._call("set", key, value, ex=ex, nx=nx)

    async def delete(self, key: str) -> int:
        return await self._call("delete", key)

    async def incr(self, key: str) -> int:
        return await self._call("incr", key)

    async def expire(self, key: str, seconds: int) -> bool:
        return await self._call("expire", key, seconds)

    async def ttl(self, key: str) -> int:
        return await self._call("ttl", key)

    async def exists(self, key: str) -> int:
        return await self._call("exists", key)

    async def sadd(self, key: str, member: str) -> int:
        return await self._call("sadd", key, member)

    async def smembers(self, key: str) -> set[str]:
        return await self._call("smembers", key)

    def pipeline(self):
        self._try_reconnect()
        return _ResilientPipeline(self)


def _create_client():
    fallback = _MemoryRedis()
    if os.getenv("REDIS_DISABLED", "").lower() in ("1", "true", "yes"):
        return fallback
    if redis is None:
        return fallback
    try:
        primary_factory = lambda: redis.from_url(settings.redis_url, decode_responses=True)
        primary = primary_factory()
        return _ResilientRedis(primary=primary, fallback=fallback, primary_factory=primary_factory)
    except Exception:
        return fallback


redis_client = _create_client()
