from app.config import settings


def _auth_token(client) -> str:
    auth_res = client.post("/api/v1/auth/anonymous")
    assert auth_res.status_code == 200
    return auth_res.json()["access_token"]


def _upgrade_plan(client, token: str, product_id: str) -> None:
    verify_res = client.post(
        "/api/v1/billing/verify",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "platform": "android",
            "product_id": product_id,
            "purchase_token": "dummy-token",
        },
    )
    assert verify_res.status_code == 200


def test_customers_requires_auth(client):
    res = client.get("/api/v1/customers")
    assert res.status_code == 401


def test_customers_forbidden_for_free_and_pro(client):
    old_app_env = settings.app_env
    settings.app_env = "dev"

    try:
        free_token = _auth_token(client)
        free_res = client.get("/api/v1/customers", headers={"Authorization": f"Bearer {free_token}"})
        assert free_res.status_code == 403
        assert free_res.json()["detail"]["error"]["code"] == "PLAN_REQUIRED"

        pro_token = _auth_token(client)
        _upgrade_plan(client, pro_token, "permy_pro_monthly")

        pro_res = client.get("/api/v1/customers", headers={"Authorization": f"Bearer {pro_token}"})
        assert pro_res.status_code == 403
        assert pro_res.json()["detail"]["error"]["code"] == "PLAN_REQUIRED"
    finally:
        settings.app_env = old_app_env


def test_customers_premium_crud_and_search(client):
    old_app_env = settings.app_env
    settings.app_env = "dev"

    try:
        token = _auth_token(client)
        _upgrade_plan(client, token, "permy-premium-monthly")
        headers = {"Authorization": f"Bearer {token}"}

        create_res = client.post(
            "/api/v1/customers",
            headers=headers,
            json={
                "display_name": "山田さん",
                "nickname": "やまだ",
                "call_name": "やまださん",
                "area_tag": "梅田",
                "age_range": "30s",
                "job_tag": "営業",
                "relationship_stage": "regular",
                "visit_frequency_tag": "biweekly",
                "drink_style_tag": "normal",
                "memo_summary": "終電を気にするタイプ",
            },
        )
        assert create_res.status_code == 200
        customer = create_res.json()
        customer_id = customer["customer_id"]

        tags_res = client.put(
            f"/api/v1/customers/{customer_id}/tags",
            headers=headers,
            json={
                "tags": [
                    {"category": "topic", "value": "転職"},
                    {"category": "event", "value": "誕生日"},
                ]
            },
        )
        assert tags_res.status_code == 200
        assert len(tags_res.json()) == 2

        visit_res = client.post(
            f"/api/v1/customers/{customer_id}/visit-logs",
            headers=headers,
            json={
                "visited_on": "2026-04-01",
                "visit_type": "store",
                "spend_level": "middle",
                "drink_amount_tag": "normal",
                "mood_tag": "good",
                "memo_short": "終電前に退店",
            },
        )
        assert visit_res.status_code == 200

        event_res = client.post(
            f"/api/v1/customers/{customer_id}/events",
            headers=headers,
            json={
                "event_type": "birthday",
                "event_date": "2026-04-15",
                "title": "誕生日",
                "note": "前日に連絡",
                "remind_days_before": 1,
                "is_active": True,
            },
        )
        assert event_res.status_code == 200
        event_id = event_res.json()["event_id"]

        update_event_reminder_res = client.put(
            f"/api/v1/customers/{customer_id}/events/{event_id}/reminder",
            headers=headers,
            json={"remind_days_before": 3},
        )
        assert update_event_reminder_res.status_code == 200
        assert update_event_reminder_res.json()["remind_days_before"] == 3

        detail_res = client.get(f"/api/v1/customers/{customer_id}", headers=headers)
        assert detail_res.status_code == 200
        detail = detail_res.json()
        assert detail["customer"]["display_name"] == "山田さん"
        assert len(detail["tags"]) == 2
        assert len(detail["visit_logs"]) == 1
        assert len(detail["events"]) == 1
        assert detail["events"][0]["remind_days_before"] == 3

        update_res = client.put(
            f"/api/v1/customers/{customer_id}",
            headers=headers,
            json={
                "relationship_stage": "important",
                "memo_summary": "次回は誕生日前提で提案",
            },
        )
        assert update_res.status_code == 200
        assert update_res.json()["relationship_stage"] == "important"

        list_res = client.get("/api/v1/customers?q=誕生日", headers=headers)
        assert list_res.status_code == 200
        listed = list_res.json()
        assert len(listed) >= 1
        assert listed[0]["customer_id"] == customer_id

        reminders_res = client.get(
            "/api/v1/customers/reminders?today=2026-04-14&days_ahead=20",
            headers=headers,
        )
        assert reminders_res.status_code == 200
        reminders = reminders_res.json()
        assert len(reminders) >= 1
        assert any(item["reminder_type"] == "event" for item in reminders)

        create_res_contact_visit = client.post(
            "/api/v1/customers",
            headers=headers,
            json={
                "display_name": "田中さん",
                "relationship_stage": "new",
                "last_contact_at": "2026-04-08T00:00:00+00:00",
                "last_visit_at": "2026-03-20T00:00:00+00:00",
            },
        )
        assert create_res_contact_visit.status_code == 200

        reminders_gap_res = client.get(
            "/api/v1/customers/reminders?today=2026-04-15&days_ahead=20",
            headers=headers,
        )
        assert reminders_gap_res.status_code == 200
        reminders_gap = reminders_gap_res.json()
        assert any(item["reminder_type"] == "contact_gap" for item in reminders_gap)
        assert any(item["reminder_type"] == "visit_gap" for item in reminders_gap)

        settings_get_res = client.get(
            "/api/v1/me/settings",
            headers=headers,
        )
        assert settings_get_res.status_code == 200
        etag = settings_get_res.headers.get("etag", "")
        assert etag

        settings_put_res = client.put(
            "/api/v1/me/settings",
            headers={
                "Authorization": f"Bearer {token}",
                "If-Match": etag,
            },
            json={
                "settings": {
                    "settings_schema_version": 1,
                    "contact_reminder_threshold_days": [10],
                    "visit_reminder_threshold_days": [40],
                }
            },
        )
        assert settings_put_res.status_code == 200

        custom_threshold_customer = client.post(
            "/api/v1/customers",
            headers=headers,
            json={
                "display_name": "鈴木さん",
                "relationship_stage": "regular",
                "last_contact_at": "2026-04-05T00:00:00+00:00",
                "last_visit_at": "2026-03-06T00:00:00+00:00",
            },
        )
        assert custom_threshold_customer.status_code == 200

        reminders_custom_res = client.get(
            "/api/v1/customers/reminders?today=2026-04-15&days_ahead=0",
            headers=headers,
        )
        assert reminders_custom_res.status_code == 200
        reminders_custom = reminders_custom_res.json()
        assert any("連絡なし10日" in item["title"] for item in reminders_custom)
        assert any("来店なし40日" in item["title"] for item in reminders_custom)
    finally:
        settings.app_env = old_app_env
