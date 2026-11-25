param(
    [string]$Target = ""
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BackendDir = Join-Path $ProjectRoot "backend"
$MobileDir = Join-Path $ProjectRoot "mobile"
$ApiHealthUrl = "http://localhost:5138/api/category"
$SwaggerUrl = "http://localhost:5138/swagger"
$WebUrl = "http://localhost:8088"

function Show-Usage {
    Write-Host ""
    Write-Host "=== RESTAURANT & CAFE POS - MO NHANH DU AN ===" -ForegroundColor Cyan
    Write-Host "Cach dung:"
    Write-Host "  start_project.bat              -> Mo menu lua chon che do"
    Write-Host "  start_project.bat chrome       -> Khoi dong Backend API + Flutter Web (Chrome :8088)"
    Write-Host "  start_project.bat windows      -> Khoi dong Backend API + Flutter Windows Desktop"
    Write-Host "  start_project.bat backend      -> Khoi dong Backend API (.NET :5138) + mo Swagger"
    Write-Host "  start_project.bat reset-db     -> Khoi phuc du lieu mau SQL Server (18 bang)"
    Write-Host "  start_project.bat stop         -> Dung tien trinh dang chay o cong 5138 & 8088"
    Write-Host "  start_project.bat help         -> Hien thi huong dan nay"
    Write-Host ""
    Write-Host "Tai khoan demo mac dinh (Mat khau tat ca: admin):" -ForegroundColor Yellow
    Write-Host "  admin | manager01 | cashier_mai | waiter_nam | chef_dung | kitchen | member_khang"
    Write-Host "Link thu QR Self-Order sau khi mo Web: $WebUrl/?tableId=2"
    Write-Host ""
}

function Ensure-EnvFiles {
    $pairs = @(
        @{ Example = (Join-Path $BackendDir ".env.example"); Target = (Join-Path $BackendDir ".env"); Name = "backend\.env" },
        @{ Example = (Join-Path $MobileDir ".env.example"); Target = (Join-Path $MobileDir ".env"); Name = "mobile\.env" }
    )
    foreach ($p in $pairs) {
        if (-not (Test-Path $p.Target) -and (Test-Path $p.Example)) {
            Copy-Item -Path $p.Example -Destination $p.Target
            Write-Host "[ENV] Da tao $($p.Name) tu file .env.example" -ForegroundColor Green
        }
    }
}

function Test-BackendHealthy {
    try {
        $resp = Invoke-WebRequest -Uri $ApiHealthUrl -UseBasicParsing -TimeoutSec 2
        return ($resp.StatusCode -eq 200)
    } catch {
        return $false
    }
}

function Start-BackendIfNeeded {
    $sqlSvc = Get-Service -Name 'MSSQL$SQLEXPRESS' -ErrorAction SilentlyContinue
    if ($null -eq $sqlSvc) {
        Write-Host "[DB] Khong tim thay service MSSQL`$SQLEXPRESS (bo qua neu dang dung SQL instance khac)." -ForegroundColor Yellow
    } elseif ($sqlSvc.Status -ne "Running") {
        Write-Host "[DB] Service MSSQL`$SQLEXPRESS dang o trang thai '$($sqlSvc.Status)'. Hay dam bao SQL Server dang chay!" -ForegroundColor Yellow
    }

    if (Test-BackendHealthy) {
        Write-Host "[API] Backend API da san sang tai http://localhost:5138" -ForegroundColor Green
        return
    }

    Write-Host "[API] Dang khoi dong Backend ASP.NET Core tai cua so moi (port 5138)..." -ForegroundColor Cyan
    $cmd = "Set-Location '$BackendDir'; `$env:ALLOWED_ORIGINS='http://localhost:8088,http://127.0.0.1:8088,http://localhost:5138'; dotnet run --project WebApi.csproj --urls 'http://localhost:5138'"
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoExit", "-Command", $cmd | Out-Null

    Write-Host "[API] Dang cho Backend san sang..." -NoNewline
    for ($i = 0; $i -lt 45; $i++) {
        Start-Sleep -Seconds 1
        if (Test-BackendHealthy) {
            Write-Host " OK!" -ForegroundColor Green
            return
        }
        Write-Host "." -NoNewline
    }
    Write-Host ""
    Write-Host "[CANH BAO] Backend chua phan hoi sau 45s. Vui long kiem tra cua so Backend PowerShell." -ForegroundColor Yellow
}

function Start-FlutterClient([string]$Device) {
    Ensure-EnvFiles
    Start-BackendIfNeeded

    if ($Device -eq "chrome") {
        Write-Host "[WEB] Dang khoi dong Flutter Web (Chrome port 8088)..." -ForegroundColor Cyan
        Write-Host "[TIP] Co the mo $WebUrl/?tableId=2 de test QR Self-Order tai ban." -ForegroundColor Gray
        $cmd = "Set-Location '$MobileDir'; flutter run -d chrome --web-port 8088"
        Start-Process -FilePath "powershell.exe" -ArgumentList "-NoExit", "-Command", $cmd | Out-Null
    } else {
        Write-Host "[DESKTOP] Dang khoi dong Flutter Windows Desktop..." -ForegroundColor Cyan
        $cmd = "Set-Location '$MobileDir'; flutter run -d windows"
        Start-Process -FilePath "powershell.exe" -ArgumentList "-NoExit", "-Command", $cmd | Out-Null
    }
}

function Reset-AcceptanceDb {
    $sqlFile = Join-Path $ProjectRoot "RestaurantPos_Acceptance.sql"
    if (-not (Test-Path $sqlFile)) {
        Write-Host "[LOI] Khong tim thay file $sqlFile" -ForegroundColor Red
        exit 1
    }
    Write-Host "[DB] Dang nap lai RestaurantPos_Acceptance.sql vao .\SQLEXPRESS..." -ForegroundColor Cyan
    Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -InputFile $sqlFile
    $counts = Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Database "RestaurantPos_Acceptance" -Query "SELECT (SELECT COUNT(*) FROM Areas) AS Areas, (SELECT COUNT(*) FROM DiningTables) AS Tables, (SELECT COUNT(*) FROM Products) AS Products, (SELECT COUNT(*) FROM Accounts) AS Accounts, (SELECT COUNT(*) FROM Ingredients) AS Ingredients, (SELECT COUNT(*) FROM ProductRecipes) AS Recipes"
    $counts | Format-Table -AutoSize
    Write-Host "[DB] Khoi phuc DB mau thanh cong!" -ForegroundColor Green
}

function Stop-ProjectProcesses {
    $conns = Get-NetTCPConnection -LocalPort 5138, 8088 -State Listen -ErrorAction SilentlyContinue
    if (-not $conns) {
        Write-Host "[STOP] Khong co tien trinh nao dang lang nghe o cong 5138 hoac 8088." -ForegroundColor Gray
        return
    }
    $pids = $conns | Select-Object -ExpandProperty OwningProcess -Unique
    foreach ($procId in $pids) {
        if ($procId -le 4) { continue }
        try {
            $proc = Get-Process -Id $procId -ErrorAction Stop
            Stop-Process -Id $procId -Force -ErrorAction Stop
            Write-Host "[STOP] Da dung $($proc.ProcessName) (PID $procId)" -ForegroundColor Green
        } catch {
            Write-Host "[STOP] Khong the dung PID ${procId}: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

$choice = $Target.Trim().ToLowerInvariant()
if ([string]::IsNullOrWhiteSpace($choice)) {
    Clear-Host
    Write-Host "=====================================================" -ForegroundColor Cyan
    Write-Host "   RESTAURANT & CAFE POS - TRINH KHOI DONG NHANH     " -ForegroundColor Cyan
    Write-Host "=====================================================" -ForegroundColor Cyan
    Write-Host "  [1] Chay Backend API + Flutter Web (Chrome :8088)  "
    Write-Host "  [2] Chay Backend API + Flutter Windows Desktop     "
    Write-Host "  [3] Chi chay Backend API (:5138) & mo Swagger      "
    Write-Host "  [4] Reset SQL Server DB mau (RestaurantPos_Acceptance)"
    Write-Host "  [5] Dung tat ca tien trinh Backend/Web (:5138,:8088)"
    Write-Host "  [6] Xem huong dan & Tai khoan Demo                 "
    Write-Host "  [0] Thoat                                          "
    Write-Host "=====================================================" -ForegroundColor Cyan
    $choice = (Read-Host "Nhap lua chon (mac dinh = 1)").Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($choice)) { $choice = "1" }
}

switch ($choice) {
    { $_ -in @("1", "chrome", "web") } {
        Start-FlutterClient "chrome"
    }
    { $_ -in @("2", "windows", "win", "desktop") } {
        Start-FlutterClient "windows"
    }
    { $_ -in @("3", "backend", "api", "swagger") } {
        Ensure-EnvFiles
        Start-BackendIfNeeded
        Start-Process $SwaggerUrl
    }
    { $_ -in @("4", "reset-db", "reset", "db") } {
        Reset-AcceptanceDb
    }
    { $_ -in @("5", "stop", "kill") } {
        Stop-ProjectProcesses
    }
    { $_ -in @("6", "help", "-h", "--help", "/?") } {
        Show-Usage
    }
    "0" {
        exit 0
    }
    default {
        Write-Host "[LOI] Tham so khong hop le: '$choice'" -ForegroundColor Red
        Show-Usage
        exit 1
    }
}
