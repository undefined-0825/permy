import asyncio
import datetime as dt

from sqlalchemy import delete, select

from app.db import SessionLocal
from app.models import ProCompGrantRequest, User


async def _seed_target(email: str, name: str = "target") -> None:
    async with SessionLocal() as db:
        await db.execute(
            delete(ProCompGrantRequest).where(ProCompGrantRequest.email == email)
        )
        db.add(
            ProCompGrantRequest(
                email=email,
                name=name,
                request_count=0,
                created_at=dt.datetime.now(dt.timezone.utc),
                updated_at=dt.datetime.now(dt.timezone.utc),
            )
        )
        await db.commit()


async def _fetch_target(email: str) -> ProCompGrantRequest | None:
    async with SessionLocal() as db:
        row = await db.execute(
            select(ProCompGrantRequest).where(ProCompGrantRequest.email == email)
        )
        return row.scalar_one_or_none()


def test_pro_comp_request_requires_auth(client):
    res = client.post("/api/v1/pro-comp/request", json={"email": "target@example.com"})
    assert res.status_code == 401


def test_pro_comp_request_approves_only_once(client):
    email = "target@example.com"
    asyncio.run(_seed_target(email))

    auth1 = client.post("/api/v1/auth/anonymous")
    assert auth1.status_code == 200
    token1 = auth1.json()["access_token"]

    first = client.post(
        "/api/v1/pro-comp/request",
        headers={"Authorization": f"Bearer {token1}"},
        json={"email": email},
    )
    assert first.status_code == 200
    assert first.json()["approved"] is True
    assert first.json()["request_count"] == 1

    generate = client.post(
        "/api/v1/generate",
        headers={"Authorization": f"Bearer {token1}"},
        json={
            "history_text": "テスト",
            "combo_id": 2,
            "tuning": None,
        },
    )
    assert generate.status_code == 200
    assert generate.json()["plan"] == "pro"

    stored_after_first = asyncio.run(_fetch_target(email))
    assert stored_after_first is not None
    assert stored_after_first.approved_user_id is not None
    assert stored_after_first.request_count == 1

    auth2 = client.post("/api/v1/auth/anonymous")
    assert auth2.status_code == 200
    token2 = auth2.json()["access_token"]

    second = client.post(
        "/api/v1/pro-comp/request",
        headers={"Authorization": f"Bearer {token2}"},
        json={"email": email},
    )
    assert second.status_code == 409
    assert second.json()["detail"]["error"]["code"] == "PRO_COMP_EMAIL_ALREADY_APPROVED"

    stored_after_second = asyncio.run(_fetch_target(email))
    assert stored_after_second is not None
    assert stored_after_second.request_count == 2


def test_pro_comp_request_rejects_unregistered_email(client):
    auth = client.post("/api/v1/auth/anonymous")
    assert auth.status_code == 200
    token = auth.json()["access_token"]

    res = client.post(
        "/api/v1/pro-comp/request",
        headers={"Authorization": f"Bearer {token}"},
        json={"email": "not-allowed@example.com"},
    )
    assert res.status_code == 403
    assert res.json()["detail"]["error"]["code"] == "PRO_COMP_EMAIL_NOT_ALLOWED"
    # remaining_attempts が返ること
    assert res.json()["detail"]["error"]["detail"]["remaining_attempts"] == 4


def test_pro_comp_locks_after_5_failures(client):
    """5回失敗後にアカウントがロックされ、6回目はACCOUNT_LOCKEDになること"""
    auth = client.post("/api/v1/auth/anonymous")
    assert auth.status_code == 200
    token = auth.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    for i in range(5):
        res = client.post(
            "/api/v1/pro-comp/request",
            headers=headers,
            json={"email": "unknown@example.com"},
        )
        assert res.status_code == 403
        assert res.json()["detail"]["error"]["code"] == "PRO_COMP_EMAIL_NOT_ALLOWED"
        expected_remaining = 4 - i
        assert res.json()["detail"]["error"]["detail"]["remaining_attempts"] == expected_remaining

    # 6回目はACCOUNT_LOCKED
    locked_res = client.post(
        "/api/v1/pro-comp/request",
        headers=headers,
        json={"email": "unknown@example.com"},
    )
    assert locked_res.status_code == 403
    assert locked_res.json()["detail"]["error"]["code"] == "ACCOUNT_LOCKED"

    # DB上でis_lockedがTrueになっていること
    async def _check_locked(user_id: str) -> bool:
        async with SessionLocal() as db:
            row = await db.execute(select(User).where(User.user_id == user_id))
            u = row.scalar_one_or_none()
            return u is not None and u.is_locked

    user_id = auth.json()["user_id"]
    assert asyncio.run(_check_locked(user_id)) is True
