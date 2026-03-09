# Test Followup功能
# Tests followup generation when settings are missing

$baseUrl = "http://localhost:8000"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test: Followup Generation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Create new user
Write-Host "[1] Creating new user..." -ForegroundColor Yellow
$authRes = Invoke-RestMethod -Uri "$baseUrl/api/v1/auth/anonymous" -Method Post -UseBasicParsing
$token = $authRes.access_token
$userId = $authRes.user_id
Write-Host "  User ID: $userId"
Write-Host "  Token: $($token.Substring(0,20))..."

# 2. Generate without any settings (should return followup for relationship_type)
Write-Host ""
Write-Host "[2] Generate without settings (should return followup)..." -ForegroundColor Yellow
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
    "Idempotency-Key" = "test-followup-001"
}
$body = @{
    history_text = "User: Hello\nShop: Hi there"
    combo_id = 0
} | ConvertTo-Json

try {
    $res = Invoke-RestMethod -Uri "$baseUrl/api/v1/generate" -Method Post -Headers $headers -Body $body -UseBasicParsing
    
    if ($res.followup) {
        Write-Host "  OK - Followup returned" -ForegroundColor Green
        Write-Host "    Key: $($res.followup.key)"
        Write-Host "    Question: $($res.followup.question)"
        Write-Host "    Choices: $($res.followup.choices.Count)"
        
        if ($res.followup.key -eq "relationship_type") {
            Write-Host "  [OK] Followup key is 'relationship_type'" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] Expected 'relationship_type', got '$($res.followup.key)'" -ForegroundColor Red
            exit 1
        }
        
        if ($res.followup.choices.Count -ge 1 -and $res.followup.choices.Count -le 3) {
            Write-Host "  [OK] Choices count: $($res.followup.choices.Count)" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] Invalid choices count: $($res.followup.choices.Count)" -ForegroundColor Red
            exit 1
        }
        
        # Verify A/B/C candidates are still returned
        if ($res.candidates.Count -eq 3) {
            Write-Host "  [OK] A/B/C candidates returned (離脱防止)" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] Expected 3 candidates, got $($res.candidates.Count)" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "  FAIL - No followup returned" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "  FAIL - $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $body = $reader.ReadToEnd()
        Write-Host "  Response body: $body" -ForegroundColor Red
    }
    exit 1
}

# 3. Update settings with relationship_type
Write-Host ""
Write-Host "[3] Updating settings with relationship_type..." -ForegroundColor Yellow
$getResp = Invoke-WebRequest -Uri "$baseUrl/api/v1/me/settings" -Method Get -Headers @{ "Authorization" = "Bearer $token" } -UseBasicParsing
$getRes = $getResp.Content | ConvertFrom-Json

# Convert to hashtable for easy manipulation
$currentSettings = @{}
if ($getRes.settings -ne $null) {
    $getRes.settings.PSObject.Properties | ForEach-Object {
        $currentSettings[$_.Name] = $_.Value
    }
}
$currentSettings["relationship_type"] = "regular"

$updateHeaders = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
    "If-Match" = $getResp.Headers['ETag']
}
$updateBody = @{
    settings = $currentSettings
} | ConvertTo-Json -Depth 5

$updateRes = Invoke-RestMethod -Uri "$baseUrl/api/v1/me/settings" -Method Put -Headers $updateHeaders -Body $updateBody -UseBasicParsing
Write-Host "  OK - Settings updated"

# 4. Generate again (should return followup for reply_length_pref)
Write-Host ""
Write-Host "[4] Generate with relationship_type set (should return followup for reply_length_pref)..." -ForegroundColor Yellow
$headers["Idempotency-Key"] = "test-followup-002"

try {
    $res = Invoke-RestMethod -Uri "$baseUrl/api/v1/generate" -Method Post -Headers $headers -Body $body -UseBasicParsing
    
    if ($res.followup) {
        Write-Host "  OK - Followup returned" -ForegroundColor Green
        Write-Host "    Key: $($res.followup.key)"
        Write-Host "    Question: $($res.followup.question)"
        
        if ($res.followup.key -eq "reply_length_pref") {
            Write-Host "  [OK] Followup key is 'reply_length_pref'" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] Expected 'reply_length_pref', got '$($res.followup.key)'" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "  FAIL - No followup returned" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "  FAIL - $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 5. Update settings with reply_length_pref
Write-Host ""
Write-Host "[5] Updating settings with reply_length_pref..." -ForegroundColor Yellow
$getResp = Invoke-WebRequest -Uri "$baseUrl/api/v1/me/settings" -Method Get -Headers @{ "Authorization" = "Bearer $token" } -UseBasicParsing
$getRes = $getResp.Content | ConvertFrom-Json

# Convert to hashtable for easy manipulation
$currentSettings = @{}
if ($getRes.settings -ne $null) {
    $getRes.settings.PSObject.Properties | ForEach-Object {
        $currentSettings[$_.Name] = $_.Value
    }
}
$currentSettings["reply_length_pref"] = "standard"

$updateHeaders["If-Match"] = $getResp.Headers['ETag']
$updateBody = @{
    settings = $currentSettings
} | ConvertTo-Json -Depth 5

$updateRes = Invoke-RestMethod -Uri "$baseUrl/api/v1/me/settings" -Method Put -Headers $updateHeaders -Body $updateBody -UseBasicParsing
Write-Host "  OK - Settings updated"

# 6. Generate again (should NOT return followup - all required settings present)
Write-Host ""
Write-Host "[6] Generate with all settings (should NOT return followup)..." -ForegroundColor Yellow
$headers["Idempotency-Key"] = "test-followup-003"

try {
    $res = Invoke-RestMethod -Uri "$baseUrl/api/v1/generate" -Method Post -Headers $headers -Body $body -UseBasicParsing
    
    if ($res.followup) {
        Write-Host "  FAIL - Followup returned but shouldn't (key: $($res.followup.key))" -ForegroundColor Red
        exit 1
    } else {
        Write-Host "  OK - No followup returned (all settings present)" -ForegroundColor Green
    }
    
    if ($res.candidates.Count -eq 3) {
        Write-Host "  [OK] A/B/C candidates returned" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Expected 3 candidates" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "  FAIL - $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "All Followup Tests Passed" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
