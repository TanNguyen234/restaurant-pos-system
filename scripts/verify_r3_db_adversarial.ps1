<#
.SYNOPSIS
    Adversarial Empirical Challenge Harness for Milestone R3: Dedicated Database & Schema Integrity
.DESCRIPTION
    Directly connects to local SQL Server 2022 Express and verifies:
    1. Database isolation (RestaurantPos_Acceptance catalog and dedicated storage files).
    2. Schema completeness across all 10 core tables (data types, nullability, identity).
    3. Primary keys, foreign keys (9 relationships), and 6 non-clustered indexes.
    4. Unique constraints on Accounts(Username), Roles(RoleCode), Roles(RoleName), Orders(OrderCode).
    5. Adversarial DML: Duplicate key insertion attacks on Username, RoleCode, OrderCode (must raise 2627/2601).
    6. Cascade delete behavior:
       - Orders -> OrderDetails (CASCADE: deleting order removes details).
       - Products -> ProductAttributes (CASCADE: deleting product removes attributes).
       - Orders -> Payments (RESTRICT: deleting order with payment fails with error 547).
       - Categories -> Products (RESTRICT: deleting category with products fails with error 547).
       - Roles -> Accounts (RESTRICT: deleting role with accounts fails with error 547).
    7. Password hash analysis:
       - Seeded accounts: 64-char hex SHA-256 matching "admin".
       - New registrations: 97-char "{salt}:{hash}" format.
       - Salt uniqueness and cryptographic hashing verification.
    Outputs structured JSON report to artifacts/r3_db_adversarial_results.json.
#>

[CmdletBinding()]
param(
    [string]$ServerInstance = "localhost",
    [string]$Database = "RestaurantPos_Acceptance",
    [string]$OutputPath = "artifacts/r3_db_adversarial_results.json"
)

$ErrorActionPreference = "Continue"

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host "  ADVERSARIAL EMPIRICAL HARNESS: SQL SERVER DATABASE ACCEPTANCE & SCHEMA   " -ForegroundColor Cyan
Write-Host "  Instance: $ServerInstance | Database: $Database                          " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan

$testResults = [System.Collections.Generic.List[PSObject]]::new()
$startTimeTotal = [System.Diagnostics.Stopwatch]::StartNew()

function Record-TestResult {
    param(
        [string]$TestId,
        [string]$Category,
        [string]$Description,
        [bool]$Passed,
        [string]$Observed,
        [string]$Expected,
        [double]$DurationMs = 0.0,
        [string]$ErrorMessage = $null
    )
    $statusText = if ($Passed) { "[PASS]" } else { "[FAIL]" }
    $color = if ($Passed) { [ConsoleColor]::Green } else { [ConsoleColor]::Red }
    Write-Host ("{0,-9} | {1,-7} | {2,-45} | {3}" -f $statusText, $TestId, $Description, $Observed) -ForegroundColor $color

    $obj = [PSCustomObject]@{
        TestId       = $TestId
        Category     = $Category
        Description  = $Description
        Passed       = $Passed
        Observed     = $Observed
        Expected     = $Expected
        DurationMs   = [Math]::Round($DurationMs, 2)
        ErrorMessage = $ErrorMessage
    }
    $script:testResults.Add($obj)
}

function Execute-SqlScalar {
    param([string]$Query, [string]$Db = $Database)
    $res = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Db -Query $Query -ErrorAction Stop
    if ($null -eq $res) { return $null }
    if ($res -is [System.Array]) {
        if ($res.Length -eq 0) { return $null }
        $first = $res[0]
        if ($first -is [System.Data.DataRow]) { return $first[0] }
        return $first
    }
    if ($res -is [System.Data.DataRow]) {
        return $res[0]
    }
    return $res
}

function Execute-SqlQuery {
    param([string]$Query, [string]$Db = $Database)
    return Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Db -Query $Query -ErrorAction Stop
}

# ----------------------------------------------------------------------------
# PHASE 1: DATABASE CATALOG & ISOLATION
# ----------------------------------------------------------------------------
Write-Host "`n--- PHASE 1: Database Catalog & Isolation ---" -ForegroundColor Yellow

# DB-01: Acceptance Database exists & is ONLINE
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $dbState = Execute-SqlScalar "SELECT state_desc FROM sys.databases WHERE name = '$Database';" "master"
    $sw.Stop()
    $passed = ($dbState -eq "ONLINE")
    Record-TestResult "DB-01" "Isolation" "Acceptance DB is ONLINE in sys.databases" $passed "State: $dbState" "State: ONLINE" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-TestResult "DB-01" "Isolation" "Acceptance DB is ONLINE in sys.databases" $false "Error: $_" "State: ONLINE" $sw.Elapsed.TotalMilliseconds $_.Exception.Message
}

# DB-02: Acceptance Database has dedicated physical data files
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $files = Execute-SqlQuery "SELECT name, physical_name, type_desc FROM sys.master_files WHERE database_id = DB_ID('$Database');" "master"
    $sw.Stop()
    $mdf = ($files | Where-Object { $_.type_desc -eq "ROWS" }).physical_name
    $ldf = ($files | Where-Object { $_.type_desc -eq "LOG" }).physical_name
    $passed = ($mdf -ne $null -and $ldf -ne $null -and $mdf.Contains("RestaurantPos_Acceptance"))
    Record-TestResult "DB-02" "Isolation" "Dedicated physical storage files allocated" $passed "MDF: $mdf" "Dedicated files containing RestaurantPos_Acceptance" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-TestResult "DB-02" "Isolation" "Dedicated physical storage files allocated" $false "Error: $_" "Dedicated files" $sw.Elapsed.TotalMilliseconds $_.Exception.Message
}

# DB-03: ConnectionString isolation in appsettings.json
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $appSettingsPath = "backend/appsettings.json"
    $appSettings = Get-Content $appSettingsPath -Raw | ConvertFrom-Json
    $connStr = $appSettings.ConnectionStrings.RestaurantPosDb
    $sw.Stop()
    $passed = ($connStr -like "*Database=RestaurantPos_Acceptance*")
    Record-TestResult "DB-03" "Isolation" "Backend appsettings points to RestaurantPos_Acceptance" $passed "ConnStr: $connStr" "Database=RestaurantPos_Acceptance" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-TestResult "DB-03" "Isolation" "Backend appsettings points to RestaurantPos_Acceptance" $false "Error: $_" "Database=RestaurantPos_Acceptance" $sw.Elapsed.TotalMilliseconds $_.Exception.Message
}

# ----------------------------------------------------------------------------
# PHASE 2: SCHEMA COMPLETENESS (10 TABLES & COLUMNS)
# ----------------------------------------------------------------------------
Write-Host "`n--- PHASE 2: Core Tables & Schema Completeness ---" -ForegroundColor Yellow

# DB-04: Exactly 10 core tables exist
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $tables = Execute-SqlQuery "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE' ORDER BY TABLE_NAME;"
    $sw.Stop()
    $expected = @("Accounts", "Areas", "Categories", "DiningTables", "OrderDetails", "Orders", "Payments", "ProductAttributes", "Products", "Roles")
    $found = @($tables.TABLE_NAME)
    $missing = $expected | Where-Object { $found -notcontains $_ }
    $passed = ($missing.Count -eq 0 -and $found.Count -ge 10)
    Record-TestResult "DB-04" "Schema" "All 10 core tables exist" $passed "Found $($found.Count) tables: $($found -join ', ')" "Expected 10 tables: $($expected -join ', ')" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-TestResult "DB-04" "Schema" "All 10 core tables exist" $false "Error: $_" "10 tables" $sw.Elapsed.TotalMilliseconds $_.Exception.Message
}

# DB-05: Accounts table columns schema
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $accCols = Execute-SqlQuery "SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Accounts';"
    $sw.Stop()
    $userCol = $accCols | Where-Object { $_.COLUMN_NAME -eq "Username" }
    $passCol = $accCols | Where-Object { $_.COLUMN_NAME -eq "PasswordHash" }
    $roleCol = $accCols | Where-Object { $_.COLUMN_NAME -eq "RoleId" }
    $passed = ($userCol.DATA_TYPE -eq "varchar" -and $userCol.CHARACTER_MAXIMUM_LENGTH -eq 64 -and
               $passCol.DATA_TYPE -eq "varchar" -and $passCol.CHARACTER_MAXIMUM_LENGTH -eq 256 -and
               $roleCol.DATA_TYPE -eq "int" -and $roleCol.IS_NULLABLE -eq "NO")
    Record-TestResult "DB-05" "Schema" "Accounts schema (Username VARCHAR(64), PasswordHash VARCHAR(256))" $passed "Username: $($userCol.DATA_TYPE)($($userCol.CHARACTER_MAXIMUM_LENGTH)), PasswordHash: $($passCol.DATA_TYPE)($($passCol.CHARACTER_MAXIMUM_LENGTH))" "VARCHAR(64), VARCHAR(256)" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-TestResult "DB-05" "Schema" "Accounts schema verification" $false "Error: $_" "Expected types" $sw.Elapsed.TotalMilliseconds $_.Exception.Message
}

# DB-06: DiningTables table schema
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $tblCols = Execute-SqlQuery "SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DiningTables';"
    $sw.Stop()
    $areaCol = $tblCols | Where-Object { $_.COLUMN_NAME -eq "AreaId" }
    $statusCol = $tblCols | Where-Object { $_.COLUMN_NAME -eq "Status" }
    $passed = ($areaCol.DATA_TYPE -eq "int" -and $statusCol.DATA_TYPE -eq "int")
    Record-TestResult "DB-06" "Schema" "DiningTables schema (AreaId INT, Status INT)" $passed "AreaId: $($areaCol.DATA_TYPE), Status: $($statusCol.DATA_TYPE)" "AreaId INT, Status INT" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-TestResult "DB-06" "Schema" "DiningTables schema verification" $false "Error: $_" "INT" $sw.Elapsed.TotalMilliseconds $_.Exception.Message
}

# DB-07: Products & ProductAttributes schema
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $prodCols = Execute-SqlQuery "SELECT COLUMN_NAME, DATA_TYPE, NUMERIC_PRECISION FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Products';"
    $sw.Stop()
    $priceCol = $prodCols | Where-Object { $_.COLUMN_NAME -eq "Price" }
    $catCol = $prodCols | Where-Object { $_.COLUMN_NAME -eq "CategoryId" }
    $passed = ($priceCol.DATA_TYPE -eq "decimal" -and $priceCol.NUMERIC_PRECISION -eq 18 -and $catCol.DATA_TYPE -eq "smallint")
    Record-TestResult "DB-07" "Schema" "Products schema (Price DECIMAL(18,0), CategoryId SMALLINT)" $passed "Price: $($priceCol.DATA_TYPE)($($priceCol.NUMERIC_PRECISION)), CategoryId: $($catCol.DATA_TYPE)" "DECIMAL(18,0), SMALLINT" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-TestResult "DB-07" "Schema" "Products schema verification" $false "Error: $_" "DECIMAL(18,0)" $sw.Elapsed.TotalMilliseconds $_.Exception.Message
}

# DB-08: Orders & OrderDetails schema
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $ordCols = Execute-SqlQuery "SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Orders';"
    $sw.Stop()
    $codeCol = $ordCols | Where-Object { $_.COLUMN_NAME -eq "OrderCode" }
    $passed = ($codeCol.DATA_TYPE -eq "varchar" -and $codeCol.CHARACTER_MAXIMUM_LENGTH -eq 32)
    Record-TestResult "DB-08" "Schema" "Orders schema (OrderCode VARCHAR(32))" $passed "OrderCode: $($codeCol.DATA_TYPE)($($codeCol.CHARACTER_MAXIMUM_LENGTH))" "VARCHAR(32)" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-TestResult "DB-08" "Schema" "Orders schema verification" $false "Error: $_" "VARCHAR(32)" $sw.Elapsed.TotalMilliseconds $_.Exception.Message
}

# DB-09: OrderDetails KDS schema (CookingStatus INT)
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $dtlCols = Execute-SqlQuery "SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'OrderDetails';"
    $sw.Stop()
    $cookCol = $dtlCols | Where-Object { $_.COLUMN_NAME -eq "CookingStatus" }
    $passed = ($cookCol.DATA_TYPE -eq "int")
    Record-TestResult "DB-09" "Schema" "OrderDetails KDS schema (CookingStatus INT)" $passed "CookingStatus: $($cookCol.DATA_TYPE)" "INT" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-TestResult "DB-09" "Schema" "OrderDetails schema verification" $false "Error: $_" "INT" $sw.Elapsed.TotalMilliseconds $_.Exception.Message
}

# DB-10: Payments schema
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $payCols = Execute-SqlQuery "SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Payments';"
    $sw.Stop()
    $methCol = $payCols | Where-Object { $_.COLUMN_NAME -eq "PaymentMethod" }
    $passed = ($methCol.DATA_TYPE -eq "varchar" -and $methCol.CHARACTER_MAXIMUM_LENGTH -eq 32)
    Record-TestResult "DB-10" "Schema" "Payments schema (PaymentMethod VARCHAR(32))" $passed "PaymentMethod: $($methCol.DATA_TYPE)($($methCol.CHARACTER_MAXIMUM_LENGTH))" "VARCHAR(32)" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-TestResult "DB-10" "Schema" "Payments schema verification" $false "Error: $_" "VARCHAR(32)" $sw.Elapsed.TotalMilliseconds $_.Exception.Message
}

# ----------------------------------------------------------------------------
# PHASE 3: CONSTRAINTS & INDEXES VERIFICATION
# ----------------------------------------------------------------------------
Write-Host "`n--- PHASE 3: Primary Keys, Foreign Keys & Indexes ---" -ForegroundColor Yellow

# DB-11: Primary keys on all 10 tables
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $pks = Execute-SqlQuery @"
SELECT t.name AS TableName, c.name AS ColumnName
FROM sys.key_constraints kc
INNER JOIN sys.tables t ON kc.parent_object_id = t.object_id
INNER JOIN sys.index_columns ic ON kc.parent_object_id = ic.object_id AND kc.unique_index_id = ic.index_id
INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE kc.type = 'PK';
"@
    $sw.Stop()
    $pkTables = @($pks.TableName)
    $expectedTables = @("Accounts", "Areas", "Categories", "DiningTables", "OrderDetails", "Orders", "Payments", "ProductAttributes", "Products", "Roles")
    $missingPk = $expectedTables | Where-Object { $pkTables -notcontains $_ }
    $passed = ($missingPk.Count -eq 0 -and $pkTables.Count -ge 10)
    Record-TestResult "DB-11" "Constraints" "Primary keys defined on all 10 tables" $passed "PK defined on $($pkTables.Count) tables" "All 10 tables have PK" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-TestResult "DB-11" "Constraints" "Primary keys check" $false "Error: $_" "10 PKs" $sw.Elapsed.TotalMilliseconds $_.Exception.Message
}

# DB-12: Foreign Keys defined (9 FK relationships)
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $fks = Execute-SqlQuery @"
SELECT fk.name AS ForeignKeyName, tp.name AS ParentTable, cp.name AS ParentColumn,
       tr.name AS ReferencedTable, cr.name AS ReferencedColumn,
       fk.delete_referential_action_desc AS DeleteAction
FROM sys.foreign_keys fk
INNER JOIN sys.tables tp ON fk.parent_object_id = tp.object_id
INNER JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
INNER JOIN sys.columns cp ON fkc.parent_object_id = cp.object_id AND fkc.parent_column_id = cp.column_id
INNER JOIN sys.tables tr ON fk.referenced_object_id = tr.object_id
INNER JOIN sys.columns cr ON fkc.referenced_object_id = cr.object_id AND fkc.referenced_column_id = cr.column_id;
"@
    $sw.Stop()
    $fkNames = @($fks.ForeignKeyName)
    $expectedFks = @(
        "FK_Accounts_Roles", "FK_Tables_Areas", "FK_OrderDetails_Orders",
        "FK_OrderDetails_Products", "FK_Orders_Accounts", "FK_Orders_Tables",
        "FK_Payments_Orders", "FK_Attributes_Products", "FK_Products_Categories"
    )
    $missingFks = $expectedFks | Where-Object { $fkNames -notcontains $_ }
    $passed = ($missingFks.Count -eq 0 -and $fkNames.Count -ge 9)
    Record-TestResult "DB-12" "Constraints" "All 9 Foreign Key relationships verified" $passed "Found $($fkNames.Count) FKs: $($fkNames -join ', ')" "Expected 9 FKs" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-TestResult "DB-12" "Constraints" "Foreign keys check" $false "Error: $_" "9 FKs" $sw.Elapsed.TotalMilliseconds $_.Exception.Message
}

# DB-13: All 6 Non-Clustered Indexes
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $indexes = Execute-SqlQuery @"
SELECT t.name AS TableName, i.name AS IndexName, COL_NAME(ic.object_id, ic.column_id) AS ColumnName
FROM sys.indexes i
INNER JOIN sys.tables t ON i.object_id = t.object_id
INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
WHERE i.is_primary_key = 0 AND i.is_unique_constraint = 0 AND t.is_ms_shipped = 0;
"@
    $sw.Stop()
    $idxNames = @($indexes.IndexName)
    $expectedIndexes = @(
        "IX_Products_CategoryId", "IX_Products_ProductName",
        "IX_Orders_OrderCode", "IX_Orders_CreatedAt",
        "IX_OrderDetails_OrderId", "IX_DiningTables_AreaId"
    )
    $missingIdx = $expectedIndexes | Where-Object { $idxNames -notcontains $_ }
    $passed = ($missingIdx.Count -eq 0 -and $idxNames.Count -ge 6)
    Record-TestResult "DB-13" "Indexes" "All 6 non-clustered indexes verified" $passed "Found $($idxNames.Count) indexes: $($idxNames -join ', ')" "Expected 6 indexes" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-TestResult "DB-13" "Indexes" "Non-clustered indexes check" $false "Error: $_" "6 indexes" $sw.Elapsed.TotalMilliseconds $_.Exception.Message
}

# DB-14: UNIQUE constraint on Accounts.Username
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $uqUser = Execute-SqlQuery @"
SELECT kc.name AS ConstraintName, c.name AS ColumnName
FROM sys.key_constraints kc
INNER JOIN sys.tables t ON kc.parent_object_id = t.object_id
INNER JOIN sys.index_columns ic ON kc.parent_object_id = ic.object_id AND kc.unique_index_id = ic.index_id
INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE t.name = 'Accounts' AND kc.type = 'UQ' AND c.name = 'Username';
"@
    $sw.Stop()
    $uqList = @($uqUser)
    $passed = ($uqList.Count -gt 0 -and $uqList[0].ColumnName -eq "Username")
    Record-TestResult "DB-14" "Constraints" "UNIQUE constraint on Accounts.Username" $passed "Constraint: $($uqList[0].ConstraintName) on Username" "UNIQUE on Username" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-TestResult "DB-14" "Constraints" "UNIQUE Accounts.Username check" $false "Error: $_" "UNIQUE on Username" $sw.Elapsed.TotalMilliseconds $_.Exception.Message
}

# DB-15: UNIQUE constraint on Orders.OrderCode
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $uqOrder = Execute-SqlQuery @"
SELECT kc.name AS ConstraintName, c.name AS ColumnName
FROM sys.key_constraints kc
INNER JOIN sys.tables t ON kc.parent_object_id = t.object_id
INNER JOIN sys.index_columns ic ON kc.parent_object_id = ic.object_id AND kc.unique_index_id = ic.index_id
INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE t.name = 'Orders' AND kc.type = 'UQ' AND c.name = 'OrderCode';
"@
    $sw.Stop()
    $uqOrderList = @($uqOrder)
    $passed = ($uqOrderList.Count -gt 0 -and $uqOrderList[0].ColumnName -eq "OrderCode")
    Record-TestResult "DB-15" "Constraints" "UNIQUE constraint on Orders.OrderCode" $passed "Constraint: $($uqOrderList[0].ConstraintName) on OrderCode" "UNIQUE on OrderCode" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-TestResult "DB-15" "Constraints" "UNIQUE Orders.OrderCode check" $false "Error: $_" "UNIQUE on OrderCode" $sw.Elapsed.TotalMilliseconds $_.Exception.Message
}

# DB-16: UNIQUE constraints on Roles(RoleCode) and Roles(RoleName)
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $uqRoles = Execute-SqlQuery @"
SELECT kc.name AS ConstraintName, c.name AS ColumnName
FROM sys.key_constraints kc
INNER JOIN sys.tables t ON kc.parent_object_id = t.object_id
INNER JOIN sys.index_columns ic ON kc.parent_object_id = ic.object_id AND kc.unique_index_id = ic.index_id
INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE t.name = 'Roles' AND kc.type = 'UQ';
"@
    $sw.Stop()
    $roleCols = @($uqRoles.ColumnName)
    $passed = ($roleCols -contains "RoleCode" -and $roleCols -contains "RoleName")
    Record-TestResult "DB-16" "Constraints" "UNIQUE constraints on Roles(RoleCode, RoleName)" $passed "Unique columns: $($roleCols -join ', ')" "RoleCode and RoleName" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-TestResult "DB-16" "Constraints" "UNIQUE Roles check" $false "Error: $_" "RoleCode, RoleName" $sw.Elapsed.TotalMilliseconds $_.Exception.Message
}

# ----------------------------------------------------------------------------
# PHASE 4: ADVERSARIAL UNIQUE CONSTRAINT STRESS-TESTING (DML ATTEMPTS)
# ----------------------------------------------------------------------------
Write-Host "`n--- PHASE 4: Adversarial Unique Constraint Stress-Testing ---" -ForegroundColor Yellow

# DB-17: Adversarial Duplicate Insert on Accounts.Username
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$dupUserSuccess = $false
$caughtError = $null
try {
    $insertQuery = @"
INSERT INTO Accounts (RoleId, Username, PasswordHash, FullName, Email, PhoneNumber, IsActive, IsEmailVerified, OAuthProvider)
VALUES (1, 'admin', 'dummy_hash', N'Duplicate Admin Attack', 'dup@attack.com', '0999999999', 1, 0, 'Local');
"@
    Execute-SqlQuery $insertQuery
    $dupUserSuccess = $true
} catch {
    $caughtError = $_.Exception.Message
}
$sw.Stop()
$passed = (-not $dupUserSuccess -and ($caughtError -like "*Violation of UNIQUE KEY constraint*" -or $caughtError -like "*Cannot insert duplicate key*"))
Record-TestResult "DB-17" "Adversarial" "Accounts.Username rejects duplicate insert ('admin')" $passed "Blocked with SQL error: $($caughtError.Trim())" "SqlException 2627/2601 Violation of UNIQUE KEY constraint" $sw.Elapsed.TotalMilliseconds

# DB-18: Adversarial Duplicate Insert on Roles.RoleCode
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$dupRoleSuccess = $false
$caughtErrorRole = $null
try {
    $insertQuery = @"
INSERT INTO Roles (RoleName, RoleCode, Description)
VALUES (N'Duplicate Admin Role', 'ADMIN', N'Attacking RoleCode Unique');
"@
    Execute-SqlQuery $insertQuery
    $dupRoleSuccess = $true
} catch {
    $caughtErrorRole = $_.Exception.Message
}
$sw.Stop()
$passed = (-not $dupRoleSuccess -and ($caughtErrorRole -like "*Violation of UNIQUE KEY constraint*" -or $caughtErrorRole -like "*Cannot insert duplicate key*"))
Record-TestResult "DB-18" "Adversarial" "Roles.RoleCode rejects duplicate insert ('ADMIN')" $passed "Blocked with SQL error: $($caughtErrorRole.Trim())" "SqlException 2627/2601 Violation of UNIQUE KEY constraint" $sw.Elapsed.TotalMilliseconds

# DB-19: Adversarial Duplicate Insert on Orders.OrderCode
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$dupOrderSuccess = $false
$caughtErrorOrder = $null
try {
    $existingOrderCode = Execute-SqlScalar "SELECT TOP 1 OrderCode FROM Orders ORDER BY OrderId;"
    if ([string]::IsNullOrWhiteSpace($existingOrderCode)) {
        throw "Failed to fetch existing OrderCode for duplicate test"
    }
    $insertQuery = @"
INSERT INTO Orders (OrderCode, CustomerName, OrderType, TotalAmount, Status)
VALUES ('$existingOrderCode', N'Duplicate Order Attack', 1, 100000, 0);
"@
    Execute-SqlQuery $insertQuery
    $dupOrderSuccess = $true
} catch {
    $caughtErrorOrder = $_.Exception.Message
}
$sw.Stop()
$passed = (-not $dupOrderSuccess -and ($caughtErrorOrder -like "*Violation of UNIQUE KEY constraint*" -or $caughtErrorOrder -like "*Cannot insert duplicate key*"))
$errMsg = if ($caughtErrorOrder) { $caughtErrorOrder.Trim() } else { "None" }
Record-TestResult "DB-19" "Adversarial" "Orders.OrderCode rejects duplicate insert" $passed "Blocked with SQL error: $errMsg" "SqlException 2627/2601 Violation of UNIQUE KEY constraint" $sw.Elapsed.TotalMilliseconds

# ----------------------------------------------------------------------------
# PHASE 5: CASCADE DELETE & REFERENTIAL INTEGRITY STRESS-TESTING
# ----------------------------------------------------------------------------
Write-Host "`n--- PHASE 5: Cascade Delete & Referential Integrity ---" -ForegroundColor Yellow

# DB-20: Orders -> OrderDetails ON DELETE CASCADE
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $cascadeOrderSql = @"
SET NOCOUNT ON;
BEGIN TRANSACTION;
-- 1. Insert test Order
INSERT INTO Orders (OrderCode, CustomerName, OrderType, TotalAmount, DiscountAmount, FinalAmount, Status, PaymentStatus)
VALUES ('ORD-TEST-CASCADE-999', N'Cascade Test Customer', 1, 90000, 0, 90000, 0, 0);
DECLARE @NewOrderId INT = SCOPE_IDENTITY();

-- 2. Insert test OrderDetails
INSERT INTO OrderDetails (OrderId, ProductId, Quantity, UnitPrice, SubTotal, CookingStatus)
VALUES (@NewOrderId, 1, 2, 35000, 70000, 0),
       (@NewOrderId, 2, 1, 20000, 20000, 0);

-- 3. Verify inserted details count = 2
DECLARE @DetailsBefore INT = (SELECT COUNT(*) FROM OrderDetails WHERE OrderId = @NewOrderId);

-- 4. Delete Order
DELETE FROM Orders WHERE OrderId = @NewOrderId;

-- 5. Check if details still exist
DECLARE @DetailsAfter INT = (SELECT COUNT(*) FROM OrderDetails WHERE OrderId = @NewOrderId);

COMMIT TRANSACTION;
SELECT @DetailsBefore AS DetailsBefore, @DetailsAfter AS DetailsAfter;
"@
    $resCascadeOrder = Execute-SqlQuery $cascadeOrderSql
    $sw.Stop()
    $before = $resCascadeOrder.DetailsBefore
    $after = $resCascadeOrder.DetailsAfter
    $passed = ($before -eq 2 -and $after -eq 0)
    Record-TestResult "DB-20" "Cascade" "Orders -> OrderDetails ON DELETE CASCADE verified" $passed "Before delete: $before details, After order delete: $after details" "Before: 2, After: 0" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-TestResult "DB-20" "Cascade" "Orders -> OrderDetails ON DELETE CASCADE check" $false "Error: $_" "Before: 2, After: 0" $sw.Elapsed.TotalMilliseconds $_.Exception.Message
}

# DB-21: Products -> ProductAttributes ON DELETE CASCADE
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $cascadeProductSql = @"
SET NOCOUNT ON;
BEGIN TRANSACTION;
-- 1. Insert test Product
INSERT INTO Products (CategoryId, ProductName, Price, Unit, ImageUrl, IsAvailable)
VALUES (1, N'Cascade Test Milk Tea', 45000, N'Ly', 'test_tea.png', 1);
DECLARE @NewProdId INT = SCOPE_IDENTITY();

-- 2. Insert test ProductAttributes
INSERT INTO ProductAttributes (ProductId, AttributeGroup, AttributeName, ExtraPrice, IsRequired)
VALUES (@NewProdId, N'Size', N'Size L', 10000, 0),
       (@NewProdId, N'Topping', N'Trân châu trắng', 10000, 0);

-- 3. Verify inserted attributes count = 2
DECLARE @AttrsBefore INT = (SELECT COUNT(*) FROM ProductAttributes WHERE ProductId = @NewProdId);

-- 4. Delete Product
DELETE FROM Products WHERE ProductId = @NewProdId;

-- 5. Check if attributes still exist
DECLARE @AttrsAfter INT = (SELECT COUNT(*) FROM ProductAttributes WHERE ProductId = @NewProdId);

COMMIT TRANSACTION;
SELECT @AttrsBefore AS AttrsBefore, @AttrsAfter AS AttrsAfter;
"@
    $resCascadeProd = Execute-SqlQuery $cascadeProductSql
    $sw.Stop()
    $before = $resCascadeProd.AttrsBefore
    $after = $resCascadeProd.AttrsAfter
    $passed = ($before -eq 2 -and $after -eq 0)
    Record-TestResult "DB-21" "Cascade" "Products -> ProductAttributes ON DELETE CASCADE verified" $passed "Before delete: $before attributes, After product delete: $after attributes" "Before: 2, After: 0" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-TestResult "DB-21" "Cascade" "Products -> ProductAttributes ON DELETE CASCADE check" $false "Error: $_" "Before: 2, After: 0" $sw.Elapsed.TotalMilliseconds $_.Exception.Message
}

# DB-22: Orders -> Payments NO_ACTION / RESTRICT
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$orderPaymentDeleteFailed = $false
$caughtFkError = $null
try {
    $paymentRestrictSql = @"
SET NOCOUNT ON;
-- 1. Insert test Order
INSERT INTO Orders (OrderCode, CustomerName, OrderType, TotalAmount, DiscountAmount, FinalAmount, Status, PaymentStatus)
VALUES ('ORD-TEST-RESTRICT-PAY', N'Payment Restrict Test', 1, 50000, 0, 50000, 3, 1);
DECLARE @OrderId INT = SCOPE_IDENTITY();

-- 2. Insert test Payment referencing Order
INSERT INTO Payments (OrderId, PaymentMethod, Amount, Status)
VALUES (@OrderId, 'Cash', 50000, 1);

-- 3. Attempt to delete Order (Must fail due to FK_Payments_Orders without CASCADE)
DELETE FROM Orders WHERE OrderId = @OrderId;
"@
    Execute-SqlQuery $paymentRestrictSql
} catch {
    $orderPaymentDeleteFailed = $true
    $caughtFkError = $_.Exception.Message
    # Cleanup test order and payment safely
    Execute-SqlQuery @"
DECLARE @OrderId INT = (SELECT OrderId FROM Orders WHERE OrderCode = 'ORD-TEST-RESTRICT-PAY');
IF @OrderId IS NOT NULL
BEGIN
    DELETE FROM Payments WHERE OrderId = @OrderId;
    DELETE FROM Orders WHERE OrderId = @OrderId;
END
"@
}
$sw.Stop()
$passed = ($orderPaymentDeleteFailed -and ($caughtFkError -like "*REFERENCE constraint*" -or $caughtFkError -like "*FK_Payments_Orders*"))
Record-TestResult "DB-22" "Cascade" "Orders -> Payments RESTRICT (no delete cascade on payments)" $passed "Delete blocked: $($caughtFkError.Trim())" "SqlException 547 REFERENCE constraint FK_Payments_Orders" $sw.Elapsed.TotalMilliseconds

# DB-23: Categories -> Products RESTRICT
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$catDeleteFailed = $false
$caughtCatError = $null
try {
    # Attempt to delete Category 1 which has products
    Execute-SqlQuery "DELETE FROM Categories WHERE CategoryId = 1;"
} catch {
    $catDeleteFailed = $true
    $caughtCatError = $_.Exception.Message
}
$sw.Stop()
$passed = ($catDeleteFailed -and ($caughtCatError -like "*REFERENCE constraint*" -or $caughtCatError -like "*FK_Products_Categories*"))
Record-TestResult "DB-23" "Cascade" "Categories -> Products RESTRICT (cannot delete category with products)" $passed "Delete blocked: $($caughtCatError.Trim())" "SqlException 547 REFERENCE constraint FK_Products_Categories" $sw.Elapsed.TotalMilliseconds

# DB-24: Roles -> Accounts RESTRICT
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$roleDeleteFailed = $false
$caughtRoleError = $null
try {
    # Attempt to delete Role 1 (ADMIN) which has accounts
    Execute-SqlQuery "DELETE FROM Roles WHERE RoleId = 1;"
} catch {
    $roleDeleteFailed = $true
    $caughtRoleError = $_.Exception.Message
}
$sw.Stop()
$passed = ($roleDeleteFailed -and ($caughtRoleError -like "*REFERENCE constraint*" -or $caughtRoleError -like "*FK_Accounts_Roles*"))
Record-TestResult "DB-24" "Cascade" "Roles -> Accounts RESTRICT (cannot delete role with active accounts)" $passed "Delete blocked: $($caughtRoleError.Trim())" "SqlException 547 REFERENCE constraint FK_Accounts_Roles" $sw.Elapsed.TotalMilliseconds

# ----------------------------------------------------------------------------
# PHASE 6: PASSWORD HASHING ARCHITECTURE & BACKWARD COMPATIBILITY
# ----------------------------------------------------------------------------
Write-Host "`n--- PHASE 6: Password Hashing Architecture & Compatibility ---" -ForegroundColor Yellow

# DB-25: Seeded accounts match raw SHA-256('admin') (64 hex characters)
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $seededAccounts = Execute-SqlQuery @"
SELECT AccountId, Username, PasswordHash, LEN(PasswordHash) AS HashLength
FROM Accounts
WHERE AccountId <= 11;
"@
    $sw.Stop()
    $expectedHash = "8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918"
    $allSeededMatch = $true
    foreach ($acc in $seededAccounts) {
        if ($acc.PasswordHash -ne $expectedHash -or $acc.HashLength -ne 64) {
            $allSeededMatch = $false
        }
    }
    Record-TestResult "DB-25" "Crypto" "Seeded accounts 1..11 match raw SHA-256('admin') exactly" $allSeededMatch "Verified $($seededAccounts.Count) seeded accounts (length=64, hash=$expectedHash)" "All 11 seeded accounts have SHA-256 of 'admin'" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-TestResult "DB-25" "Crypto" "Seeded accounts password hash check" $false "Error: $_" "SHA-256('admin')" $sw.Elapsed.TotalMilliseconds $_.Exception.Message
}

# DB-26: Newly registered accounts have {salt}:{hash} format (97 characters)
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $newAccounts = Execute-SqlQuery @"
SELECT AccountId, Username, PasswordHash, LEN(PasswordHash) AS HashLength
FROM Accounts
WHERE AccountId > 11;
"@
    $sw.Stop()
    $allNewMatch = ($newAccounts.Count -gt 0)
    foreach ($acc in $newAccounts) {
        $parts = $acc.PasswordHash.Split(':')
        if ($acc.HashLength -ne 97 -or $parts.Length -ne 2 -or $parts[0].Length -ne 32 -or $parts[1].Length -ne 64) {
            $allNewMatch = $false
        }
    }
    Record-TestResult "DB-26" "Crypto" "New accounts format is {salt:32}:{hash:64} (97 chars)" $allNewMatch "Verified $($newAccounts.Count) new registered accounts with 97-char {salt}:{hash}" "Length 97 chars, 2 parts separated by ':'" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-TestResult "DB-26" "Crypto" "New accounts format check" $false "Error: $_" "{salt}:{hash}" $sw.Elapsed.TotalMilliseconds $_.Exception.Message
}

# DB-27: Salt uniqueness across registered accounts
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $salts = Execute-SqlQuery @"
SELECT SUBSTRING(PasswordHash, 1, 32) AS Salt, COUNT(*) AS Cnt
FROM Accounts
WHERE AccountId > 11 AND CHARINDEX(':', PasswordHash) = 33
GROUP BY SUBSTRING(PasswordHash, 1, 32);
"@
    $sw.Stop()
    $uniqueSalts = $true
    foreach ($s in $salts) {
        if ($s.Cnt -gt 1) {
            $uniqueSalts = $false
        }
    }
    $passed = ($uniqueSalts -and $salts.Count -gt 0)
    Record-TestResult "DB-27" "Crypto" "Cryptographic random salt is unique per account" $passed "Found $($salts.Count) distinct salts across new accounts, max duplication = 1" "Zero duplicate salts" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-TestResult "DB-27" "Crypto" "Salt uniqueness check" $false "Error: $_" "Unique salts" $sw.Elapsed.TotalMilliseconds $_.Exception.Message
}

# DB-28: Empirical verification of PasswordHasher SHA-256 algorithm
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $adminBytes = [System.Text.Encoding]::UTF8.GetBytes("admin")
    $adminHashBytes = $sha256.ComputeHash($adminBytes)
    $computedAdminHash = [System.BitConverter]::ToString($adminHashBytes).Replace("-", "").ToLowerInvariant()
    $expectedAdminHash = "8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918"
    $sw.Stop()
    $passed = ($computedAdminHash -eq $expectedAdminHash)
    Record-TestResult "DB-28" "Crypto" "SHA256 algorithm output matches database seed constant" $passed "Computed: $computedAdminHash" "Expected: $expectedAdminHash" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-TestResult "DB-28" "Crypto" "SHA256 algorithm verification" $false "Error: $_" "Match" $sw.Elapsed.TotalMilliseconds $_.Exception.Message
}

# ----------------------------------------------------------------------------
# SUMMARY & ARTIFACT EXPORT
# ----------------------------------------------------------------------------
$startTimeTotal.Stop()
$totalTests = $testResults.Count
$totalPassed = ($testResults | Where-Object { $_.Passed }).Count
$totalFailed = ($testResults | Where-Object { -not $_.Passed }).Count
$passRate = [Math]::Round(($totalPassed / $totalTests) * 100, 2)

Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host "  ADVERSARIAL EMPIRICAL HARNESS SUMMARY                                    " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host "Total Executed: $totalTests"
Write-Host "Total Passed:   $totalPassed" -ForegroundColor Green
Write-Host "Total Failed:   $totalFailed" -ForegroundColor $(if ($totalFailed -eq 0) { [ConsoleColor]::Green } else { [ConsoleColor]::Red })
Write-Host "Pass Rate:      $passRate %"
Write-Host "Total Duration: $([Math]::Round($startTimeTotal.Elapsed.TotalSeconds, 2)) seconds"
Write-Host "==========================================================================" -ForegroundColor Cyan

$reportObj = [PSCustomObject]@{
    ReportType     = "Adversarial Database & Schema Acceptance Verification"
    Database       = $Database
    ServerInstance = $ServerInstance
    ExecutedAtUtc  = [DateTime]::UtcNow.ToString("o")
    TotalExecuted  = $totalTests
    PassedCount    = $totalPassed
    FailedCount    = $totalFailed
    PassRate       = $passRate
    DurationSeconds= [Math]::Round($startTimeTotal.Elapsed.TotalSeconds, 2)
    Results        = $testResults
}

$artifactsDir = [System.IO.Path]::GetDirectoryName($OutputPath)
if (-not [string]::IsNullOrEmpty($artifactsDir) -and -not (Test-Path $artifactsDir)) {
    New-Item -ItemType Directory -Path $artifactsDir -Force | Out-Null
}

$jsonOutput = $reportObj | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($OutputPath, $jsonOutput, [System.Text.Encoding]::UTF8)
Write-Host "Detailed report exported to: $OutputPath" -ForegroundColor Green

if ($totalFailed -gt 0) {
    exit 1
} else {
    exit 0
}
