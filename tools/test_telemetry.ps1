# Test Telemetry API
# Tests POST /api/v1/telemetry/events endpoint

$baseUrl = "http://localhost:8000"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test: Telemetry API" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Create new user
Write-Host "[1] Creating new user..." -ForegroundColor Yellow
$authRes = Invoke-RestMethod -Uri "$baseUrl/api/v1/auth/anonymous" -Method Post -UseBasicParsing
$token = $authRes.access_token
$userId = $authRes.user_id
Write-Host "  User ID: $userId"
Write-Host "  Token: $($token.Substring(0,20))..."

# 2. Send telemetry events (generate_requested)
Write-Host ""
Write-Host "[2] Sending generate_requested event..." -ForegroundColor Yellow
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}
$body = @{
    events = @(
        @{
            event_name = "generate_requested"
            app_version = "1.0.0"
            os = "android"
            device_class = "phone"
            daily_used = 0
            daily_remaining = 3
            has_ng_setting = $false
            persona_version = 2
        }
    )
} | ConvertTo-Json -Depth 5

try {
    $res = Invoke-RestMethod -Uri "$baseUrl/api/v1/telemetry/events" -Method Post -Headers $headers -Body $body -UseBasicParsing
    Write-Host "  OK - Events received: $($res.received)" -ForegroundColor Green
    Write-Host "  Request ID: $($res.request_id)"
} catch {
    Write-Host "  FAIL - $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 3. Send multiple events (batch)
Write-Host ""
Write-Host "[3] Sending batch of events..." -ForegroundColor Yellow
$body = @{
    events = @(
        @{
            event_name = "generate_succeeded"
            app_version = "1.0.0"
            os = "ios"
            device_class = "phone"
            latency_ms = 1500
            ng_gate_triggered = $false
            followup_returned = $false
        },
        @{
            event_name = "candidate_copied"
            app_version = "1.0.0"
            os = "ios"
            device_class = "phone"
            candidate_id = "A"
        },
        @{
            event_name = "app_opened"
            app_version = "1.0.0"
            os = "android"
            device_class = "tablet"
        }
    )
} | ConvertTo-Json -Depth 5

try {
    $res = Invoke-RestMethod -Uri "$baseUrl/api/v1/telemetry/events" -Method Post -Headers $headers -Body $body -UseBasicParsing
    Write-Host "  OK - Events received: $($res.received)" -ForegroundColor Green
    
    if ($res.received -eq 3) {
        Write-Host "  [OK] Batch size correct" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Expected 3 events, got $($res.received)" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "  FAIL - $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 4. Test generate_failed event
Write-Host ""
Write-Host "[4] Sending generate_failed event..." -ForegroundColor Yellow
$body = @{
    events = @(
        @{
            event_name = "generate_failed"
            app_version = "1.0.0"
            os = "android"
            device_class = "phone"
            latency_ms = 500
            error_code = "UPSTREAM_UNAVAILABLE"
        }
    )
} | ConvertTo-Json -Depth 5

try {
    $res = Invoke-RestMethod -Uri "$baseUrl/api/v1/telemetry/events" -Method Post -Headers $headers -Body $body -UseBasicParsing
    Write-Host "  OK - Events received: $($res.received)" -ForegroundColor Green
} catch {
    Write-Host "  FAIL - $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 5. Test without authentication (should fail with 401)
Write-Host ""
Write-Host "[5] Testing without authentication (should fail)..." -ForegroundColor Yellow
$headers_noauth = @{
    "Content-Type" = "application/json"
}
try {
    $res = Invoke-RestMethod -Uri "$baseUrl/api/v1/telemetry/events" -Method Post -Headers $headers_noauth -Body $body -UseBasicParsing
    Write-Host "  FAIL - Should have rejected unauthenticated request" -ForegroundColor Red
    exit 1
} catch {
    if ($_.Exception.Response.StatusCode -eq 401) {
        Write-Host "  OK - Unauthenticated request rejected (401)" -ForegroundColor Green
    } else {
        Write-Host "  FAIL - Unexpected status code: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "All Telemetry API Tests Passed" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
