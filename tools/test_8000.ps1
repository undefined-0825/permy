#requires -Version 5.1
param(
    [string]$BaseUrl = "http://127.0.0.1:8000",
    [string]$Path    = "/api/v1/health"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# 日本語文字化け対策（PS5）
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding           = [System.Text.UTF8Encoding]::new($false)

try {
    $uri = ($BaseUrl.TrimEnd('/') + $Path)
    $response = Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec 5

    if ($response.StatusCode -eq 200) {
        Write-Host "[OK] FastAPIサーバーは正常に応答しています。"
        Write-Host ("レスポンス: {0}" -f $response.Content)
        exit 0
    }

    Write-Host ("[NG] FastAPIサーバーからの応答コード: {0}" -f $response.StatusCode)
    exit 1
}
catch {
    Write-Host "[NG] FastAPIサーバーに接続できませんでした。"
    Write-Host ("例外: {0}" -f $_.Exception.Message)
    exit 1
}