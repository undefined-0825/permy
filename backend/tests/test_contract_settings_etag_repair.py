from __future__ import annotations

import asyncio

from sqlalchemy import select

from app.db import SessionLocal
from app.models import User, UserSettings


def _auth(client):
    res = client.post('/api/v1/auth/anonymous')
    assert res.status_code == 200
    body = res.json()
    token = body['access_token']
    user_id = body['user_id']
    return token, user_id


async def _clear_settings_etag(user_id: str) -> None:
    async with SessionLocal() as session:
        row = await session.execute(
            select(UserSettings).where(UserSettings.user_id == user_id)
        )
        st = row.scalar_one_or_none()
        assert st is not None
        st.etag = ''
        await session.commit()


async def _tamper_settings_plan(user_id: str) -> None:
    async with SessionLocal() as session:
        row = await session.execute(
            select(UserSettings).where(UserSettings.user_id == user_id)
        )
        st = row.scalar_one_or_none()
        assert st is not None
        settings = dict(st.settings_json or {})
        settings['feature_tier'] = 'pro'
        settings['billing_tier'] = 'premium_comp'
        settings['plan'] = 'pro'
        st.settings_json = settings
        await session.commit()


async def _get_user_tiers(user_id: str) -> tuple[str, str]:
    async with SessionLocal() as session:
        row = await session.execute(select(User).where(User.user_id == user_id))
        user = row.scalar_one_or_none()
        assert user is not None
        feature_tier = user.feature_tier or 'free'
        billing_tier = user.billing_tier or 'free'
        return feature_tier, billing_tier


def test_get_settings_repairs_missing_etag(client):
    token, user_id = _auth(client)
    headers = {'Authorization': f'Bearer {token}'}

    current = client.get('/api/v1/me/settings', headers=headers)
    assert current.status_code == 200

    asyncio.run(_clear_settings_etag(user_id))

    repaired = client.get('/api/v1/me/settings', headers=headers)
    assert repaired.status_code == 200

    repaired_body = repaired.json()
    repaired_etag = (repaired.headers.get('etag') or repaired_body.get('etag') or '').strip()
    assert repaired_etag != ''

    updated = client.put(
        '/api/v1/me/settings',
        json={'settings': {'settings_schema_version': 1, 'persona_version': 3}},
        headers={**headers, 'If-Match': repaired_etag},
    )
    assert updated.status_code == 200


def test_get_settings_syncs_plan_fields_with_auth_context(client):
    token, user_id = _auth(client)
    headers = {'Authorization': f'Bearer {token}'}

    current = client.get('/api/v1/me/settings', headers=headers)
    assert current.status_code == 200

    asyncio.run(_tamper_settings_plan(user_id))
    feature_tier, billing_tier = asyncio.run(_get_user_tiers(user_id))
    expected_plan = 'pro' if feature_tier == 'pro' else 'free'

    repaired = client.get('/api/v1/me/settings', headers=headers)
    assert repaired.status_code == 200
    settings = repaired.json().get('settings') or {}

    assert settings.get('feature_tier') == feature_tier
    assert settings.get('billing_tier') == billing_tier
    assert settings.get('plan') == expected_plan
