from __future__ import annotations

from dataclasses import dataclass


TRUE_TYPES = ["Stability", "Independence", "Approval", "Realism", "Romance"]
NIGHT_TYPES = ["VisitPush", "Heal", "LittleDevil", "BigClient", "Balance"]

TRUE_TIE_ORDER = ["Stability", "Realism", "Independence", "Approval", "Romance"]
NIGHT_TIE_ORDER = ["Balance", "BigClient", "VisitPush", "Heal", "LittleDevil"]

_TRUE_WEIGHTS: dict[tuple[str, str], dict[str, int]] = {
    ("true_priority", "life_balance"): {"Stability": 3, "Independence": 1, "Realism": 1},
    ("true_priority", "future_stability"): {"Stability": 2, "Independence": 1, "Realism": 3},
    ("true_priority", "partner_time"): {"Stability": 1, "Approval": 1, "Romance": 3},
    ("true_priority", "social_trust"): {"Approval": 3, "Realism": 1, "Romance": 1},
    ("true_priority", "self_autonomy"): {"Stability": 1, "Independence": 3, "Realism": 1},
    ("true_decision_axis", "low_stress"): {"Stability": 3, "Independence": 1, "Realism": 2},
    ("true_decision_axis", "long_term_return"): {"Stability": 1, "Independence": 1, "Realism": 3},
    ("true_decision_axis", "emotional_satisfaction"): {"Approval": 2, "Romance": 3},
    ("true_decision_axis", "pace_control"): {"Stability": 1, "Independence": 3, "Realism": 1},
}

_NIGHT_WEIGHTS: dict[tuple[str, str], dict[str, int]] = {
    ("night_goal_primary", "next_visit"): {"VisitPush": 3, "LittleDevil": 1, "BigClient": 2, "Balance": 1},
    ("night_goal_primary", "relationship_keep"): {"VisitPush": 1, "Heal": 3, "BigClient": 1, "Balance": 2},
    ("night_goal_primary", "special_distance"): {"VisitPush": 1, "LittleDevil": 3, "BigClient": 1, "Balance": 1},
    ("night_goal_primary", "long_term_growth"): {"VisitPush": 1, "Heal": 1, "BigClient": 3, "Balance": 2},
    ("night_temperature", "calm_safe"): {"Heal": 3, "BigClient": 1, "Balance": 2},
    ("night_temperature", "sweet_light"): {"VisitPush": 1, "Heal": 1, "LittleDevil": 3, "Balance": 1},
    ("night_temperature", "clear_proposal"): {"VisitPush": 3, "LittleDevil": 1, "BigClient": 2, "Balance": 1},
    ("night_temperature", "adaptive"): {"VisitPush": 1, "Heal": 2, "LittleDevil": 1, "BigClient": 2, "Balance": 3},
    ("night_game_tolerance", "avoid_game"): {"Heal": 3, "BigClient": 2, "Balance": 2},
    ("night_game_tolerance", "light_game"): {"VisitPush": 1, "Heal": 1, "LittleDevil": 2, "BigClient": 1, "Balance": 3},
    ("night_game_tolerance", "adaptive_game"): {"VisitPush": 2, "Heal": 1, "LittleDevil": 2, "BigClient": 2, "Balance": 3},
    ("night_game_tolerance", "active_game"): {"VisitPush": 2, "LittleDevil": 3, "BigClient": 1, "Balance": 1},
    ("night_customer_allocation", "wide_touchpoints"): {"VisitPush": 3, "Heal": 1, "LittleDevil": 1, "BigClient": 1, "Balance": 1},
    ("night_customer_allocation", "care_existing"): {"VisitPush": 1, "Heal": 3, "BigClient": 2, "Balance": 2},
    ("night_customer_allocation", "focus_key_clients"): {"VisitPush": 1, "LittleDevil": 1, "BigClient": 3, "Balance": 1},
    ("night_customer_allocation", "dynamic_balance"): {"VisitPush": 1, "Heal": 2, "LittleDevil": 1, "BigClient": 2, "Balance": 3},
    ("night_risk_response", "firefighting_safe"): {"VisitPush": 1, "Heal": 2, "BigClient": 2, "Balance": 3},
    ("night_risk_response", "soft_distance"): {"Heal": 3, "BigClient": 1, "Balance": 2},
    ("night_risk_response", "recover_initiative"): {"VisitPush": 3, "LittleDevil": 2, "BigClient": 1, "Balance": 1},
    ("night_risk_response", "adaptive_landing"): {"VisitPush": 1, "Heal": 2, "LittleDevil": 1, "BigClient": 2, "Balance": 3},
}


@dataclass(frozen=True)
class DiagnosisOutcome:
    persona_version: int
    true_self_type: str
    night_self_type: str
    persona_goal_primary: str
    persona_goal_secondary: str | None
    style_assertiveness: int
    style_warmth: int
    style_risk_guard: int


def evaluate(answers: dict[str, str]) -> DiagnosisOutcome:
    true_scores = {name: 0 for name in TRUE_TYPES}
    night_scores = {name: 0 for name in NIGHT_TYPES}

    for key, value in answers.items():
        for target, score in _TRUE_WEIGHTS.get((key, value), {}).items():
            true_scores[target] += score
        for target, score in _NIGHT_WEIGHTS.get((key, value), {}).items():
            night_scores[target] += score

    true_self_type = _pick_top(true_scores, TRUE_TIE_ORDER)
    night_self_type = _pick_top(night_scores, NIGHT_TIE_ORDER)

    primary = _goal_primary(answers, night_scores)
    secondary = _goal_secondary(primary, night_scores)

    assertiveness = _normalize(night_scores["VisitPush"] + night_scores["LittleDevil"], 0, 24)
    warmth = _normalize(night_scores["Heal"] + night_scores["Balance"], 0, 24)

    safety_bonus = 4 if answers.get("night_risk_response") in {"firefighting_safe", "adaptive_landing"} else 0
    risk_guard = _normalize(night_scores["Balance"] + safety_bonus, 0, 16)

    return DiagnosisOutcome(
        persona_version=3,
        true_self_type=true_self_type,
        night_self_type=night_self_type,
        persona_goal_primary=primary,
        persona_goal_secondary=secondary,
        style_assertiveness=assertiveness,
        style_warmth=warmth,
        style_risk_guard=risk_guard,
    )


def validate_answers(answers: dict[str, str]) -> bool:
    required = {
        "true_priority",
        "true_decision_axis",
        "night_goal_primary",
        "night_temperature",
        "night_game_tolerance",
        "night_customer_allocation",
        "night_risk_response",
    }
    if set(answers.keys()) != required:
        return False

    for key, value in answers.items():
        if (key, value) not in _TRUE_WEIGHTS and (key, value) not in _NIGHT_WEIGHTS:
            return False
    return True


def _pick_top(scores: dict[str, int], tie_order: list[str]) -> str:
    max_score = max(scores.values())
    candidates = {k for k, v in scores.items() if v == max_score}
    for name in tie_order:
        if name in candidates:
            return name
    return tie_order[0]


def _goal_primary(answers: dict[str, str], night_scores: dict[str, int]) -> str:
    primary_map = {
        "next_visit": "next_visit",
        "relationship_keep": "relationship_keep",
        "special_distance": "special_distance",
        "long_term_growth": "long_term_growth",
    }

    goal = primary_map.get(answers.get("night_goal_primary", ""), "relationship_keep")
    risk_answer = answers.get("night_risk_response")
    if risk_answer == "firefighting_safe" and (night_scores["Balance"] >= night_scores["LittleDevil"] or night_scores["Heal"] >= night_scores["VisitPush"]):
        return "firefighting"
    return goal


def _goal_secondary(primary: str, night_scores: dict[str, int]) -> str | None:
    mapping = {
        "VisitPush": "next_visit",
        "Heal": "relationship_keep",
        "LittleDevil": "special_distance",
        "BigClient": "long_term_growth",
        "Balance": "relationship_keep",
    }
    ordered = sorted(night_scores.items(), key=lambda item: item[1], reverse=True)
    if len(ordered) < 2:
        return None
    second = mapping.get(ordered[1][0])
    if second == primary:
        return None
    return second


def _normalize(value: int, min_value: int, max_value: int) -> int:
    if max_value <= min_value:
        return 0
    bounded = max(min_value, min(value, max_value))
    return int(round((bounded - min_value) * 100 / (max_value - min_value)))
