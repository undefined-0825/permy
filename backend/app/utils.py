from __future__ import annotations

import hashlib
import hmac
import json
import secrets


def sha256_hex(data: str) -> str:
    return hashlib.sha256(data.encode("utf-8")).hexdigest()


def etag_for_json(obj: dict) -> str:
    raw = json.dumps(obj, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
    return sha256_hex(raw)


def new_ticket_id() -> str:
    return secrets.token_urlsafe(16)


def new_migration_code_12digits() -> str:
    return "".join(str(secrets.randbelow(10)) for _ in range(12))


def user_id_hash(user_id: str, secret: str) -> str:
    """
    user_idをHMAC-SHA256でハッシュ化（Telemetry用）
    元のuser_idから復元不可能な形で匿名化
    """
    return hmac.new(secret.encode("utf-8"), user_id.encode("utf-8"), hashlib.sha256).hexdigest()
