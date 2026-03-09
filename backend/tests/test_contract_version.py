from fastapi.testclient import TestClient

from app.main import app


def test_version_endpoint_has_update_fields() -> None:
    client = TestClient(app)

    res = client.get("/api/v1/version")

    assert res.status_code == 200
    body = res.json()

    assert "app" in body
    assert "version" in body
    assert "latest_version" in body
    assert "min_supported_version" in body
    assert "android_store_url" in body
    assert "ios_store_url" in body
