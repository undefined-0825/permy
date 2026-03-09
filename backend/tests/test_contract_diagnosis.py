def _auth_headers(client):
    auth = client.post("/api/v1/auth/anonymous")
    assert auth.status_code == 200
    token = auth.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_diagnosis_returns_types_and_parameters(client):
    headers = _auth_headers(client)
    payload = {
        "answers": [
            {"question_id": "true_priority", "choice_id": "life_balance"},
            {"question_id": "true_decision_axis", "choice_id": "low_stress"},
            {"question_id": "night_goal_primary", "choice_id": "next_visit"},
            {"question_id": "night_temperature", "choice_id": "adaptive"},
            {"question_id": "night_game_tolerance", "choice_id": "light_game"},
            {"question_id": "night_customer_allocation", "choice_id": "care_existing"},
            {"question_id": "night_risk_response", "choice_id": "adaptive_landing"},
        ]
    }

    res = client.post("/api/v1/me/diagnosis", json=payload, headers=headers)
    assert res.status_code == 200

    data = res.json()
    assert data["persona_version"] == 3
    assert data["true_self_type"] in {
        "Stability", "Independence", "Approval", "Realism", "Romance"
    }
    assert data["night_self_type"] in {
        "VisitPush", "Heal", "LittleDevil", "BigClient", "Balance"
    }
    assert 0 <= data["style_assertiveness"] <= 100
    assert 0 <= data["style_warmth"] <= 100
    assert 0 <= data["style_risk_guard"] <= 100


def test_diagnosis_rejects_invalid_question_id(client):
    headers = _auth_headers(client)
    payload = {
        "answers": [
            {"question_id": "invalid", "choice_id": "life_balance"},
            {"question_id": "true_decision_axis", "choice_id": "low_stress"},
            {"question_id": "night_goal_primary", "choice_id": "next_visit"},
            {"question_id": "night_temperature", "choice_id": "adaptive"},
            {"question_id": "night_game_tolerance", "choice_id": "light_game"},
            {"question_id": "night_customer_allocation", "choice_id": "care_existing"},
            {"question_id": "night_risk_response", "choice_id": "adaptive_landing"},
        ]
    }

    res = client.post("/api/v1/me/diagnosis", json=payload, headers=headers)
    assert res.status_code == 422
