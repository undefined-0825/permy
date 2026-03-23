# stg環境向けフロントエンド起動スクリプト
$ErrorActionPreference = "Stop"

$stgUrl = "https://permy-backend-stg.onrender.com"
$healthUrl = "$stgUrl/api/v1/health"

Write-Host "stgサーバーを起こしています... ($healthUrl)" -ForegroundColor Cyan

$maxRetry = 10
$retryInterval = 10
$ok = $false

for ($i = 1; $i -le $maxRetry; $i++) {
    try {
        $res = Invoke-WebRequest -Uri $healthUrl -TimeoutSec 30 -UseBasicParsing -ErrorAction Stop
        if ($res.StatusCode -eq 200) {
            Write-Host "stgサーバー起動確認 OK (${i}回目)" -ForegroundColor Green
            $ok = $true
            break
        }
    } catch {
        Write-Host "[$i/$maxRetry] 応答なし、${retryInterval}秒後に再試行..." -ForegroundColor Yellow
    }
    Start-Sleep -Seconds $retryInterval
}

if (-not $ok) {
    Write-Host "stgサーバーが起動しませんでした。Renderダッシュボードを確認してください。" -ForegroundColor Red
    exit 1
}

$frontendDir = Join-Path -Path $PSScriptRoot -ChildPath "frontend"
Push-Location $frontendDir
try {
    Write-Host "flutter run (stg向け) を開始します..." -ForegroundColor Cyan
    flutter run --dart-define=API_BASE_URL=$stgUrl
} finally {
    Pop-Location
}