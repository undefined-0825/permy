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


def test_auth_anonymous_initial_settings_include_followup_defaults(client):
    res = client.post("/api/v1/auth/anonymous")
    assert res.status_code == 200
    token = res.json()["access_token"]

    settings = client.get(
        "/api/v1/me/settings",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert settings.status_code == 200

    body = settings.json()["settings"]
    assert body["relationship_type"] == "new"
    assert body["reply_length_pref"] == "standard"
    assert body["ng_tags"] == []
    assert body["ng_free_phrases"] == []


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


def test_delete_account_requires_auth(client):
    """
    DELETE /api/v1/auth/me は認証必須
    """
    res = client.delete("/api/v1/auth/me")
    assert res.status_code == 401


def test_delete_account_returns_204(client):
    """
    DELETE /api/v1/auth/me は204を返す
    """
    # ユーザー作成
    res = client.post("/api/v1/auth/anonymous")
    assert res.status_code == 200
    token = res.json()["access_token"]

    # アカウント削除
    res = client.delete(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res.status_code == 204


def test_delete_account_invalidates_session(client):
    """
    アカウント削除後はセッションが無効化される
    """
    # ユーザー作成
    res = client.post("/api/v1/auth/anonymous")
    assert res.status_code == 200
    token = res.json()["access_token"]

    # アカウント削除
    res = client.delete(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res.status_code == 204

    # 削除後のトークンでアクセスすると401
    res = client.get(
        "/api/v1/me/settings",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res.status_code == 401
