def _auth_headers(client):
    auth = client.post("/api/v1/auth/anonymous")
    assert auth.status_code == 200
    token = auth.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_generate_uses_settings_context_with_dummy_client(client):
    headers = _auth_headers(client)

    current = client.get("/api/v1/me/settings", headers=headers)
    assert current.status_code == 200
    assert (current.json().get("etag") or "") != ""
    etag = current.headers.get("etag")
    settings = dict(current.json().get("settings") or {})
    settings.update(
        {
            "relationship_type": "regular",
            "true_self_type": "Stability",
            "night_self_type": "Balance",
            "persona_goal_primary": "relationship_keep",
            "style_assertiveness": 40,
            "style_warmth": 70,
            "style_risk_guard": 65,
            "emoji_amount_pref": "many",
            "reaction_level_pref": "high",
        }
    )

    updated = client.put(
        "/api/v1/me/settings",
        json={"settings": settings},
        headers={**headers, "If-Match": etag},
    )
    assert updated.status_code == 200

    res = client.post(
        "/api/v1/generate",
        json={"history_text": "User: hello\nShop: hi", "combo_id": 0},
        headers={**headers, "Idempotency-Key": "test-generate-context-001"},
    )
    assert res.status_code == 200

    body = res.json()
    candidates = body["candidates"]
    assert len(candidates) == 3
    assert "関係: regular" in candidates[0]["text"]
    assert "😊" in candidates[0]["text"]
    assert "！" in candidates[0]["text"]


def test_generate_uses_default_followup_settings_for_new_user(client):
    headers = _auth_headers(client)

    res = client.post(
        "/api/v1/generate",
        json={"history_text": "User: hello\nShop: hi", "combo_id": 0},
        headers={**headers, "Idempotency-Key": "test-generate-default-settings-001"},
    )
    assert res.status_code == 200

    body = res.json()
    assert body.get("followup") is None
