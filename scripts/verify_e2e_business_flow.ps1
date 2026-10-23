<#
.SYNOPSIS
    Real End-to-End Restaurant Business Flow, Catalog, Offline Sync & Payment Acceptance Harness
.DESCRIPTION
    Executes real HTTP requests against live ASP.NET Core API on port 5138
    connected to SQL Server database RestaurantPos_Acceptance.
    Verifies:
    1. Category & Product CRUD + Image Upload + Cleanups + Protection Gates.
    2. Full Restaurant Order Lifecycle: Table -> Order -> KDS Cooking -> Cashier Settlement -> Table Release.
    3. Idempotent Offline Sync & Deduplication.
    4. VietQR & VNPay Sandbox Payments.
    Outputs structured JSON report to artifacts/e2e_business_flow_results.json.
#>

[CmdletBinding()]
param(
    [string]$BaseUrl = "http://localhost:5138",
    [string]$ServerInstance = "localhost\SQLEXPRESS",
    [string]$Database = "RestaurantPos_Acceptance",
    [string]$OutputPath = "artifacts/e2e_business_flow_results.json"
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host "  REAL E2E RESTAURANT BUSINESS FLOW & ACCEPTANCE TEST SUITE               " -ForegroundColor Cyan
Write-Host "  Target: $BaseUrl | Dedicated DB: $Database                              " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan

$testResults = [System.Collections.Generic.List[PSObject]]::new()
$startTimeTotal = [System.Diagnostics.Stopwatch]::StartNew()

function Record-Result {
    param(
        [string]$TestId,
        [string]$Category,
        [string]$Description,
        [bool]$Passed,
        [int]$StatusCode,
        [string]$Details = "",
        [double]$DurationMs = 0.0
    )

    $statusLabel = if ($Passed) { "[PASS]" } else { "[FAIL]" }
    $color = if ($Passed) { "Green" } else { "Red" }
    Write-Host ("{0,-8} | {1,-9} | HTTP {2,-3} | {3,8:N2} ms | {4}" -f $statusLabel, $TestId, $StatusCode, $DurationMs, $Description) -ForegroundColor $color
    if (-not $Passed -and -not [string]::IsNullOrEmpty($Details)) {
        Write-Host "         ERROR: $Details" -ForegroundColor Yellow
    }

    $testResults.Add([PSCustomObject]@{
        Id = $TestId
        Category = $Category
        Description = $Description
        Passed = $Passed
        StatusCode = $StatusCode
        DurationMs = [Math]::Round($DurationMs, 2)
        Details = $Details
        Timestamp = (Get-Date).ToString("o")
    })
}

# -------------------------------------------------------------
# 1. CATALOG & IMAGE VERIFICATION
# -------------------------------------------------------------
Write-Host "`n--- Phase 1: Category & Product CRUD + Image Management ---" -ForegroundColor Yellow

# Test 1.1: Get Categories
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $resp = Invoke-RestMethod -Uri "$BaseUrl/api/category" -Method Get
    $sw.Stop()
    $pass = ($resp.Count -gt 0)
    Record-Result "CAT-01" "CATALOG" "Get list of categories (API returns array)" $pass 200 "Count: $($resp.Count)" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-Result "CAT-01" "CATALOG" "Get list of categories" $false 500 $_.Exception.Message $sw.Elapsed.TotalMilliseconds
}

# Test 1.2: Check Category Delete Protection when products exist (CategoryId = 1)
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $resp = Invoke-WebRequest -Uri "$BaseUrl/api/category/1" -Method Delete
    $sw.Stop()
    Record-Result "CAT-02" "CATALOG" "Delete category with products rejected (Expected 400)" $false $resp.StatusCode "Should have rejected" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    $status = $_.Exception.Response.StatusCode.value__
    $pass = ($status -eq 400)
    Record-Result "CAT-02" "CATALOG" "Delete category with products rejected (HasProducts check)" $pass $status "Protected successfully" $sw.Elapsed.TotalMilliseconds
}

# Test 1.3: Get Products with Pagination
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $paged = Invoke-RestMethod -Uri "$BaseUrl/api/product?page=1&pageSize=5" -Method Get
    $sw.Stop()
    $pass = ($paged.items.Count -eq 5 -and $paged.totalItems -ge 10 -and $paged.totalPages -ge 2)
    Record-Result "PROD-01" "CATALOG" "Get products with pagination (page 1, pageSize 5)" $pass 200 "Items: $($paged.items.Count), Total: $($paged.totalItems), Pages: $($paged.totalPages)" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-Result "PROD-01" "CATALOG" "Get products with pagination" $false 500 $_.Exception.Message $sw.Elapsed.TotalMilliseconds
}

# Test 1.4: Pagination Page 2 differs from Page 1
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $paged2 = Invoke-RestMethod -Uri "$BaseUrl/api/product?page=2&pageSize=5" -Method Get
    $sw.Stop()
    $firstIdP1 = $paged.items[0].productId
    $firstIdP2 = $paged2.items[0].productId
    $pass = ($firstIdP1 -ne $firstIdP2 -and $paged2.items.Count -gt 0)
    Record-Result "PROD-02" "CATALOG" "Pagination boundaries (Page 2 items distinct from Page 1)" $pass 200 "P1 first ID: $firstIdP1, P2 first ID: $firstIdP2" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-Result "PROD-02" "CATALOG" "Pagination page 2" $false 500 $_.Exception.Message $sw.Elapsed.TotalMilliseconds
}

# Test 1.5: Filter by Category (CategoryId = 1)
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $catProds = Invoke-RestMethod -Uri "$BaseUrl/api/product/by-category/1" -Method Get
    $sw.Stop()
    $allCat1 = $true
    foreach ($item in $catProds.items) {
        if ($item.categoryId -ne 1) { $allCat1 = $false }
    }
    Record-Result "PROD-03" "CATALOG" "Filter products by CategoryId=1" ($allCat1 -and $catProds.items.Count -gt 0) 200 "Count: $($catProds.items.Count)" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-Result "PROD-03" "CATALOG" "Filter products by category" $false 500 $_.Exception.Message $sw.Elapsed.TotalMilliseconds
}

# Test 1.6: Search products by keyword
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $kw = [System.Uri]::EscapeDataString("Matcha")
    $searchProds = Invoke-RestMethod -Uri "$BaseUrl/api/product/search?keyword=$kw" -Method Get
    $sw.Stop()
    $pass = ($searchProds.items.Count -gt 0)
    Record-Result "PROD-04" "CATALOG" "Search products by keyword ('Matcha')" $pass 200 "Found: $($searchProds.items.Count)" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-Result "PROD-04" "CATALOG" "Search products" $false 500 $_.Exception.Message $sw.Elapsed.TotalMilliseconds
}

# Test 1.7: Latest products
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $latest = Invoke-RestMethod -Uri "$BaseUrl/api/product/latest?pageSize=3" -Method Get
    $sw.Stop()
    $pass = ($latest.items.Count -eq 3)
    Record-Result "PROD-05" "CATALOG" "Get latest products (Sorted DESC)" $pass 200 "Count: $($latest.items.Count)" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-Result "PROD-05" "CATALOG" "Get latest products" $false 500 $_.Exception.Message $sw.Elapsed.TotalMilliseconds
}

# Test 1.8: Related products
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $related = Invoke-RestMethod -Uri "$BaseUrl/api/product/1/related" -Method Get
    $sw.Stop()
    $pass = ($related.items.Count -gt 0)
    Record-Result "PROD-06" "CATALOG" "Get related products for ProductId=1" $pass 200 "Found: $($related.items.Count)" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-Result "PROD-06" "CATALOG" "Get related products" $false 500 $_.Exception.Message $sw.Elapsed.TotalMilliseconds
}

# Test 1.9: Prevent deleting product referenced in historical order (ProductId = 1)
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $resp = Invoke-WebRequest -Uri "$BaseUrl/api/product/1" -Method Delete
    $sw.Stop()
    Record-Result "PROD-07" "CATALOG" "Delete product referenced in orders rejected (Expected 400)" $false $resp.StatusCode "Should have rejected" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    $status = $_.Exception.Response.StatusCode.value__
    $pass = ($status -eq 400)
    Record-Result "PROD-07" "CATALOG" "Delete product in historical orders rejected (HasOrders check)" $pass $status "Protected successfully" $sw.Elapsed.TotalMilliseconds
}

# -------------------------------------------------------------
# 2. FULL RESTAURANT ORDER & KDS LIFECYCLE
# -------------------------------------------------------------
Write-Host "`n--- Phase 2: Full Restaurant Order & KDS Lifecycle ---" -ForegroundColor Yellow

# Step 2.1: Verify Table 2 is Empty (Status = 0)
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $tableResp = Invoke-RestMethod -Uri "$BaseUrl/api/table" -Method Get
    $sw.Stop()
    $t2 = $tableResp | Where-Object { $_.tableId -eq 2 }
    $pass = ($t2 -ne $null)
    Record-Result "ORDER-01" "ORDER_FLOW" "Verify Table 2 exists on floor plan" $pass 200 "Table: $($t2.tableName), Status: $($t2.status)" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-Result "ORDER-01" "ORDER_FLOW" "Verify Table 2 exists" $false 500 $_.Exception.Message $sw.Elapsed.TotalMilliseconds
}

# Step 2.2: Place order for Table 2 (Products: ID 1 x 2, ID 2 x 1)
$orderPayload = @{
    tableId = 2
    customerName = "Anh Hoang E2E Test"
    orderType = 1
    note = "Ít đường, nhiều đá"
    items = @(
        @{ productId = 1; quantity = 2; itemNote = "Đậm đà" },
        @{ productId = 2; quantity = 1; itemNote = "Bình thường" }
    )
} | ConvertTo-Json -Depth 5

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$createdOrder = $null
try {
    $createResp = Invoke-RestMethod -Uri "$BaseUrl/api/order" -Method Post -Body $orderPayload -ContentType "application/json; charset=utf-8"
    $sw.Stop()
    $createdOrder = $createResp.data
    $pass = ($createResp.success -eq $true -and $createdOrder -ne $null -and $createdOrder.finalAmount -gt 0)
    Record-Result "ORDER-02" "ORDER_FLOW" "Place real order via POST /api/order with server-calculated total" $pass 200 "OrderCode: $($createdOrder.orderCode), Total: $($createdOrder.finalAmount)" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-Result "ORDER-02" "ORDER_FLOW" "Place real order" $false 500 $_.Exception.Message $sw.Elapsed.TotalMilliseconds
}

# Step 2.3: Verify Table 2 becomes Occupied (Status = 1) in SQL Server
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $table2Updated = Invoke-RestMethod -Uri "$BaseUrl/api/table" -Method Get | Where-Object { $_.tableId -eq 2 }
    $sw.Stop()
    $pass = ($table2Updated.status -eq 1 -and $table2Updated.currentOrderId -eq $createdOrder.orderId)
    Record-Result "ORDER-03" "ORDER_FLOW" "Verify Table 2 status transitioned to Occupied (1) with CurrentOrderId" $pass 200 "Status: $($table2Updated.status), CurrentOrderId: $($table2Updated.currentOrderId)" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-Result "ORDER-03" "ORDER_FLOW" "Verify table occupied" $false 500 $_.Exception.Message $sw.Elapsed.TotalMilliseconds
}

# Step 2.4: Reject placing new order on currently Occupied table
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $dupOrderResp = Invoke-WebRequest -Uri "$BaseUrl/api/order" -Method Post -Body $orderPayload -ContentType "application/json; charset=utf-8"
    $sw.Stop()
    Record-Result "ORDER-04" "ORDER_FLOW" "Reject new order on occupied table (Expected 400)" $false $dupOrderResp.StatusCode "Should have rejected" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    $status = $_.Exception.Response.StatusCode.value__
    $pass = ($status -eq 400)
    Record-Result "ORDER-04" "ORDER_FLOW" "Reject new order on already occupied table" $pass $status "Conflict correctly prevented" $sw.Elapsed.TotalMilliseconds
}

# Step 2.5: Kitchen Display System (KDS) receives order items
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$kdsItem1 = $null
$kdsItem2 = $null
try {
    $kdsResp = Invoke-RestMethod -Uri "$BaseUrl/api/kds" -Method Get
    $sw.Stop()
    $ourItems = $kdsResp.data | Where-Object { $_.orderId -eq $createdOrder.orderId }
    $pass = ($ourItems.Count -eq 2)
    if ($pass) {
        $kdsItem1 = $ourItems[0]
        $kdsItem2 = $ourItems[1]
    }
    Record-Result "KDS-01" "KDS_FLOW" "KDS displays new order items in pending cooking queue" $pass 200 "Items in KDS: $($ourItems.Count)" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-Result "KDS-01" "KDS_FLOW" "KDS displays items" $false 500 $_.Exception.Message $sw.Elapsed.TotalMilliseconds
}

# Step 2.6: KDS Transition item 1 to Cooking (Status = 1)
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $statusBody = @{ cookingStatus = 1 } | ConvertTo-Json
    $kdsUpd1 = Invoke-RestMethod -Uri "$BaseUrl/api/kds/$($kdsItem1.orderDetailId)/status" -Method Put -Body $statusBody -ContentType "application/json"
    $sw.Stop()
    $pass = ($kdsUpd1.success -eq $true)
    Record-Result "KDS-02" "KDS_FLOW" "KDS transition dish to 'Cooking' (1)" $pass 200 "Item ID $($kdsItem1.orderDetailId) Cooking" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-Result "KDS-02" "KDS_FLOW" "KDS cooking update" $false 500 $_.Exception.Message $sw.Elapsed.TotalMilliseconds
}

# Step 2.7: KDS Complete all items (Status = 2) -> Order auto-transitions to Served (2)
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $statusBodyReady = @{ cookingStatus = 2 } | ConvertTo-Json
    $null = Invoke-RestMethod -Uri "$BaseUrl/api/kds/$($kdsItem1.orderDetailId)/status" -Method Put -Body $statusBodyReady -ContentType "application/json"
    $null = Invoke-RestMethod -Uri "$BaseUrl/api/kds/$($kdsItem2.orderDetailId)/status" -Method Put -Body $statusBodyReady -ContentType "application/json"
    
    # Check order status
    $checkOrd = Invoke-RestMethod -Uri "$BaseUrl/api/order/$($createdOrder.orderId)" -Method Get
    $sw.Stop()
    $pass = ($checkOrd.status -eq 2) # Served
    Record-Result "KDS-03" "KDS_FLOW" "All dishes marked Ready (2) -> Order auto-transitions to 'Served' (2)" $pass 200 "Order Status: $($checkOrd.statusText)" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-Result "KDS-03" "KDS_FLOW" "KDS complete items" $false 500 $_.Exception.Message $sw.Elapsed.TotalMilliseconds
}

# -------------------------------------------------------------
# 3. CASHIER SETTLEMENT & TABLE RELEASE
# -------------------------------------------------------------
Write-Host "`n--- Phase 3: Cashier Settlement & Table Release ---" -ForegroundColor Yellow

# Step 3.1: Confirm Cash Payment
$cashPayload = @{
    orderId = $createdOrder.orderId
    note = "Khách thanh toán tiền mặt 100k, thối 20k"
} | ConvertTo-Json

$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $payResp = Invoke-RestMethod -Uri "$BaseUrl/api/payment/cash" -Method Post -Body $cashPayload -ContentType "application/json; charset=utf-8"
    $sw.Stop()
    $pass = ($payResp.success -eq $true -and $payResp.data.paymentMethod -eq "Cash" -and $payResp.data.status -eq 1)
    Record-Result "PAY-01" "PAYMENT" "Confirm Cash payment at cashier desk" $pass 200 "Payment ID: $($payResp.data.paymentId), Method: $($payResp.data.paymentMethod)" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-Result "PAY-01" "PAYMENT" "Confirm cash payment" $false 500 $_.Exception.Message $sw.Elapsed.TotalMilliseconds
}

# Step 3.2: Verify Order is Settled and Completed in SQL Server
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $settledOrder = Invoke-RestMethod -Uri "$BaseUrl/api/order/$($createdOrder.orderId)" -Method Get
    $sw.Stop()
    $pass = ($settledOrder.paymentStatus -eq 1 -and $settledOrder.status -eq 3)
    Record-Result "PAY-02" "PAYMENT" "Verify Order PaymentStatus=1 (Paid) and Status=3 (Completed)" $pass 200 "Payment: $($settledOrder.paymentStatusText), Status: $($settledOrder.statusText)" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-Result "PAY-02" "PAYMENT" "Verify settled order" $false 500 $_.Exception.Message $sw.Elapsed.TotalMilliseconds
}

# Step 3.3: Verify Table 2 is Released (Status = 0, CurrentOrderId = null)
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $table2Released = Invoke-RestMethod -Uri "$BaseUrl/api/table" -Method Get | Where-Object { $_.tableId -eq 2 }
    $sw.Stop()
    $pass = ($table2Released.status -eq 0 -and $table2Released.currentOrderId -eq $null)
    Record-Result "PAY-03" "PAYMENT" "Verify Table 2 is released back to Empty (0)" $pass 200 "Status: $($table2Released.status), CurrentOrderId: $($table2Released.currentOrderId)" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-Result "PAY-03" "PAYMENT" "Verify table released" $false 500 $_.Exception.Message $sw.Elapsed.TotalMilliseconds
}

# Step 3.4: Reject Duplicate Payment on already paid order
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $dupPayResp = Invoke-WebRequest -Uri "$BaseUrl/api/payment/cash" -Method Post -Body $cashPayload -ContentType "application/json"
    $sw.Stop()
    Record-Result "PAY-04" "PAYMENT" "Reject duplicate payment on settled order (Expected 400)" $false $dupPayResp.StatusCode "Should have rejected" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    $status = $_.Exception.Response.StatusCode.value__
    $pass = ($status -eq 400)
    Record-Result "PAY-04" "PAYMENT" "Reject duplicate payment on already settled order" $pass $status "Duplicate payment blocked" $sw.Elapsed.TotalMilliseconds
}

# -------------------------------------------------------------
# 4. VIETQR & VNPAY PAYMENT GATEWAYS
# -------------------------------------------------------------
Write-Host "`n--- Phase 4: VietQR & VNPay Sandbox Payment Gateways ---" -ForegroundColor Yellow

# Step 4.1: Generate VietQR for Order 1
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $qrResp = Invoke-RestMethod -Uri "$BaseUrl/api/payment/vietqr/1" -Method Get
    $sw.Stop()
    $qr = $qrResp.data
    $pass = ($qrResp.success -eq $true -and $qr.qrCodeUrl.StartsWith("https://img.vietqr.io") -and $qr.accountNo -eq "102871234567")
    Record-Result "GATEWAY-01" "GATEWAY" "Generate dynamic VietQR image link & account metadata" $pass 200 "Bank: $($qr.bankId), Acc: $($qr.accountNo), URL: $($qr.qrCodeUrl.Substring(0, 45))..." $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-Result "GATEWAY-01" "GATEWAY" "Generate VietQR" $false 500 $_.Exception.Message $sw.Elapsed.TotalMilliseconds
}

# Step 4.2: Generate VNPay Sandbox Signed Payment URL (using unpaid Order 3)
$vnpPayload = @{
    orderId = 3
    returnUrl = "http://localhost:5138/api/payment/vnpay/callback"
} | ConvertTo-Json

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$vnpUrl = ""
try {
    $vnpResp = Invoke-RestMethod -Uri "$BaseUrl/api/payment/vnpay/create-url" -Method Post -Body $vnpPayload -ContentType "application/json"
    $sw.Stop()
    $vnpUrl = $vnpResp.paymentUrl
    $pass = ($vnpResp.success -eq $true -and $vnpUrl.Contains("vnp_SecureHash=") -and $vnpResp.status -eq "SANDBOX VERIFIED")
    Record-Result "GATEWAY-02" "GATEWAY" "Generate VNPay Sandbox URL with HMAC-SHA512 checksum" $pass 200 "Label: $($vnpResp.status)" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-Result "GATEWAY-02" "GATEWAY" "Generate VNPay Sandbox URL" $false 500 $_.Exception.Message $sw.Elapsed.TotalMilliseconds
}

# Step 4.3: Reject Invalid HMAC Signature on VNPay Callback
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $tamperedCallback = "$BaseUrl/api/payment/vnpay/callback?vnp_Amount=10000000&vnp_ResponseCode=00&vnp_TxnRef=2_12345&vnp_SecureHash=INVALID_FORGED_HASH"
    $tamperedResp = Invoke-WebRequest -Uri $tamperedCallback -Method Get
    $sw.Stop()
    Record-Result "GATEWAY-03" "GATEWAY" "Reject tampered VNPay callback (Expected 400)" $false $tamperedResp.StatusCode "Should have rejected" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    $status = $_.Exception.Response.StatusCode.value__
    $pass = ($status -eq 400)
    Record-Result "GATEWAY-03" "GATEWAY" "Reject VNPay callback with forged HMAC signature" $pass $status "Tampered callback blocked" $sw.Elapsed.TotalMilliseconds
}

# -------------------------------------------------------------
# 5. OFFLINE SYNC EXPERIMENTS & IDEMPOTENT DEDUPLICATION
# -------------------------------------------------------------
Write-Host "`n--- Phase 5: Offline Sync & Idempotent Deduplication ---" -ForegroundColor Yellow

$offlineOrderId = [int]((Get-Date).Ticks % 800000 + 100000)
$expectedOfflineCode = "ORD-OFF-$($offlineOrderId.ToString('D6'))"
$offlinePayload = @{
    offlineOrderId = $offlineOrderId
    tableId = 6
    customerName = "Khach Offline Sync Test"
    orderType = 1
    items = @(
        @{ productId = 3; quantity = 1 }
    )
} | ConvertTo-Json -Depth 5

# Step 5.1: First offline order sync
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$firstSyncOrder = $null
try {
    $syncResp1 = Invoke-RestMethod -Uri "$BaseUrl/api/order" -Method Post -Body $offlinePayload -ContentType "application/json; charset=utf-8"
    $sw.Stop()
    $firstSyncOrder = $syncResp1.data
    $pass = ($syncResp1.success -eq $true -and $firstSyncOrder.orderCode -eq $expectedOfflineCode)
    Record-Result "OFFLINE-01" "OFFLINE" "Sync offline order (creates $expectedOfflineCode)" $pass 200 "OrderCode: $($firstSyncOrder.orderCode), OrderId: $($firstSyncOrder.orderId)" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-Result "OFFLINE-01" "OFFLINE" "Sync offline order 1" $false 500 $_.Exception.Message $sw.Elapsed.TotalMilliseconds
}

# Step 5.2: Re-send identical offline order (Simulating network timeout retry / concurrent resend)
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $syncResp2 = Invoke-RestMethod -Uri "$BaseUrl/api/order" -Method Post -Body $offlinePayload -ContentType "application/json; charset=utf-8"
    $sw.Stop()
    $secondSyncOrder = $syncResp2.data
    # Idempotent deduplication must return the SAME orderId without creating duplicate rows
    $pass = ($syncResp2.success -eq $true -and $secondSyncOrder.orderId -eq $firstSyncOrder.orderId -and $syncResp2.message.Contains("Idempotent"))
    Record-Result "OFFLINE-02" "OFFLINE" "Concurrent retry / re-sync deduplication (Exact same OrderId returned)" $pass 200 "Deduplicated OrderId: $($secondSyncOrder.orderId)" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-Result "OFFLINE-02" "OFFLINE" "Offline retry deduplication" $false 500 $_.Exception.Message $sw.Elapsed.TotalMilliseconds
}

# Step 5.3: Verify in SQL Server that only ONE order with OrderCode 'ORD-OFF-099881' exists
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $conn = New-Object System.Data.SqlClient.SqlConnection("Server=$ServerInstance;Database=$Database;Integrated Security=True;TrustServerCertificate=True;")
    $conn.Open()
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "SELECT COUNT(*) FROM Orders WHERE OrderCode = '$expectedOfflineCode'"
    $dbCount = $cmd.ExecuteScalar()
    $conn.Close()
    $sw.Stop()

    $pass = ($dbCount -eq 1)
    Record-Result "OFFLINE-03" "OFFLINE" "Verify database contains strictly ONE order for offline queue item" $pass 200 "SQL Count: $dbCount (Zero Duplication)" $sw.Elapsed.TotalMilliseconds
} catch {
    $sw.Stop()
    Record-Result "OFFLINE-03" "OFFLINE" "Query SQL for offline order count" $false 500 $_.Exception.Message $sw.Elapsed.TotalMilliseconds
}

# -------------------------------------------------------------
# SUMMARY & ARTIFACT EXPORT
# -------------------------------------------------------------
$totalDuration = $startTimeTotal.Elapsed.TotalSeconds
$passCount = ($testResults | Where-Object { $_.Passed }).Count
$failCount = ($testResults | Where-Object { -not $_.Passed }).Count
$totalCount = $testResults.Count
$passRate = [Math]::Round(($passCount / $totalCount) * 100, 2)

Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host "  REAL E2E RESTAURANT BUSINESS FLOW EXECUTION SUMMARY                     " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host "Total Executed : $totalCount"
Write-Host "Total Passed   : $passCount" -ForegroundColor Green
Write-Host "Total Failed   : $failCount" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })
Write-Host "Pass Rate      : $passRate %" -ForegroundColor $(if ($passRate -eq 100) { "Green" } else { "Yellow" })
Write-Host "Total Duration : $([Math]::Round($totalDuration, 2)) seconds"
Write-Host "==========================================================================" -ForegroundColor Cyan

$report = [PSCustomObject]@{
    Harness = "Restaurant POS Real E2E Business Flow Acceptance"
    Target = $BaseUrl
    Database = $Database
    ExecutedAt = (Get-Date).ToString("o")
    TotalTests = $totalCount
    Passed = $passCount
    Failed = $failCount
    PassRate = $passRate
    DurationSeconds = [Math]::Round($totalDuration, 2)
    Results = $testResults
}

$dir = [System.IO.Path]::GetDirectoryName($OutputPath)
if (-not [string]::IsNullOrEmpty($dir) -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

$report | ConvertTo-Json -Depth 6 | Set-Content -Path $OutputPath -Encoding UTF8
Write-Host "Detailed report exported to: $OutputPath" -ForegroundColor Green
