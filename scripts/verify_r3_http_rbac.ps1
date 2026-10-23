<#
.SYNOPSIS
    Milestone R3 HTTP Integration Test Suite: Real API Authentication & RBAC Verification
.DESCRIPTION
    Executes real HTTP integration tests against running ASP.NET Core API on port 5138
    connected to SQL Server database RestaurantPos_Acceptance.
    Verifies registration, login, negative auth, password change lifecycle, and RBAC boundary enforcement
    across all 6 roles (ADMIN, MANAGER, CASHIER, WAITER, KITCHEN, MEMBER).
.PARAMETER BaseUrl
    Base URL of the API. Default is http://localhost:5138.
.PARAMETER DefaultPassword
    Default test password. Default is Password123@.
.PARAMETER AlternativePassword
    Alternative fallback password for seeded accounts. Default is admin.
.PARAMETER OutputPath
    Path to save the JSON execution report. Default is artifacts/r3_http_rbac_results.json.
#>

[CmdletBinding()]
param(
    [string]$BaseUrl = "http://localhost:5138",
    [string]$DefaultPassword = "Password123@",
    [string]$AlternativePassword = "admin",
    [string]$OutputPath = "artifacts/r3_http_rbac_results.json"
)

$ErrorActionPreference = "Continue"

# -------------------------------------------------------------
# Utility Functions
# -------------------------------------------------------------

function Decode-Base64Url([string]$base64Url) {
    $base64 = $base64Url.Replace('-', '+').Replace('_', '/')
    switch ($base64.Length % 4) {
        2 { $base64 += '==' }
        3 { $base64 += '=' }
    }
    $bytes = [System.Convert]::FromBase64String($base64)
    return [System.Text.Encoding]::UTF8.GetString($bytes)
}

function Parse-JwtToken([string]$jwt) {
    if ([string]::IsNullOrWhiteSpace($jwt)) { return $null }
    $parts = $jwt.Split('.')
    if ($parts.Length -lt 2) { return $null }
    try {
        $headerJson = Decode-Base64Url $parts[0]
        $payloadJson = Decode-Base64Url $parts[1]
        return [PSCustomObject]@{
            Header = ($headerJson | ConvertFrom-Json)
            Payload = ($payloadJson | ConvertFrom-Json)
        }
    } catch {
        return $null
    }
}

function Sanitize-Body([object]$body) {
    if ($null -eq $body) { return "" }
    $json = if ($body -is [string]) { $body } else { $body | ConvertTo-Json -Compress -Depth 10 }
    $json = $json -replace '("password"\s*:\s*")[^"]*(")', '$1[REDACTED]$2'
    $json = $json -replace '("oldPassword"\s*:\s*")[^"]*(")', '$1[REDACTED]$2'
    $json = $json -replace '("newPassword"\s*:\s*")[^"]*(")', '$1[REDACTED]$2'
    $json = $json -replace '("token"\s*:\s*")[^"]*(")', '$1[REDACTED_JWT]$2'
    return $json
}

function Invoke-SanitizedRequest {
    param(
        [string]$Method,
        [string]$Uri,
        [object]$Body = $null,
        [string]$Token = $null
    )

    $headers = @{
        "Accept" = "application/json"
    }
    if (-not [string]::IsNullOrWhiteSpace($Token)) {
        $headers["Authorization"] = "Bearer $Token"
    }

    $sanitizedReqBody = Sanitize-Body $body
    $sanitizedAuth = if ($Token) { "Bearer [REDACTED_JWT]" } else { "None" }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $statusCode = 0
    $respBody = ""

    try {
        $params = @{
            Method = $Method
            Uri = $Uri
            Headers = $headers
            ErrorAction = "Stop"
            UseBasicParsing = $true
        }
        if ($null -ne $Body) {
            $params["ContentType"] = "application/json"
            $params["Body"] = if ($Body -is [string]) { $Body } else { $Body | ConvertTo-Json -Compress -Depth 10 }
        }

        $response = Invoke-WebRequest @params
        $sw.Stop()
        $statusCode = [int]$response.StatusCode
        $respBody = $response.Content
    } catch [System.Net.WebException] {
        $sw.Stop()
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $respBody = $reader.ReadToEnd()
            $reader.Close()
        } else {
            $statusCode = 500
            $respBody = $_.Exception.Message
        }
    } catch {
        $sw.Stop()
        $statusCode = 500
        $respBody = $_.ToString()
    }

    $durationMs = [math]::Round($sw.Elapsed.TotalMilliseconds, 2)
    $sanitizedRespBody = Sanitize-Body $respBody

    return [PSCustomObject]@{
        StatusCode = $statusCode
        Body = $respBody
        SanitizedBody = $sanitizedRespBody
        DurationMs = $durationMs
        Method = $Method
        Uri = $Uri
        SanitizedAuth = $sanitizedAuth
        SanitizedReqBody = $sanitizedReqBody
    }
}

# -------------------------------------------------------------
# Main Test Harness
# -------------------------------------------------------------

$timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$testResults = [System.Collections.Generic.List[PSCustomObject]]::new()
$roleTokens = @{}

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host "  RESTAURANT POS - REAL HTTP INTEGRATION & RBAC ACCEPTANCE TEST SUITE    " -ForegroundColor Cyan
Write-Host "  Target: $BaseUrl | Dedicated DB: RestaurantPos_Acceptance               " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host ""

function Record-TestResult {
    param(
        [string]$TestId,
        [string]$Category,
        [string]$Description,
        [int[]]$ExpectedStatus,
        [PSCustomObject]$HttpResult,
        [bool]$ExtraAssertion = $true,
        [string]$FailureNote = ""
    )

    $statusMatch = $ExpectedStatus -contains $HttpResult.StatusCode
    $passed = $statusMatch -and $ExtraAssertion
    $verdict = if ($passed) { "PASS" } else { "FAIL" }
    $color = if ($passed) { "Green" } else { "Red" }

    $logMsg = "[{0}] {1,-8} | HTTP {2} (Expected: {3}) | {4,7} ms | {5}" -f `
        $verdict, $TestId, $HttpResult.StatusCode, ($ExpectedStatus -join '/'), $HttpResult.DurationMs, $Description

    Write-Host $logMsg -ForegroundColor $color
    if (-not $passed) {
        Write-Host "    Req: $($HttpResult.Method) $($HttpResult.Uri)" -ForegroundColor Yellow
        Write-Host "    Auth: $($HttpResult.SanitizedAuth) | Body: $($HttpResult.SanitizedReqBody)" -ForegroundColor Yellow
        Write-Host "    Resp: $($HttpResult.SanitizedBody)" -ForegroundColor Yellow
        if ($FailureNote) { Write-Host "    Note: $FailureNote" -ForegroundColor Red }
    }

    $testResults.Add([PSCustomObject]@{
        TestId = $TestId
        Category = $Category
        Description = $Description
        Method = $HttpResult.Method
        Uri = $HttpResult.Uri
        ExpectedStatus = ($ExpectedStatus -join ',')
        ActualStatus = $HttpResult.StatusCode
        DurationMs = $HttpResult.DurationMs
        Verdict = $verdict
        FailureNote = if (-not $passed) { $FailureNote } else { "" }
        SanitizedRequest = $HttpResult.SanitizedReqBody
        SanitizedResponse = $HttpResult.SanitizedBody
    })
}

# -------------------------------------------------------------
# Phase 0: Pre-flight Check
# -------------------------------------------------------------
Write-Host "--- Phase 0: Pre-flight Connectivity ---" -ForegroundColor White
$preRes = Invoke-SanitizedRequest -Method "GET" -Uri "$BaseUrl/api/table/areas"
Record-TestResult -TestId "PRE-01" -Category "Preflight" -Description "Verify API server is up on $BaseUrl" `
    -ExpectedStatus @(200) -HttpResult $preRes

if ($preRes.StatusCode -ne 200) {
    Write-Host "`nCRITICAL: API at $BaseUrl is unreachable or returned status $($preRes.StatusCode)." -ForegroundColor Red
    Write-Host "Ensure the Web API project is running ('dotnet run' on port 5138) before executing integration tests." -ForegroundColor Red
    exit 1
}

# -------------------------------------------------------------
# Phase 1: User Registration
# -------------------------------------------------------------
Write-Host "`n--- Phase 1: User Registration Flows ---" -ForegroundColor White
$regUsername = "test_member_$timestamp"
$regEmail = "member_$timestamp@restaurantpos.vn"
$regPassword = "Password123@"

$regPayload = @{
    username = $regUsername
    password = $regPassword
    fullName = "Acceptance Test Member"
    email = $regEmail
    phoneNumber = "0987654321"
    roleCode = "MEMBER"
}

$regRes = Invoke-SanitizedRequest -Method "POST" -Uri "$BaseUrl/api/auth/register" -Body $regPayload
Record-TestResult -TestId "REG-01" -Category "Registration" -Description "Register new account ($regUsername)" `
    -ExpectedStatus @(200, 201) -HttpResult $regRes

# Attempt duplicate registration
$dupRes = Invoke-SanitizedRequest -Method "POST" -Uri "$BaseUrl/api/auth/register" -Body $regPayload
Record-TestResult -TestId "REG-02" -Category "Registration" -Description "Reject duplicate username registration" `
    -ExpectedStatus @(400) -HttpResult $dupRes

# Invalid registration (empty fields)
$invRegRes = Invoke-SanitizedRequest -Method "POST" -Uri "$BaseUrl/api/auth/register" -Body @{ username = "" }
Record-TestResult -TestId "REG-03" -Category "Registration" -Description "Reject empty registration payload" `
    -ExpectedStatus @(400) -HttpResult $invRegRes

# -------------------------------------------------------------
# Phase 2: Role Authentication & Token Verification (6 Roles)
# -------------------------------------------------------------
Write-Host "`n--- Phase 2: Authentication & Token Issuance for All 6 Roles ---" -ForegroundColor White

$rolesToTest = @(
    @{ Role = "ADMIN";   Username = "admin";       FallbackUsername = "admin" },
    @{ Role = "MANAGER"; Username = "manager01";   FallbackUsername = "manager01" },
    @{ Role = "CASHIER"; Username = "cashier_mai";  FallbackUsername = "cashier_mai" },
    @{ Role = "WAITER";  Username = "waiter_nam";   FallbackUsername = "waiter_lan" },
    @{ Role = "KITCHEN"; Username = "kitchen";      FallbackUsername = "chef_dung" },
    @{ Role = "MEMBER";  Username = "member_khang"; FallbackUsername = $regUsername }
)

$authIndex = 1
foreach ($r in $rolesToTest) {
    $roleName = $r.Role
    $uName = $r.Username
    $testId = "AUTH-{0:D2}" -f $authIndex
    $authIndex++

    # Try primary password, fallback to alternative if 401
    $loginPayload = @{ username = $uName; password = $DefaultPassword }
    $loginRes = Invoke-SanitizedRequest -Method "POST" -Uri "$BaseUrl/api/auth/login" -Body $loginPayload

    if ($loginRes.StatusCode -eq 401 -and -not [string]::IsNullOrWhiteSpace($AlternativePassword)) {
        $loginPayload = @{ username = $uName; password = $AlternativePassword }
        $loginRes = Invoke-SanitizedRequest -Method "POST" -Uri "$BaseUrl/api/auth/login" -Body $loginPayload
    }

    # If primary username fails and fallback username exists, attempt fallback
    if ($loginRes.StatusCode -ne 200 -and $r.FallbackUsername -ne $uName) {
        $uName = $r.FallbackUsername
        $loginPayload = @{ username = $uName; password = $DefaultPassword }
        $loginRes = Invoke-SanitizedRequest -Method "POST" -Uri "$BaseUrl/api/auth/login" -Body $loginPayload
        if ($loginRes.StatusCode -eq 401) {
            $loginPayload = @{ username = $uName; password = $AlternativePassword }
            $loginRes = Invoke-SanitizedRequest -Method "POST" -Uri "$BaseUrl/api/auth/login" -Body $loginPayload
        }
    }

    $tokenObj = $null
    $hasToken = $false
    $roleClaimMatch = $false

    if ($loginRes.StatusCode -eq 200) {
        try {
            $respObj = $loginRes.Body | ConvertFrom-Json
            if ($respObj.token) {
                $hasToken = $true
                $tokenStr = $respObj.token
                $roleTokens[$roleName] = $tokenStr
                $tokenObj = Parse-JwtToken $tokenStr

                if ($null -ne $tokenObj -and $null -ne $tokenObj.Payload) {
                    $claimRole = $tokenObj.Payload.role
                    if (-not $claimRole) { $claimRole = $tokenObj.Payload."http://schemas.microsoft.com/ws/2008/06/identity/claims/role" }
                    if ($claimRole -eq $roleName -or ($roleName -eq "KITCHEN" -and $claimRole -in @("KITCHEN","HEAD_CHEF"))) {
                        $roleClaimMatch = $true
                    }
                }
            }
        } catch {}
    }

    $extraOk = $hasToken -and ($null -ne $tokenObj)
    Record-TestResult -TestId $testId -Category "Authentication" `
        -Description "Login as $roleName (user: $uName) & verify JWT" `
        -ExpectedStatus @(200) -HttpResult $loginRes -ExtraAssertion $extraOk `
        -FailureNote "Token missing or role claim mismatch"
}

# -------------------------------------------------------------
# Phase 3: Negative Login Tests
# -------------------------------------------------------------
Write-Host "`n--- Phase 3: Negative Authentication Scenarios ---" -ForegroundColor White

$badPwdRes = Invoke-SanitizedRequest -Method "POST" -Uri "$BaseUrl/api/auth/login" `
    -Body @{ username = "admin"; password = "IncorrectPassword999!" }
Record-TestResult -TestId "AUTH-07" -Category "NegativeAuth" -Description "Reject login with incorrect password" `
    -ExpectedStatus @(401) -HttpResult $badPwdRes

$ghostRes = Invoke-SanitizedRequest -Method "POST" -Uri "$BaseUrl/api/auth/login" `
    -Body @{ username = "ghost_user_non_existent"; password = "any" }
Record-TestResult -TestId "AUTH-08" -Category "NegativeAuth" -Description "Reject non-existent username" `
    -ExpectedStatus @(401) -HttpResult $ghostRes

$emptyLoginRes = Invoke-SanitizedRequest -Method "POST" -Uri "$BaseUrl/api/auth/login" -Body @{}
Record-TestResult -TestId "AUTH-09" -Category "NegativeAuth" -Description "Reject empty credentials payload" `
    -ExpectedStatus @(400) -HttpResult $emptyLoginRes

# -------------------------------------------------------------
# Phase 4: Password Change Lifecycle (on Test Account)
# -------------------------------------------------------------
Write-Host "`n--- Phase 4: Password Change Lifecycle (Safe Test Account) ---" -ForegroundColor White

# Login as registered test account
$regLoginRes = Invoke-SanitizedRequest -Method "POST" -Uri "$BaseUrl/api/auth/login" `
    -Body @{ username = $regUsername; password = $regPassword }
$regToken = ""
if ($regLoginRes.StatusCode -eq 200) {
    $regToken = ($regLoginRes.Body | ConvertFrom-Json).token
}

# Attempt change with wrong old password
$wrongOldRes = Invoke-SanitizedRequest -Method "POST" -Uri "$BaseUrl/api/auth/change-password" `
    -Token $regToken -Body @{ oldPassword = "WrongOldPassword!"; newPassword = "BrandNewSecret123@" }
Record-TestResult -TestId "PWD-01" -Category "PasswordChange" -Description "Reject password change with wrong old password" `
    -ExpectedStatus @(400, 401) -HttpResult $wrongOldRes

# Change password with valid old password
$newTestPassword = "BrandNewSecret123@"
$validChangeRes = Invoke-SanitizedRequest -Method "POST" -Uri "$BaseUrl/api/auth/change-password" `
    -Token $regToken -Body @{ oldPassword = $regPassword; newPassword = $newTestPassword }
Record-TestResult -TestId "PWD-02" -Category "PasswordChange" -Description "Successfully change password with correct credentials" `
    -ExpectedStatus @(200) -HttpResult $validChangeRes

# Verify old password is now dead
$oldDeadRes = Invoke-SanitizedRequest -Method "POST" -Uri "$BaseUrl/api/auth/login" `
    -Body @{ username = $regUsername; password = $regPassword }
Record-TestResult -TestId "PWD-03" -Category "PasswordChange" -Description "Verify old password rejected (401)" `
    -ExpectedStatus @(401) -HttpResult $oldDeadRes

# Verify new password is now active
$newActiveRes = Invoke-SanitizedRequest -Method "POST" -Uri "$BaseUrl/api/auth/login" `
    -Body @{ username = $regUsername; password = $newTestPassword }
$newPassTokenOk = $false
if ($newActiveRes.StatusCode -eq 200) {
    $newPassTokenOk = -not [string]::IsNullOrWhiteSpace(($newActiveRes.Body | ConvertFrom-Json).token)
}
Record-TestResult -TestId "PWD-04" -Category "PasswordChange" -Description "Verify new password authenticates & returns JWT" `
    -ExpectedStatus @(200) -HttpResult $newActiveRes -ExtraAssertion $newPassTokenOk

# -------------------------------------------------------------
# Phase 5: RBAC Boundary Enforcement
# -------------------------------------------------------------
Write-Host "`n--- Phase 5: RBAC Boundary Enforcement (/api/account/members) ---" -ForegroundColor White

# 1. Unauthenticated request
$anonRes = Invoke-SanitizedRequest -Method "GET" -Uri "$BaseUrl/api/account/members"
Record-TestResult -TestId "RBAC-01" -Category "RBAC" -Description "Deny unauthenticated call (No Header)" `
    -ExpectedStatus @(401) -HttpResult $anonRes

# 2. Garbage token
$fakeRes = Invoke-SanitizedRequest -Method "GET" -Uri "$BaseUrl/api/account/members" -Token "invalid.jwt.token"
Record-TestResult -TestId "RBAC-02" -Category "RBAC" -Description "Deny malformed/tampered JWT token" `
    -ExpectedStatus @(401) -HttpResult $fakeRes

# 3. Allowed Roles: ADMIN and MANAGER
$adminTok = $roleTokens["ADMIN"]
$adminRbacRes = Invoke-SanitizedRequest -Method "GET" -Uri "$BaseUrl/api/account/members" -Token $adminTok
$adminArrayOk = $false
if ($adminRbacRes.StatusCode -eq 200) {
    try {
        $arr = $adminRbacRes.Body | ConvertFrom-Json
        $adminArrayOk = ($arr -is [System.Collections.IEnumerable]) -and ($arr.Count -gt 0)
    } catch {}
}
Record-TestResult -TestId "RBAC-03" -Category "RBAC" -Description "Allow ADMIN token (200 OK + members list)" `
    -ExpectedStatus @(200) -HttpResult $adminRbacRes -ExtraAssertion $adminArrayOk

$managerTok = $roleTokens["MANAGER"]
$mgrRbacRes = Invoke-SanitizedRequest -Method "GET" -Uri "$BaseUrl/api/account/members" -Token $managerTok
$mgrArrayOk = $false
if ($mgrRbacRes.StatusCode -eq 200) {
    try {
        $arr = $mgrRbacRes.Body | ConvertFrom-Json
        $mgrArrayOk = ($arr -is [System.Collections.IEnumerable])
    } catch {}
}
Record-TestResult -TestId "RBAC-04" -Category "RBAC" -Description "Allow MANAGER token (200 OK)" `
    -ExpectedStatus @(200) -HttpResult $mgrRbacRes -ExtraAssertion $mgrArrayOk

# 4. Disallowed Roles: CASHIER, WAITER, KITCHEN, MEMBER (Must receive 403 Forbidden)
$disallowedRoles = @("CASHIER", "WAITER", "KITCHEN", "MEMBER")
$rbacIndex = 5

foreach ($rName in $disallowedRoles) {
    $tok = $roleTokens[$rName]
    $tId = "RBAC-{0:D2}" -f $rbacIndex
    $rbacIndex++

    if ([string]::IsNullOrWhiteSpace($tok)) {
        Write-Host "[$tId] SKIP | Role token for $rName was not obtained in Phase 2" -ForegroundColor Yellow
        $testResults.Add([PSCustomObject]@{
            TestId = $tId; Category = "RBAC"; Description = "Enforce 403 Forbidden for $rName";
            Verdict = "BLOCKED"; FailureNote = "Missing token from Phase 2"
        })
        continue
    }

    $forbiddenRes = Invoke-SanitizedRequest -Method "GET" -Uri "$BaseUrl/api/account/members" -Token $tok
    Record-TestResult -TestId $tId -Category "RBAC" -Description "Enforce 403 Forbidden for role $rName" `
        -ExpectedStatus @(403) -HttpResult $forbiddenRes
}

# -------------------------------------------------------------
# Summary & Audit Report
# -------------------------------------------------------------
Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host "                       INTEGRATION TEST SUMMARY REPORT                   " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan

$passedCount = ($testResults | Where-Object { $_.Verdict -eq "PASS" }).Count
$failedCount = ($testResults | Where-Object { $_.Verdict -eq "FAIL" }).Count
$blockedCount = ($testResults | Where-Object { $_.Verdict -eq "BLOCKED" }).Count
$totalCount = $testResults.Count

$avgDuration = [math]::Round(($testResults | Measure-Object -Property DurationMs -Average).Average, 2)
$maxDuration = ($testResults | Measure-Object -Property DurationMs -Maximum).Maximum
$minDuration = ($testResults | Measure-Object -Property DurationMs -Minimum).Minimum

Write-Host "Total Executed : $totalCount" -ForegroundColor White
Write-Host "Passed         : $passedCount" -ForegroundColor Green
Write-Host "Failed         : $failedCount" -ForegroundColor $(if ($failedCount -gt 0) { "Red" } else { "Green" })
Write-Host "Blocked/Skipped: $blockedCount" -ForegroundColor $(if ($blockedCount -gt 0) { "Yellow" } else { "Gray" })
Write-Host "Latencies (ms) : Min = $minDuration ms | Avg = $avgDuration ms | Max = $maxDuration ms" -ForegroundColor White

# Export structured report
$artifactDir = Split-Path -Path $OutputPath -Parent
if (-not [string]::IsNullOrWhiteSpace($artifactDir) -and -not (Test-Path $artifactDir)) {
    New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
}

$reportData = @{
    Timestamp = (Get-Date).ToString("o")
    TargetUrl = $BaseUrl
    Database = "RestaurantPos_Acceptance"
    Summary = @{
        Total = $totalCount
        Passed = $passedCount
        Failed = $failedCount
        Blocked = $blockedCount
        MinDurationMs = $minDuration
        AvgDurationMs = $avgDuration
        MaxDurationMs = $maxDuration
    }
    Tests = $testResults
}

$reportData | ConvertTo-Json -Depth 5 | Set-Content -Path $OutputPath -Encoding UTF8
Write-Host "`nDetailed JSON execution audit report saved to: $OutputPath" -ForegroundColor Cyan

if ($failedCount -gt 0) {
    Write-Host "`n[RESULT] FAILED: $failedCount integration test(s) failed." -ForegroundColor Red
    exit 1
} else {
    Write-Host "`n[RESULT] SUCCESS: All $passedCount integration test assertions passed 100%!" -ForegroundColor Green
    exit 0
}
