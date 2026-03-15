from fastapi import HTTPException


def _auth_headers(client):
    auth = client.post('/api/v1/auth/anonymous')
    assert auth.status_code == 200
    token = auth.json()['access_token']
    return {'Authorization': f'Bearer {token}'}


class _FailingAiClient:
    async def generate_abc(self, history_text, ctx):
        raise HTTPException(
            status_code=502,
            detail={
                'error': {
                    'code': 'AI_UPSTREAM_ERROR',
                    'message': 'AI呼び出しに失敗しました',
                    'detail': {'type': 'TimeoutError'},
                }
            },
        )


def test_generate_keeps_ai_error_code(client, monkeypatch):
    from app.api.v1 import generate as generate_module

    monkeypatch.setattr(generate_module, 'get_ai_client', lambda: _FailingAiClient())

    headers = _auth_headers(client)
    res = client.post(
        '/api/v1/generate',
        json={'history_text': 'User: hello\nShop: hi', 'combo_id': 0},
        headers={**headers, 'Idempotency-Key': 'test-ai-error-passthrough-001'},
    )

    assert res.status_code == 502
    body = res.json()
    assert body['detail']['error']['code'] == 'AI_UPSTREAM_ERROR'
