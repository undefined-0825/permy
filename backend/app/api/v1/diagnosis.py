from __future__ import annotations

from fastapi import APIRouter, Depends

from app.schemas import DiagnosisRequest, DiagnosisResponse
from app.security import AuthContext, get_auth_context
from app.errors import err
from app.services.diagnosis import evaluate, validate_answers

router = APIRouter()


@router.post("/me/diagnosis", response_model=DiagnosisResponse)
async def evaluate_diagnosis(
    req: DiagnosisRequest,
    auth: AuthContext = Depends(get_auth_context),
):
    _ = auth
    answers = {item.question_id: item.choice_id for item in req.answers}
    if len(answers) != len(req.answers):
        raise err("VALIDATION_FAILED", "設問が重複しています", status_code=422)

    if not validate_answers(answers):
        raise err("VALIDATION_FAILED", "設問または選択肢が不正です", status_code=422)

    result = evaluate(answers)
    return DiagnosisResponse(
        persona_version=result.persona_version,
        true_self_type=result.true_self_type,
        night_self_type=result.night_self_type,
        persona_goal_primary=result.persona_goal_primary,
        persona_goal_secondary=result.persona_goal_secondary,
        style_assertiveness=result.style_assertiveness,
        style_warmth=result.style_warmth,
        style_risk_guard=result.style_risk_guard,
    )
