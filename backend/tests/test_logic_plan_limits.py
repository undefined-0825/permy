from app.plan_limits import (
    FREE_GENERATE_DAILY_LIMIT,
    PREMIUM_GENERATE_DAILY_LIMIT,
    PRO_GENERATE_DAILY_LIMIT,
    generate_daily_limit,
)


def test_generate_daily_limit_is_fixed_for_each_plan():
    assert FREE_GENERATE_DAILY_LIMIT == 3
    assert PRO_GENERATE_DAILY_LIMIT == 100
    assert PREMIUM_GENERATE_DAILY_LIMIT == 200

    assert generate_daily_limit("free") == 3
    assert generate_daily_limit("pro") == 100
    assert generate_daily_limit("premium") == 200


def test_generate_daily_limit_fallbacks_to_free_for_unknown_plan():
    assert generate_daily_limit("unknown") == 3
