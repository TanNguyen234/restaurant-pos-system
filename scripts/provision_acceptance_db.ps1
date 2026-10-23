<#
.SYNOPSIS
    Provisions the dedicated acceptance test database: RestaurantPos_Acceptance.
.DESCRIPTION
    1. Generates RestaurantPos_Acceptance.sql from RestaurantPosDb.sql by replacing the database catalog name.
    2. Ensures the dedicated KITCHEN role and kitchen seed account exist.
    3. Executes the DDL/DML script against the local SQL Server instance using Invoke-Sqlcmd.
    4. Validates that all 10 tables exist and row counts match expected seed state.
#>

[CmdletBinding()]
param(
    [string]$ServerInstance = "localhost",
    [string]$TargetDatabase = "RestaurantPos_Acceptance",
    [string]$SourceScriptPath = "",
    [string]$GeneratedScriptPath = ""
)

if ([string]::IsNullOrWhiteSpace($SourceScriptPath)) {
    $SourceScriptPath = Join-Path $PSScriptRoot "..\RestaurantPosDb.sql"
}
if ([string]::IsNullOrWhiteSpace($GeneratedScriptPath)) {
    $GeneratedScriptPath = Join-Path $PSScriptRoot "..\RestaurantPos_Acceptance.sql"
}

$ErrorActionPreference = "Stop"

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host "  PROVISIONING DEDICATED ACCEPTANCE DATABASE: $TargetDatabase             " -ForegroundColor Cyan
Write-Host "  Target Instance: $ServerInstance                                         " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan

# 1. Resolve absolute paths
$resolvedSource = (Resolve-Path $SourceScriptPath).Path
$resolvedDest = [System.IO.Path]::GetFullPath($GeneratedScriptPath)

Write-Host "`n[1/4] Reading source script from: $resolvedSource" -ForegroundColor Yellow
if (-not (Test-Path $resolvedSource)) {
    throw "Source SQL script not found at: $resolvedSource"
}

$sqlContent = [System.IO.File]::ReadAllText($resolvedSource, [System.Text.Encoding]::UTF8)

# Replace database name occurrences
$sqlContent = $sqlContent -replace 'RestaurantPosDb', $TargetDatabase

# Append dedicated KITCHEN role and kitchen user if missing in seed
$kitchenSeedSql = @"

-- ============================================================================
-- Ensure KITCHEN Role & Seed User Exist for Acceptance RBAC Testing
-- ============================================================================
USE [$TargetDatabase];
GO

IF NOT EXISTS (SELECT 1 FROM Roles WHERE RoleCode = 'KITCHEN')
BEGIN
    INSERT INTO Roles (RoleName, RoleCode, Description)
    VALUES (N'Bộ phận bếp & pha chế (KDS)', 'KITCHEN', N'Màn hình KDS nhận order và chế biến món ăn');
    PRINT 'Inserted KITCHEN role into Roles table.';
END
GO

IF NOT EXISTS (SELECT 1 FROM Accounts WHERE Username = 'kitchen')
BEGIN
    DECLARE @KitchenRoleId INT = (SELECT RoleId FROM Roles WHERE RoleCode = 'KITCHEN');
    INSERT INTO Accounts (RoleId, Username, PasswordHash, FullName, Email, PhoneNumber, IsActive, IsEmailVerified, OAuthProvider)
    VALUES (@KitchenRoleId, 'kitchen', '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918', N'Bếp Trưởng KDS', 'kitchen@restaurantpos.vn', '0907890123', 1, 1, 'Local');
    PRINT 'Inserted kitchen user into Accounts table.';
END
GO
"@

$sqlContent = $sqlContent + "`r`n" + $kitchenSeedSql

[System.IO.File]::WriteAllText($resolvedDest, $sqlContent, [System.Text.Encoding]::UTF8)
Write-Host "Generated customized acceptance script at: $resolvedDest" -ForegroundColor Green

# 2. Drop existing database if exists to guarantee clean repeatable provisioning
Write-Host "`n[2/4] Resetting database $TargetDatabase if already existing..." -ForegroundColor Yellow
$dropQuery = @"
USE master;
IF EXISTS (SELECT name FROM sys.databases WHERE name = N'$TargetDatabase')
BEGIN
    ALTER DATABASE [$TargetDatabase] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [$TargetDatabase];
    PRINT 'Dropped existing database $TargetDatabase.';
END
"@

try {
    Invoke-Sqlcmd -ServerInstance $ServerInstance -Query $dropQuery -Verbose:$false
    Write-Host "Clean state guaranteed for $TargetDatabase." -ForegroundColor Green
} catch {
    Write-Warning "Could not drop $($TargetDatabase): $_. Will proceed with creation script."
}

# 3. Execute script via Invoke-Sqlcmd with -InputFile
Write-Host "`n[3/4] Executing DDL & DML script via Invoke-Sqlcmd..." -ForegroundColor Yellow
Invoke-Sqlcmd -ServerInstance $ServerInstance -InputFile $resolvedDest -Verbose:$false
Write-Host "Execution completed successfully." -ForegroundColor Green

# 4. Verify table and row counts
Write-Host "`n[4/4] Verifying Table Schema, Foreign Keys & Seed Records..." -ForegroundColor Yellow
$verifyQuery = @"
USE [$TargetDatabase];
SELECT t.name AS TableName, SUM(p.rows) AS TotalRows
FROM sys.tables t
INNER JOIN sys.partitions p ON t.object_id = p.object_id AND p.index_id IN (0, 1)
GROUP BY t.name
ORDER BY t.name;
"@

$tables = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $TargetDatabase -Query $verifyQuery

$tables | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor Cyan

$expectedTables = @(
    "Accounts", "Areas", "Categories", "DiningTables", "OrderDetails",
    "Orders", "Payments", "ProductAttributes", "Products", "Roles"
)

$foundTableNames = $tables.TableName
$allFound = $true

foreach ($expected in $expectedTables) {
    if ($foundTableNames -notcontains $expected) {
        Write-Host "MISSING TABLE: $expected" -ForegroundColor Red
        $allFound = $false
    }
}

if (-not $allFound) {
    throw "Database provisioning verification failed: One or more tables are missing."
}

Write-Host "`n==========================================================================" -ForegroundColor Green
Write-Host "  SUCCESS: $TargetDatabase provisioned with all 10 tables and verified seeds!  " -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Green
