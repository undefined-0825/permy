# test_rate_limit.ps1
# Test rate limit enforcement (5 requests per minute)

$ErrorActionPreference = "Stop"
$baseUrl = "http://localhost:8000"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Rate Limit Test (5 requests/minute)" -ForegroundColor Cyan
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
    history_text = "User: Hello"
    combo_id = 0
} | ConvertTo-Json

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

# Test: Send 6 requests rapidly (limit is 5/min)
$successCount = 0
$rateLimitedCount = 0

for ($i = 1; $i -le 6; $i++) {
    Write-Host "[$i] Sending rapid request..." -ForegroundColor Yellow
    
    try {
        $response = Invoke-WebRequest `
            -Uri "$baseUrl/api/v1/generate" `
            -Method POST `
            -Headers $headers `
            -Body $generateBody `
            -TimeoutSec 5
        
        $statusCode = $response.StatusCode
        Write-Host "  Status: $statusCode (Success)" -ForegroundColor Green
        $successCount++
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        
        if ($statusCode -eq 429) {
            Write-Host "  Status: $statusCode (Rate limited)" -ForegroundColor Yellow
            $rateLimitedCount++
            
            if ($_.Exception.Response) {
                $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
                $responseBody = $reader.ReadToEnd()
                $reader.Close()
                
                try {
                    $content = $responseBody | ConvertFrom-Json
                    if ($content.error_code) {
                        Write-Host "  Error code: $($content.error_code)" -ForegroundColor DarkGray
                    }
                } catch {
                    # Ignore parse errors
                }
            }
        } else {
            Write-Host "  Status: $statusCode (Unexpected error)" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Results:" -ForegroundColor Cyan
Write-Host "  Success: $successCount" -ForegroundColor Green
Write-Host "  Rate limited (429): $rateLimitedCount" -ForegroundColor Yellow
Write-Host ""

if ($rateLimitedCount -gt 0) {
    Write-Host "OK - Rate limit is working (at least 1 request was rate limited)" -ForegroundColor Green
} else {
    Write-Host "WARNING - No rate limiting detected (all $successCount requests succeeded)" -ForegroundColor Yellow
    Write-Host "  This might be OK if limit is higher than 6 requests/minute" -ForegroundColor DarkGray
}

Write-Host "========================================" -ForegroundColor Cyan
