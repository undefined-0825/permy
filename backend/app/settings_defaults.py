from __future__ import annotations

DEFAULT_SETTINGS: dict[str, object] = {
    "settings_schema_version": 1,
    "persona_version": 2,
    "relationship_type": "new",
    "reply_length_pref": "standard",
    "line_break_pref": "infer",
    "emoji_amount_pref": "standard",
    "reaction_level_pref": "standard",
    "partner_name_usage_pref": "once",
    "ng_tags": [],
    "ng_free_phrases": [],
    "contact_reminder_threshold_days": [3, 7],
    "visit_reminder_threshold_days": [14, 30],
}


def with_default_settings(settings: dict | None) -> dict:
    normalized = dict(settings or {})

    for key, value in DEFAULT_SETTINGS.items():
        normalized.setdefault(key, value)

    normalized["ng_tags"] = [str(item) for item in normalized.get("ng_tags") or []]
    normalized["ng_free_phrases"] = [
        str(item) for item in normalized.get("ng_free_phrases") or []
    ]
    normalized["contact_reminder_threshold_days"] = [
        int(item)
        for item in normalized.get("contact_reminder_threshold_days") or [3, 7]
        if isinstance(item, int) or (isinstance(item, str) and item.isdigit())
    ]
    normalized["visit_reminder_threshold_days"] = [
        int(item)
        for item in normalized.get("visit_reminder_threshold_days") or [14, 30]
        if isinstance(item, int) or (isinstance(item, str) and item.isdigit())
    ]

    return normalized