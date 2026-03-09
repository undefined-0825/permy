# test_daily_limit.ps1
# Test daily limit enforcement

$ErrorActionPreference = "Stop"
$baseUrl = "http://localhost:8000"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Daily Limit Test (Free Plan = 3/day)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Create new user
Write-Host "[1] Creating new user..." -ForegroundColor Yellow
$authResp = Invoke-WebRequest -Uri "$baseUrl/api/v1/auth/anonymous" -Method POST
$authContent = $authResp.Content | ConvertFrom-Json
$token = $authContent.access_token
$userId = $authContent.user_id
Write-Host "  Token: $($token.Substring(0, 20))..." -ForegroundColor Green
Write-Host "  User ID: $userId" -ForegroundColor Green
Write-Host ""

# Set usage count to 2 (limit is 3, so only 1 more request should succeed)
Write-Host "[2] Setting usage count to 2 (via stub)..." -ForegroundColor Yellow
Push-Location ..\backend
try {
    python tools\set_usage_count.py $userId 2
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: Failed to set usage count" -ForegroundColor Red
        exit 1
    }
} finally {
    Pop-Location
}
Write-Host ""

# Generate request body
$generateBody = @{
    history_text = "User: Hello`nShop: Thank you`nUser: See you"
    combo_id = 0
} | ConvertTo-Json

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

# Test: Send 2 requests (usage is already at 2, limit is 3)
# First request should succeed (2+1=3, at limit)
# Second request should fail (already at 3/3)
Write-Host "[3] Testing daily limit enforcement..." -ForegroundColor Yellow
Write-Host ""

for ($i = 1; $i -le 2; $i++) {
    Write-Host "  [3.$i] Sending generate request #$i..." -ForegroundColor Yellow
    
    try {
        $response = Invoke-WebRequest `
            -Uri "$baseUrl/api/v1/generate" `
            -Method POST `
            -Headers $headers `
            -Body $generateBody
        
        $content = $response.Content | ConvertFrom-Json
        $statusCode = $response.StatusCode
        
        Write-Host "    Status: $statusCode" -ForegroundColor Green
        Write-Host "    Daily: $($content.daily.used)/$($content.daily.limit) (remaining: $($content.daily.remaining))" -ForegroundColor Green
        
        if ($i -eq 1) {
            # First request should succeed (reaching limit)
            if ($content.daily.used -ne 3) {
                Write-Host "    ERROR: Expected used=3, got $($content.daily.used)" -ForegroundColor Red
                exit 1
            }
            Write-Host "    OK - Request succeeded and reached limit (3/3)" -ForegroundColor Green
        } else {
            # Second request should NOT succeed
            Write-Host "    ERROR: Request #$i should have been blocked!" -ForegroundColor Red
            exit 1
        }
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        
        if ($_.Exception.Response) {
            $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            $responseBody = $reader.ReadToEnd()
            $reader.Close()
            
            try {
                $content = $responseBody | ConvertFrom-Json
            } catch {
                $content = $responseBody
            }
        }
        
        Write-Host "    Status: $statusCode" -ForegroundColor Yellow
        
        if ($i -eq 1) {
            # First request should have succeeded
            Write-Host "    ERROR: Request #$i should have succeeded!" -ForegroundColor Red
            Write-Host "    Response: $responseBody" -ForegroundColor Red
            exit 1
        }
        
        if ($statusCode -eq 429) {
            Write-Host "    OK - Daily limit exceeded (429)" -ForegroundColor Green
            if ($content.error_code) {
                Write-Host "    Error code: $($content.error_code)" -ForegroundColor Green
            }
        } else {
            Write-Host "    ERROR: Expected 429, got $statusCode" -ForegroundColor Red
            exit 1
        }
    }
    
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Daily Limit Test: PASSED" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
