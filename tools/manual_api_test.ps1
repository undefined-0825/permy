# manual_api_test.ps1
# Backend API Manual Validation Script

$ErrorActionPreference = "Stop"
$baseUrl = "http://localhost:8000"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Backend API Manual Test Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

function Invoke-ApiTest {
    param(
        [string]$TestName,
        [string]$Method,
        [string]$Endpoint,
        [hashtable]$Headers = @{},
        [object]$Body = $null,
        [int]$ExpectedStatus = 200
    )
    
    Write-Host "[$TestName]" -ForegroundColor Yellow
    Write-Host "  Method: $Method $Endpoint"
    
    $params = @{
        Uri = "$baseUrl$Endpoint"
        Method = $Method
        Headers = $Headers
        ContentType = "application/json"
    }
    
    if ($Body) {
        $params.Body = ($Body | ConvertTo-Json -Depth 10)
        Write-Host "  Body: $($params.Body)" -ForegroundColor DarkGray
    }
    
    try {
        $response = Invoke-WebRequest @params
        $statusCode = $response.StatusCode
        $content = $response.Content | ConvertFrom-Json
        
        if ($statusCode -eq $ExpectedStatus) {
            Write-Host "  OK - Status: $statusCode (Expected: $ExpectedStatus)" -ForegroundColor Green
            Write-Host "  Response: $($response.Content)" -ForegroundColor DarkGray
            return @{
                Success = $true
                StatusCode = $statusCode
                Content = $content
            }
        } else {
            Write-Host "  FAIL - Status: $statusCode (Expected: $ExpectedStatus)" -ForegroundColor Red
            return @{
                Success = $false
                StatusCode = $statusCode
                Content = $content
            }
        }
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $content = $null
        
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
        
        if ($statusCode -eq $ExpectedStatus) {
            Write-Host "  OK - Status: $statusCode (Expected: $ExpectedStatus)" -ForegroundColor Green
            Write-Host "  Response: $responseBody" -ForegroundColor DarkGray
            return @{
                Success = $true
                StatusCode = $statusCode
                Content = $content
            }
        } else {
            Write-Host "  FAIL - Status: $statusCode (Expected: $ExpectedStatus)" -ForegroundColor Red
            Write-Host "  Error: $responseBody" -ForegroundColor Red
            return @{
                Success = $false
                StatusCode = $statusCode
                Content = $content
            }
        }
    }
    finally {
        Write-Host ""
    }
}

# Check if server is running
try {
    $healthCheck = Invoke-WebRequest -Uri "$baseUrl/docs" -Method GET -TimeoutSec 5 -ErrorAction SilentlyContinue
    Write-Host "OK - Server is running at $baseUrl" -ForegroundColor Green
    Write-Host ""
}
catch {
    # Try root endpoint (may return 404 but server is up)
    try {
        $rootCheck = Invoke-WebRequest -Uri "$baseUrl/" -Method GET -TimeoutSec 5 -ErrorAction SilentlyContinue
        Write-Host "OK - Server is running at $baseUrl" -ForegroundColor Green
        Write-Host ""
    }
    catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 404) {
            Write-Host "OK - Server is running at $baseUrl (404 is OK)" -ForegroundColor Green
            Write-Host ""
        }
        else {
            Write-Host "ERROR - Server is not running at $baseUrl" -ForegroundColor Red
            Write-Host "  Please start server with .\start_fastapi.ps1 first" -ForegroundColor Yellow
            exit 1
        }
    }
}

# Test result counters
$totalTests = 0
$passedTests = 0
$failedTests = 0

# ========================================
# TC-01: Anonymous Auth
# ========================================
$totalTests++
$result = Invoke-ApiTest `
    -TestName "TC-01: Anonymous Auth" `
    -Method "POST" `
    -Endpoint "/api/v1/auth/anonymous" `
    -ExpectedStatus 200

if ($result.Success -and $result.Content.access_token) {
    $token = $result.Content.access_token
    Write-Host "  OK - Got access_token: $($token.Substring(0, [Math]::Min(20, $token.Length)))..." -ForegroundColor Green
    $passedTests++
} else {
    Write-Host "  FAIL - Could not get access_token" -ForegroundColor Red
    $failedTests++
    exit 1
}

# ========================================
# TC-02: Get Settings (initial)
# ========================================
$totalTests++
$result = Invoke-ApiTest `
    -TestName "TC-02: Get Settings (initial)" `
    -Method "GET" `
    -Endpoint "/api/v1/me/settings" `
    -Headers @{ "Authorization" = "Bearer $token" } `
    -ExpectedStatus 200

if ($result.Success -and $result.Content.settings) {
    Write-Host "  OK - settings received" -ForegroundColor Green
    # Get ETag from response headers
    $settingsResp = Invoke-WebRequest -Uri "http://localhost:8000/api/v1/me/settings" -Method GET -Headers @{ "Authorization" = "Bearer $token" }
    $etag = $settingsResp.Headers["ETag"]
    if ($etag) {
        Write-Host "  OK - etag: $etag" -ForegroundColor Green
    }
    $passedTests++
} else {
    Write-Host "  FAIL - Could not get settings" -ForegroundColor Red
    $failedTests++
}

# ========================================
# TC-03: Update Settings
# ========================================
$totalTests++
$updateSettings = @{
    settings = @{
        settings_schema_version = 1
        persona_version = 2
        true_self_type = "honest"
        night_self_type = "professional"
        relationship_type = "customer_regular"
        reply_length_pref = "medium"
        ng_tags = @("violence", "politics")
        ng_free_phrases = @("test_ng_phrase_1", "test_ng_phrase_2")
    }
}

$headers = @{
    "Authorization" = "Bearer $token"
}

if ($etag) {
    $headers["If-Match"] = $etag
}

$result = Invoke-ApiTest `
    -TestName "TC-03: Update Settings" `
    -Method "PUT" `
    -Endpoint "/api/v1/me/settings" `
    -Headers $headers `
    -Body $updateSettings `
    -ExpectedStatus 200

if ($result.Success) {
    Write-Host "  OK - Settings updated" -ForegroundColor Green
    $passedTests++
    
    # Verify update
    $totalTests++
    $result = Invoke-ApiTest `
        -TestName "TC-03b: Verify Update" `
        -Method "GET" `
        -Endpoint "/api/v1/me/settings" `
        -Headers @{ "Authorization" = "Bearer $token" } `
        -ExpectedStatus 200
    
    if ($result.Success -and $result.Content.settings.true_self_type -eq "honest") {
        Write-Host "  OK - Updated values verified" -ForegroundColor Green
        $passedTests++
    } else {
        Write-Host "  FAIL - Updated values not verified" -ForegroundColor Red
        $failedTests++
    }
} else {
    Write-Host "  FAIL - Settings update failed" -ForegroundColor Red
    $failedTests++
}

# ========================================
# TC-04: Settings Validation (enum invalid)
# ========================================
$totalTests++
$invalidSettings = @{
    settings = @{
        true_self_type = "UnknownX"
    }
}

$result = Invoke-ApiTest `
    -TestName "TC-04: Settings Validation (enum invalid)" `
    -Method "PUT" `
    -Endpoint "/api/v1/me/settings" `
    -Headers @{ "Authorization" = "Bearer $token" } `
    -Body $invalidSettings `
    -ExpectedStatus 422

if ($result.Success) {
    Write-Host "  OK - Invalid value rejected correctly" -ForegroundColor Green
    $passedTests++
} else {
    Write-Host "  FAIL - Invalid value not rejected" -ForegroundColor Red
    $failedTests++
}

# ========================================
# TC-05: Generate (OPENAI_DISABLED=true)
# ========================================
$totalTests++
$generateRequest = @{
    history_text = "User: Hello`nShop: Thank you`nUser: See you again"
    combo_id = 0
}

$result = Invoke-ApiTest `
    -TestName "TC-05: Generate (OPENAI_DISABLED=true)" `
    -Method "POST" `
    -Endpoint "/api/v1/generate" `
    -Headers @{ "Authorization" = "Bearer $token" } `
    -Body $generateRequest `
    -ExpectedStatus 200

if ($result.Success -and $result.Content.candidates) {
    Write-Host "  OK - Generate succeeded" -ForegroundColor Green
    Write-Host "  Candidates count: $($result.Content.candidates.Count)" -ForegroundColor Green
    if ($result.Content.model_hint) {
        Write-Host "  model_hint: $($result.Content.model_hint)" -ForegroundColor Green
    }
    $passedTests++
} else {
    Write-Host "  FAIL - Generate failed" -ForegroundColor Red
    $failedTests++
}

# ========================================
# Test Result Summary
# ========================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Result Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Tests: $totalTests"
Write-Host "Passed: $passedTests" -ForegroundColor Green
Write-Host "Failed: $failedTests" -ForegroundColor Red
Write-Host ""

if ($failedTests -eq 0) {
    Write-Host "OK - All tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "FAILED - Some tests failed." -ForegroundColor Red
    exit 1
}
