# 1. 匿名認証でトークン取得
$authRes = Invoke-WebRequest -Uri "http://127.0.0.1:8000/api/v1/auth/anonymous" -Method POST
$token = ($authRes.Content | ConvertFrom-Json).access_token

# 2. トークン付きでgenerate呼び出し
$body = @{
    history_text = "こんにちは。今日はどんな一日でしたか？"
    combo_id = 0
} | ConvertTo-Json

$response = Invoke-WebRequest `
    -Uri "http://127.0.0.1:8000/api/v1/generate" `
    -Method POST `
    -Body $body `
    -ContentType "application/json" `
    -Headers @{ Authorization = "Bearer $token" }

Write-Host $response.Content
