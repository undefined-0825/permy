def test_json_content_type_has_utf8_charset(client) -> None:
    res = client.get("/api/v1/health")

    assert res.status_code == 200
    assert res.headers["content-type"].startswith("application/json")
    assert "charset=utf-8" in res.headers["content-type"].lower()


def test_cache_control_no_store(client) -> None:
    res = client.get("/api/v1/health")

    assert res.status_code == 200
    assert res.headers.get("cache-control") == "no-store"
