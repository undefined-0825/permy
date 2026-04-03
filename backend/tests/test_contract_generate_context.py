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
            "line_break_pref": "many",
            "emoji_amount_pref": "many",
            "reaction_level_pref": "high",
            "partner_name_usage_pref": "many",
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
        json={"history_text": "さやかちゃん: hello\nShop: hi", "combo_id": 0},
        headers={**headers, "Idempotency-Key": "test-generate-context-001"},
    )
    assert res.status_code == 200

    body = res.json()
    candidates = body["candidates"]
    assert len(candidates) == 3
    assert "関係: regular" in candidates[0]["text"]
    # FreeプランではPro専用設定が正規化される
    assert "さやかちゃん" not in candidates[0]["text"]
    assert "😊" not in candidates[0]["text"]
    assert "！" not in candidates[0]["text"]
    assert "\n" not in candidates[0]["text"]


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


def test_generate_accepts_my_line_name(client):
    """my_line_name フィールドを含むリクエストが正常に処理される"""
    headers = _auth_headers(client)

    res = client.post(
        "/api/v1/generate",
        json={
            "history_text": "田中太郎\tこんにちは\n山田花子\tこんにちは",
            "combo_id": 0,
            "my_line_name": "田中太郎",
        },
        headers={**headers, "Idempotency-Key": "test-generate-my-line-name-001"},
    )
    assert res.status_code == 200
    body = res.json()
    assert len(body["candidates"]) == 3


def test_generate_my_line_name_is_optional(client):
    """my_line_name が省略された場合も正常に処理される（後方互換）"""
    headers = _auth_headers(client)

    res = client.post(
        "/api/v1/generate",
        json={"history_text": "User: hello\nShop: hi", "combo_id": 0},
        headers={**headers, "Idempotency-Key": "test-generate-no-line-name-001"},
    )
    assert res.status_code == 200
    assert len(res.json()["candidates"]) == 3


def test_generate_accepts_customer_context(client):
    """customer_context を含むリクエストが正常に処理される"""
    headers = _auth_headers(client)

    res = client.post(
        "/api/v1/generate",
        json={
            "history_text": "User: hello\nShop: hi",
            "combo_id": 0,
            "customer_context": {
                "display_name": "山田さん",
                "relationship_stage": "regular",
                "memo_summary": "終電前に帰る",
                "tags": [{"category": "topic", "value": "誕生日"}],
            },
        },
        headers={**headers, "Idempotency-Key": "test-generate-customer-context-001"},
    )
    assert res.status_code == 200
    assert len(res.json()["candidates"]) == 3
