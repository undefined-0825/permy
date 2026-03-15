from __future__ import annotations

import asyncio

from sqlalchemy import select

from app.db import SessionLocal
from app.models import UserSettings


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
