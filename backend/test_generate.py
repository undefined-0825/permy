import asyncio
import json
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

# Auth
res = client.post('/api/v1/auth/anonymous')
print(f"Auth status: {res.status_code}")
token = res.json()['access_token']

# Generate
headers = {
    'Authorization': f'Bearer {token}',
    'Idempotency-Key': 'test-001',
    'Content-Type': 'application/json'
}
body = json.dumps({
    'history_text': 'User: hello\nShop: hi',
    'combo_id': 0
})

try:
    res = client.post('/api/v1/generate', content=body, headers=headers)
    print(f"Generate status: {res.status_code}")
    print(f"Response: {res.text}")
except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()
