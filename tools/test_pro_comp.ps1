# Test pro_comp user functionality
# Tests that feature_tier/billing_tier separation works correctly

$baseUrl = "http://localhost:8000"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test: pro_comp User (feature_tier/billing_tier)" -ForegroundColor Cyan  
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Create new user
Write-Host "[1] Creating new user..." -ForegroundColor Yellow
$authRes = Invoke-RestMethod -Uri "$baseUrl/api/v1/auth/anonymous" -Method Post -UseBasicParsing
$token = $authRes.access_token
$userId = $authRes.user_id
Write-Host "  User ID: $userId"
Write-Host "  Token: $($token.Substring(0,20))..."

# 2. Test Free user (combo_id=2 should fail)
Write-Host ""
Write-Host "[2] Testing Free user (combo_id=2 should fail)..." -ForegroundColor Yellow
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
    "Idempotency-Key" = "test-free-001"
}
$body = @{
    history_text = "User: Hello"
    combo_id = 2
} | ConvertTo-Json

try {
    $res = Invoke-RestMethod -Uri "$baseUrl/api/v1/generate" -Method Post -Headers $headers -Body $body -UseBasicParsing
    Write-Host "  FAIL - Should have rejected combo_id=2 for Free user" -ForegroundColor Red
} catch {
    if ($_.Exception.Response.StatusCode -eq 403) {
        Write-Host "  OK - combo_id=2 rejected for Free user (403)" -ForegroundColor Green
    } else {
        Write-Host "  FAIL - Unexpected error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 3. Grant pro_comp
Write-Host ""
Write-Host "[3] Granting pro_comp to user..." -ForegroundColor Yellow
$grantOutput = & python "tools/grant_comp_user.py" $userId 2>&1
Write-Host "  $grantOutput"

# 4. Test pro_comp user (combo_id=2 should succeed)
Write-Host ""
Write-Host "[4] Testing pro_comp user (combo_id=2 should succeed)..." -ForegroundColor Yellow
$headers["Idempotency-Key"] = "test-procomp-001"
try {
    $res = Invoke-RestMethod -Uri "$baseUrl/api/v1/generate" -Method Post -Headers $headers -Body $body -UseBasicParsing
    Write-Host "  OK - combo_id=2 accepted for pro_comp user" -ForegroundColor Green
    Write-Host "  Plan in response: $($res.plan)"
    Write-Host "  Daily limit: $($res.daily.limit)"
    
    if ($res.plan -eq "pro") {
        Write-Host "  ✓ Plan correctly returned as 'pro'" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Plan should be 'pro' but was '$($res.plan)'" -ForegroundColor Red
    }
    
    if ($res.daily.limit -eq 100) {
        Write-Host "  ✓ Daily limit correctly set to 100" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Daily limit should be 100 but was $($res.daily.limit)" -ForegroundColor Red
    }
} catch {
    Write-Host "  FAIL - combo_id=2 should work for pro_comp user: $($_.Exception.Message)" -ForegroundColor Red
}

# 5. Verify tier in DB
Write-Host ""
Write-Host "[5] Verifying tier in database..." -ForegroundColor Yellow
$statusOutput = & python "tools/grant_comp_user.py" $userId --status 2>&1
Write-Host "  $statusOutput"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
