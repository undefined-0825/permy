# test_idempotency.ps1
# Test Idempotency-Key enforcement

$ErrorActionPreference = "Stop"
$baseUrl = "http://localhost:8000"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Idempotency-Key Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Create new user
Write-Host "[1] Creating new user..." -ForegroundColor Yellow
$authResp = Invoke-WebRequest -Uri "$baseUrl/api/v1/auth/anonymous" -Method POST
$token = ($authResp.Content | ConvertFrom-Json).access_token
Write-Host "  Token: $($token.Substring(0, 20))..." -ForegroundColor Green
Write-Host ""

# Generate request body
$generateBody = @{
    history_text = "User: Test message"
    combo_id = 0
} | ConvertTo-Json

# Test 1: Same Idempotency-Key twice
Write-Host "[2] Test: Same Idempotency-Key twice" -ForegroundColor Yellow
$idempotencyKey = [guid]::NewGuid().ToString()
Write-Host "  Using key: $idempotencyKey" -ForegroundColor DarkGray

$headers1 = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
    "Idempotency-Key" = $idempotencyKey
}

Write-Host "  [2a] First request with this key..." -ForegroundColor Yellow
try {
    $response1 = Invoke-WebRequest `
        -Uri "$baseUrl/api/v1/generate" `
        -Method POST `
        -Headers $headers1 `
        -Body $generateBody
    
    Write-Host "    Status: $($response1.StatusCode) (Success)" -ForegroundColor Green
}
catch {
    $statusCode1 = $_.Exception.Response.StatusCode.value__
    Write-Host "    Status: $statusCode1 (Failed)" -ForegroundColor Red
    exit 1
}

Write-Host "  [2b] Second request with SAME key..." -ForegroundColor Yellow
try {
    $response2 = Invoke-WebRequest `
        -Uri "$baseUrl/api/v1/generate" `
        -Method POST `
        -Headers $headers1 `
        -Body $generateBody
    
    Write-Host "    Status: $($response2.StatusCode) - Should have been blocked!" -ForegroundColor Red
    exit 1
}
catch {
    $statusCode2 = $_.Exception.Response.StatusCode.value__
    
    if ($statusCode2 -eq 429) {
        Write-Host "    Status: $statusCode2 (Blocked - OK)" -ForegroundColor Green
        
        if ($_.Exception.Response) {
            $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            $responseBody = $reader.ReadToEnd()
            $reader.Close()
            
            try {
                $content = $responseBody | ConvertFrom-Json
                if ($content.error_code) {
                    Write-Host "    Error code: $($content.error_code)" -ForegroundColor Green
                }
            } catch {
                # Ignore
            }
        }
    } else {
        Write-Host "    Status: $statusCode2 - Expected 429!" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# Test 2: Different Idempotency-Key should succeed
Write-Host "[3] Test: Different Idempotency-Key should succeed" -ForegroundColor Yellow
$idempotencyKey2 = [guid]::NewGuid().ToString()
Write-Host "  Using new key: $idempotencyKey2" -ForegroundColor DarkGray

$headers2 = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
    "Idempotency-Key" = $idempotencyKey2
}

try {
    $response3 = Invoke-WebRequest `
        -Uri "$baseUrl/api/v1/generate" `
        -Method POST `
        -Headers $headers2 `
        -Body $generateBody
    
    Write-Host "  Status: $($response3.StatusCode) (Success)" -ForegroundColor Green
}
catch {
    $statusCode3 = $_.Exception.Response.StatusCode.value__
    Write-Host "  Status: $statusCode3 (Should have succeeded!)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Idempotency-Key Test: PASSED" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
