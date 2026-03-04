import pytest

from app.schemas import AuthAnonymousResponse


def test_auth_anonymous_returns_200(client):
    """
    POST /api/v1/auth/anonymous クライアント IP とデバイス fingerprint でレート制限
    """
    res = client.post("/api/v1/auth/anonymous")
    assert res.status_code == 200


def test_auth_anonymous_response_schema(client):
    """
    POST /api/v1/auth/anonymous はuser_id, access_token を返す
    """
    res = client.post("/api/v1/auth/anonymous")
    assert res.status_code == 200

    data = res.json()
    assert "user_id" in data
    assert "access_token" in data
    assert isinstance(data["user_id"], str)
    assert isinstance(data["access_token"], str)
    assert len(data["user_id"]) > 0
    assert len(data["access_token"]) > 0


def test_auth_anonymous_creates_unique_users(client):
    """
    複数リクエストで異なる user_id を発行
    """
    res1 = client.post("/api/v1/auth/anonymous")
    res2 = client.post("/api/v1/auth/anonymous")

    assert res1.status_code == 200
    assert res2.status_code == 200

    data1 = res1.json()
    data2 = res2.json()

    assert data1["user_id"] != data2["user_id"]
    assert data1["access_token"] != data2["access_token"]


def test_auth_anonymous_missing_device_fingerprint_is_ok(client):
    """
    X-Device-Fingerprint ヘッダなしで呼び出し可能
    """
    res = client.post("/api/v1/auth/anonymous")
    assert res.status_code == 200
    assert "user_id" in res.json()


def test_auth_anonymous_with_device_fingerprint(client):
    """
    X-Device-Fingerprint ヘッダ付きでも呼び出し可能
    """
    res = client.post(
        "/api/v1/auth/anonymous",
        headers={"X-Device-Fingerprint": "test_device_123"},
    )
    assert res.status_code == 200
    assert "user_id" in res.json()
