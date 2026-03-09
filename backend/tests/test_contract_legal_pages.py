from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_legal_terms_page() -> None:
    res = client.get("/legal/terms")
    assert res.status_code == 200
    assert "text/html" in res.headers.get("content-type", "")
    assert "Permy 利用規約" in res.text


def test_legal_privacy_page() -> None:
    res = client.get("/legal/privacy")
    assert res.status_code == 200
    assert "text/html" in res.headers.get("content-type", "")
    assert "Permy プライバシーポリシー" in res.text


def test_legal_help_page() -> None:
    res = client.get("/legal/help")
    assert res.status_code == 200
    assert "text/html" in res.headers.get("content-type", "")
    assert "Permy ヘルプ（使い方）" in res.text
