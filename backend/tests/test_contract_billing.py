from app.config import settings


def test_billing_verify_requires_auth(client):
    res = client.post(
        "/api/v1/billing/verify",
        json={
            "platform": "android",
            "product_id": "permy_pro_monthly",
            "purchase_token": "dummy-token",
        },
    )
    assert res.status_code == 401


def test_billing_verify_returns_pro_and_allows_pro_combo(client):
    old_app_env = settings.app_env
    settings.app_env = "dev"

    try:
        auth_res = client.post("/api/v1/auth/anonymous")
        assert auth_res.status_code == 200
        token = auth_res.json()["access_token"]

        before = client.post(
            "/api/v1/generate",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "history_text": "テスト",
                "combo_id": 2,
                "tuning": None,
            },
        )
        assert before.status_code == 403

        verify_res = client.post(
            "/api/v1/billing/verify",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "platform": "android",
                "product_id": "permy_pro_monthly",
                "purchase_token": "dummy-token",
            },
        )
        assert verify_res.status_code == 200
        assert verify_res.json()["plan"] == "pro"
        assert verify_res.json()["verified"] is True

        after = client.post(
            "/api/v1/generate",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "history_text": "テスト",
                "combo_id": 2,
                "tuning": None,
            },
        )
        assert after.status_code == 200
        assert after.json()["plan"] == "pro"
    finally:
        settings.app_env = old_app_env


def test_billing_verify_rejects_invalid_product(client):
    old_app_env = settings.app_env
    settings.app_env = "dev"

    try:
        auth_res = client.post("/api/v1/auth/anonymous")
        assert auth_res.status_code == 200
        token = auth_res.json()["access_token"]

        verify_res = client.post(
            "/api/v1/billing/verify",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "platform": "android",
                "product_id": "invalid_product",
                "purchase_token": "dummy-token",
            },
        )
        assert verify_res.status_code == 400
        assert verify_res.json()["detail"]["error"]["code"] == "BILLING_PRODUCT_INVALID"
    finally:
        settings.app_env = old_app_env


def test_billing_verify_rejects_empty_purchase_token(client):
    old_app_env = settings.app_env
    settings.app_env = "dev"

    try:
        auth_res = client.post("/api/v1/auth/anonymous")
        assert auth_res.status_code == 200
        token = auth_res.json()["access_token"]

        verify_res = client.post(
            "/api/v1/billing/verify",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "platform": "android",
                "product_id": "permy_pro_monthly",
                "purchase_token": "   ",
            },
        )
        assert verify_res.status_code == 400
        assert verify_res.json()["detail"]["error"]["code"] == "BILLING_RECEIPT_INVALID"
    finally:
        settings.app_env = old_app_env


def test_billing_verify_prod_returns_not_configured(client):
    old_app_env = settings.app_env
    settings.app_env = "prod"

    try:
        auth_res = client.post("/api/v1/auth/anonymous")
        assert auth_res.status_code == 200
        token = auth_res.json()["access_token"]

        verify_res = client.post(
            "/api/v1/billing/verify",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "platform": "android",
                "product_id": "permy_pro_monthly",
                "purchase_token": "dummy-token",
            },
        )
        assert verify_res.status_code == 503
        assert verify_res.json()["detail"]["error"]["code"] == "BILLING_NOT_CONFIGURED"
    finally:
        settings.app_env = old_app_env
