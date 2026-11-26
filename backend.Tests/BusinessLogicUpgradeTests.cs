using System.Globalization;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using WebApi.Models;
using Xunit;

namespace WebApi.Tests;

public class BusinessLogicUpgradeTests
{
    private sealed class TestFixture : IDisposable
    {
        public SqliteConnection Connection { get; }
        public RestaurantPosContext Context { get; }

        public TestFixture()
        {
            Connection = new SqliteConnection("DataSource=:memory:");
            Connection.Open();
            var options = new DbContextOptionsBuilder<RestaurantPosContext>()
                .UseSqlite(Connection)
                .Options;
            Context = new RestaurantPosContext(options);
            Context.Database.EnsureCreated();
            SeedBaseData();
        }

        private void SeedBaseData()
        {
            Context.Roles.AddRange(
                new Role { RoleId = 1, RoleName = "Admin", RoleCode = "ADMIN" },
                new Role { RoleId = 2, RoleName = "Cashier", RoleCode = "CASHIER" },
                new Role { RoleId = 3, RoleName = "Member", RoleCode = "MEMBER" }
            );

            Context.Accounts.AddRange(
                new Account { AccountId = 1, RoleId = 1, Username = "admin", PasswordHash = "hash", FullName = "Admin", IsActive = true },
                new Account { AccountId = 2, RoleId = 2, Username = "cashier1", PasswordHash = "hash", FullName = "Cashier 1", PhoneNumber = "0901111111", IsActive = true },
                new Account { AccountId = 3, RoleId = 2, Username = "cashier2", PasswordHash = "hash", FullName = "Cashier 2", PhoneNumber = "0902222222", IsActive = true },
                new Account { AccountId = 8, RoleId = 3, Username = "member1", PasswordHash = "hash", FullName = "Member One", PhoneNumber = "0908888888", LoyaltyPoints = 500, IsActive = true },
                new Account { AccountId = 9, RoleId = 3, Username = "member2", PasswordHash = "hash", FullName = "Member Two", PhoneNumber = "0909999999", LoyaltyPoints = 100, IsActive = true }
            );

            Context.Areas.Add(new Area { AreaId = 1, AreaName = "Sảnh Chính", SortOrder = 1, IsActive = true });
            Context.DiningTables.AddRange(
                new DiningTable { TableId = 1, AreaId = 1, TableName = "Bàn 01", Capacity = 4, Status = 0 },
                new DiningTable { TableId = 2, AreaId = 1, TableName = "Bàn 02", Capacity = 4, Status = 0 },
                new DiningTable { TableId = 3, AreaId = 1, TableName = "VIP 03", Capacity = 6, Status = 0 }
            );

            Context.Categories.Add(new Category { Id = 1, Name = "Cà phê", Title = "Coffee", Description = "Coffee", Icon = "coffee", SortOrder = 1, IsActive = true });

            Context.Products.AddRange(
                new Product { ProductId = 1, CategoryId = 1, ProductName = "Bạc Xỉu", Price = 45000, Unit = "Ly", ImageUrl = "/img/1.png", IsAvailable = true, AutoDisabledByStock = false },
                new Product { ProductId = 2, CategoryId = 1, ProductName = "Cà phê Tạm Ngưng Thủ Công", Price = 35000, Unit = "Ly", ImageUrl = "/img/2.png", IsAvailable = false, AutoDisabledByStock = false }
            );

            Context.ProductAttributes.AddRange(
                new ProductAttribute { AttributeId = 1, ProductId = 1, AttributeGroup = "Size", AttributeName = "Size L", ExtraPrice = 10000 },
                new ProductAttribute { AttributeId = 2, ProductId = 1, AttributeGroup = "Topping", AttributeName = "Thêm Trân Châu", ExtraPrice = 8000 }
            );

            Context.Ingredients.AddRange(
                new Ingredient { IngredientId = 1, IngredientName = "Cà phê Robusta", Unit = "gram", CurrentStock = 100m, MinThreshold = 30m, CostPerUnit = 320m, IsActive = true },
                new Ingredient { IngredientId = 2, IngredientName = "Sữa đặc", Unit = "ml", CurrentStock = 150m, MinThreshold = 50m, CostPerUnit = 45m, IsActive = true },
                new Ingredient { IngredientId = 3, IngredientName = "Trân châu đường đen", Unit = "gram", CurrentStock = 80m, MinThreshold = 20m, CostPerUnit = 95m, IsActive = true }
            );

            // Product 1 needs 40g coffee + 50ml condensed milk
            // Product 2 (manually off) needs 20g coffee
            Context.ProductRecipes.AddRange(
                new ProductRecipe { ProductId = 1, IngredientId = 1, QuantityRequired = 40m },
                new ProductRecipe { ProductId = 1, IngredientId = 2, QuantityRequired = 50m },
                new ProductRecipe { ProductId = 2, IngredientId = 1, QuantityRequired = 20m }
            );

            // Size L adds +20g coffee; Topping adds +30g boba
            Context.ProductAttributeRecipes.AddRange(
                new ProductAttributeRecipe { AttributeId = 1, IngredientId = 1, QuantityRequired = 20m },
                new ProductAttributeRecipe { AttributeId = 2, IngredientId = 3, QuantityRequired = 30m }
            );

            Context.Discounts.AddRange(
                new Discount { DiscountId = 1, Code = "VIP10", Title = "Giảm 10% (200 PTS)", DiscountPercent = 10, MinOrderAmount = 50000, MaxDiscountAmount = 50000, PointsCost = 200, IsActive = true },
                new Discount { DiscountId = 2, Code = "FREE5K", Title = "Miễn phí điểm 5K", DiscountAmount = 5000, MinOrderAmount = 20000, PointsCost = 0, IsActive = true }
            );

            Context.SaveChanges();
        }

        public void Dispose()
        {
            Context.Dispose();
            Connection.Dispose();
        }
    }

    [Fact]
    public async Task Bom_InsufficientStock_RejectsOrder_And_RollsBack()
    {
        using var fx = new TestFixture();
        var orderRepo = new OrderRepository(fx.Context);

        // Bạc Xỉu needs 40g coffee/cup -> 3 cups = 120g > 100g available
        var res = await orderRepo.CreateOrderAsync(new CreateOrderDto
        {
            TableId = 1,
            Items = new List<CreateOrderItemDto> { new() { ProductId = 1, Quantity = 3 } }
        }, authenticatedAccountId: 2);

        Assert.False(res.Success);
        Assert.Contains("Không đủ nguyên liệu", res.Message);
        fx.Context.ChangeTracker.Clear();
        Assert.Equal(0, await fx.Context.Orders.CountAsync());
        Assert.Equal(100m, (await fx.Context.Ingredients.FindAsync(1))!.CurrentStock);
        Assert.Equal(0, (await fx.Context.DiningTables.FindAsync(1))!.Status);
    }

    [Fact]
    public async Task Bom_ProductAndModifiers_Deduct_AutoDisable_And_AutoReopen_PreservingManualOff()
    {
        using var fx = new TestFixture();
        var orderRepo = new OrderRepository(fx.Context);
        var invRepo = new InventoryRepository(fx.Context);

        // 1x Bạc Xỉu (40g coffee, 50ml milk) + Size L (+20g coffee) + Trân Châu (+30g boba)
        // Total deducted: coffee=60g (remaining 40g -> 1 cup? Wait: wait, let's order 2? Wait 60g leaves 40g -> can still make 1 base cup. Order 1 base + 1 Size L then another 1 base?)
        // Order 1x Bạc Xỉu + Size L + Trân Châu first -> remaining coffee = 40g, milk = 100ml, boba = 50g.
        var res1 = await orderRepo.CreateOrderAsync(new CreateOrderDto
        {
            TableId = 1,
            Items = new List<CreateOrderItemDto>
            {
                new()
                {
                    ProductId = 1,
                    Quantity = 1,
                    Modifiers = new List<OrderItemModifierDto>
                    {
                        new() { AttributeId = 1, ModifierName = "Size L", ExtraPrice = 10000 },
                        new() { AttributeId = 2, ModifierName = "Thêm Trân Châu", ExtraPrice = 8000 }
                    }
                }
            }
        }, authenticatedAccountId: 2);

        Assert.True(res1.Success);
        Assert.Equal(40m, (await fx.Context.Ingredients.FindAsync(1))!.CurrentStock);
        Assert.Equal(100m, (await fx.Context.Ingredients.FindAsync(2))!.CurrentStock);
        Assert.Equal(50m, (await fx.Context.Ingredients.FindAsync(3))!.CurrentStock);
        Assert.Equal(63000m, res1.Order!.TotalAmount); // 45k + 10k + 8k

        // Order 1 more Bạc Xỉu (40g coffee) -> coffee drops to 0g (<40g) -> Product 1 auto-disabled!
        var res2 = await orderRepo.CreateOrderAsync(new CreateOrderDto
        {
            TableId = 2,
            Items = new List<CreateOrderItemDto> { new() { ProductId = 1, Quantity = 1 } }
        }, authenticatedAccountId: 2);

        Assert.True(res2.Success);
        var p1 = await fx.Context.Products.FindAsync(1);
        var p2 = await fx.Context.Products.FindAsync(2);
        Assert.False(p1!.IsAvailable);
        Assert.True(p1.AutoDisabledByStock);
        Assert.False(p2!.IsAvailable);
        Assert.False(p2.AutoDisabledByStock);

        // Restock coffee +100g -> Product 1 auto-reopens, Product 2 stays manually off!
        var adj = await invRepo.AdjustStockAsync(1, new AdjustStockDto { Type = "IMPORT", ChangeAmount = 100m, Note = "Nhập thêm" }, 1);
        Assert.True(adj.Success);

        p1 = await fx.Context.Products.FindAsync(1);
        p2 = await fx.Context.Products.FindAsync(2);
        Assert.True(p1!.IsAvailable);
        Assert.False(p1.AutoDisabledByStock);
        Assert.False(p2!.IsAvailable);
        Assert.False(p2.AutoDisabledByStock);
    }

    [Fact]
    public async Task Bom_VoidRestore_IsAccurate_And_PreventsPhantomStock()
    {
        using var fx = new TestFixture();
        var orderRepo = new OrderRepository(fx.Context);
        var invRepo = new InventoryRepository(fx.Context);

        var created = await orderRepo.CreateOrderAsync(new CreateOrderDto
        {
            TableId = 1,
            Items = new List<CreateOrderItemDto>
            {
                new()
                {
                    ProductId = 1,
                    Quantity = 1,
                    Modifiers = new List<OrderItemModifierDto>
                    {
                        new() { AttributeId = 2, ModifierName = "Thêm Trân Châu", ExtraPrice = 8000 }
                    }
                }
            }
        }, authenticatedAccountId: 2);

        Assert.True(created.Success);
        var detailId = created.Order!.Details[0].OrderDetailId;
        Assert.Equal(60m, (await fx.Context.Ingredients.FindAsync(1))!.CurrentStock);
        Assert.Equal(50m, (await fx.Context.Ingredients.FindAsync(3))!.CurrentStock);

        var voidRes = await orderRepo.VoidOrderItemAsync(created.Order.OrderId, detailId, "Khách đổi món", 1);
        Assert.True(voidRes.Success);
        Assert.Equal(100m, (await fx.Context.Ingredients.FindAsync(1))!.CurrentStock);
        Assert.Equal(80m, (await fx.Context.Ingredients.FindAsync(3))!.CurrentStock);

        // Attempt second refund beyond what was deducted for this OrderId
        await invRepo.RestoreForVoidAsync(created.Order.OrderId, 1, 5, new[] { 2 }, 1);
        Assert.Equal(100m, (await fx.Context.Ingredients.FindAsync(1))!.CurrentStock);
        Assert.Equal(80m, (await fx.Context.Ingredients.FindAsync(3))!.CurrentStock);
    }

    [Fact]
    public async Task Reservations_Duration_Overlap_AutoLock_NoShow_DepositCredit_And_Ownership()
    {
        using var fx = new TestFixture();
        var tableRepo = new TableRepository(fx.Context);
        var orderRepo = new OrderRepository(fx.Context);
        var payRepo = new PaymentRepository(fx.Context);

        var baseTime = DateTime.Now.AddHours(3);

        // Past arrival rejected
        var pastRes = tableRepo.ReserveTable(1, "Past", "0900000001", 2, DateTime.Now.AddMinutes(-20), 0, null);
        Assert.False(pastRes.Success);

        // Capacity exceeded rejected
        var capRes = tableRepo.ReserveTable(1, "OverCap", "0900000002", 8, baseTime, 0, null);
        Assert.False(capRes.Success);

        // Future reservation (>60m ahead) succeeds WITHOUT immediately locking empty table
        var r1 = tableRepo.ReserveTable(1, "Member One", "0908888888", 4, baseTime, 100000m, "Gần cửa", 120, 30, accountId: 8);
        Assert.True(r1.Success);
        Assert.Equal(0, (await fx.Context.DiningTables.FindAsync(1))!.Status);

        // Overlapping reservation (+60m falls inside 120m window) rejected
        var overlapRes = tableRepo.ReserveTable(1, "Overlap", "0900000003", 2, baseTime.AddMinutes(60), 0, null);
        Assert.False(overlapRes.Success);

        // Non-overlapping slot (+130m) succeeds
        var nonOverlap = tableRepo.ReserveTable(1, "Later", "0900000004", 2, baseTime.AddMinutes(130), 0, null);
        Assert.True(nonOverlap.Success);

        // Non-owner Member cannot cancel Member One's reservation
        var forbiddenCancel = tableRepo.CancelReservation(r1.Reservation!.ReservationId, callerAccountId: 9, isStaff: false);
        Assert.False(forbiddenCancel.Success);
        Assert.True(forbiddenCancel.Forbidden);

        // Cancel the second reservation so table 1 only has r1
        var ownerCancelLater = tableRepo.CancelReservation(nonOverlap.Reservation!.ReservationId, callerAccountId: 1, isStaff: true);
        Assert.True(ownerCancelLater.Success);

        // SyncReservationStates 40m before r1 ArrivalTime -> locks table to Status = 3
        var lockSync = tableRepo.SyncReservationStates(baseTime.AddMinutes(-40));
        Assert.Equal(1, lockSync.LockedCount);
        Assert.Equal(3, (await fx.Context.DiningTables.FindAsync(1))!.Status);

        // Create second reservation on Table 2 and expire it past +30m grace -> Status = 4 (NoShow) & table freed to 0
        var r2Arrival = DateTime.Now.AddMinutes(20);
        var r2 = tableRepo.ReserveTable(2, "Late Guest", "0900000005", 2, r2Arrival, 0, null);
        Assert.True(r2.Success);
        Assert.Equal(3, (await fx.Context.DiningTables.FindAsync(2))!.Status);

        var expireSync = tableRepo.SyncReservationStates(r2Arrival.AddMinutes(31));
        Assert.True(expireSync.ExpiredCount >= 1);
        Assert.Equal(4, (await fx.Context.Reservations.FindAsync(r2.Reservation!.ReservationId))!.Status);
        Assert.Equal(0, (await fx.Context.DiningTables.FindAsync(2))!.Status);

        // Check-In r1 -> first order auto-applies DepositAmount (100,000đ)
        var checkIn = tableRepo.CheckInReservation(r1.Reservation.ReservationId);
        Assert.True(checkIn.Success);
        Assert.Equal(100000m, checkIn.DepositAmount);
        Assert.Equal(1, (await fx.Context.DiningTables.FindAsync(1))!.Status);

        // Order 2x Bạc Xỉu = 90,000đ (< 100k deposit -> 0đ remaining)
        var orderRes = await orderRepo.CreateOrderAsync(new CreateOrderDto
        {
            TableId = 1,
            Items = new List<CreateOrderItemDto> { new() { ProductId = 1, Quantity = 2 } }
        }, authenticatedAccountId: 2);

        Assert.True(orderRes.Success);
        Assert.Equal(100000m, orderRes.Order!.PaidAmount);
        Assert.Equal(0m, orderRes.Order.RemainingAmount);
        Assert.Contains("Deposit", orderRes.Order.PaymentMethods);

        // Finalize 0đ remaining completes order cleanly
        var finalize = await payRepo.ProcessPaymentAsync(orderRes.Order.OrderId, "Cash", 0m, null, null, 2);
        Assert.True(finalize.Success);
        Assert.True(finalize.Payment!.IsFullyPaid);
        Assert.Equal(3, (await fx.Context.Orders.FindAsync(orderRes.Order.OrderId))!.Status);
    }

    [Fact]
    public async Task CsvExport_FiltersSearch_IncludesAccountingColumns_And_SanitizesFormulas()
    {
        using var fx = new TestFixture();
        var orderRepo = new OrderRepository(fx.Context);

        var created = await orderRepo.CreateOrderAsync(new CreateOrderDto
        {
            TableId = 1,
            CustomerName = "=SUM(A1:A2)",
            PhoneNumber = "0908888888",
            DiscountCode = "FREE5K",
            Note = "+cmd|' /C calc'!A0",
            Items = new List<CreateOrderItemDto> { new() { ProductId = 1, Quantity = 1 } }
        }, authenticatedAccountId: 2);

        Assert.True(created.Success);

        string csvMatch = await orderRepo.ExportOrdersCsvAsync(search: "0908888888");
        string csvMiss = await orderRepo.ExportOrdersCsvAsync(search: "KHONGTONTAI999");

        Assert.Contains("OrderId,OrderCode,CreatedAt,TableName,CustomerName,PhoneNumber,OrderType,DiscountCode,TotalAmount,DiscountAmount,FinalAmount,PaidAmount,PaymentMethods,Status,PaymentStatus,Note", csvMatch);
        Assert.Contains("\"'=SUM(A1:A2)\"", csvMatch);
        Assert.Contains("\"'+cmd|' /C calc'!A0\"", csvMatch);
        Assert.Contains("\"FREE5K\"", csvMatch);
        Assert.Contains("45000", csvMatch);
        Assert.DoesNotContain("0908888888", csvMiss);
    }

    [Fact]
    public async Task VoucherWallet_CancelProtection_GuestToken_Idor_ShiftIsolation_And_LoyaltyPhone()
    {
        using var fx = new TestFixture();
        var loyaltyRepo = new LoyaltyRepository(fx.Context);
        var discRepo = new DiscountRepository(fx.Context);
        var orderRepo = new OrderRepository(fx.Context);
        var payRepo = new PaymentRepository(fx.Context);
        var shiftRepo = new ShiftRepository(fx.Context);

        // 1. PointsCost > 0 voucher cannot be used before redeeming
        var preCheck = await discRepo.ValidateDiscountAsync("VIP10", 100000m, accountId: 8);
        Assert.False(preCheck.IsValid);

        var unredeemedOrder = await orderRepo.CreateOrderAsync(new CreateOrderDto
        {
            OrderType = 2,
            DiscountCode = "VIP10",
            Items = new List<CreateOrderItemDto> { new() { ProductId = 1, Quantity = 2 } }
        }, authenticatedAccountId: 8);
        Assert.False(unredeemedOrder.Success);

        // Redeem once -> 1st order succeeds, 2nd fails
        var redeem = await loyaltyRepo.RedeemVoucherAsync(8, "VIP10");
        Assert.True(redeem.Success);
        Assert.Equal(300, redeem.RemainingPoints);

        var firstOrder = await orderRepo.CreateOrderAsync(new CreateOrderDto
        {
            OrderType = 2,
            DiscountCode = "VIP10",
            Items = new List<CreateOrderItemDto> { new() { ProductId = 1, Quantity = 2 } } // 90k - 10% = 81k
        }, authenticatedAccountId: 8);
        Assert.True(firstOrder.Success);
        Assert.Equal(9000m, firstOrder.Order!.DiscountAmount);

        var secondOrderFail = await orderRepo.CreateOrderAsync(new CreateOrderDto
        {
            OrderType = 2,
            DiscountCode = "VIP10",
            Items = new List<CreateOrderItemDto> { new() { ProductId = 1, Quantity = 2 } }
        }, authenticatedAccountId: 8);
        Assert.False(secondOrderFail.Success);

        // Cancel unpaid 1st order via UpdateOrderStatusAsync(4) -> refunds voucher + restores BOM stock
        Assert.Equal(20m, (await fx.Context.Ingredients.FindAsync(1))!.CurrentStock); // 100 - 80 = 20
        var cancelFirst = await orderRepo.UpdateOrderStatusAsync(firstOrder.Order.OrderId, 4, canCompleteOrCancel: true);
        Assert.True(cancelFirst.Success);
        Assert.Equal(100m, (await fx.Context.Ingredients.FindAsync(1))!.CurrentStock);

        var ownedCounts = await discRepo.GetOwnedVoucherCountsAsync(8);
        Assert.Equal(1, ownedCounts["VIP10"]);

        // 2. Anonymous QR guestToken & IDOR Lookup
        var anonOrder = await orderRepo.CreateOrderAsync(new CreateOrderDto
        {
            TableId = 1,
            Items = new List<CreateOrderItemDto> { new() { ProductId = 1, Quantity = 1 } }
        }, authenticatedAccountId: null);
        Assert.True(anonOrder.Success);
        Assert.False(string.IsNullOrWhiteSpace(anonOrder.Order!.GuestAccessToken));

        var badCancel = await orderRepo.CancelUnpaidOrderAsync(anonOrder.Order.OrderId, null, isStaff: false, guestToken: "wrong-token");
        Assert.False(badCancel.Success);
        Assert.True(badCancel.Forbidden);

        // Anonymous Lookup returns empty (IDOR closed)
        Assert.Empty(await orderRepo.LookupOrdersAsync(anonOrder.Order.OrderCode, callerAccountId: null, isStaff: false));
        // Member 9 cannot see Member 8's orders
        Assert.Empty(await orderRepo.LookupOrdersAsync(firstOrder.Order.OrderCode, callerAccountId: 9, isStaff: false));

        var goodCancel = await orderRepo.CancelUnpaidOrderAsync(anonOrder.Order.OrderId, null, isStaff: false, guestToken: anonOrder.Order.GuestAccessToken);
        Assert.True(goodCancel.Success);

        // 3. Concurrent shifts isolation + partial VNPay + PhoneNumber loyalty award + block cancelling paid order
        var s1 = await shiftRepo.OpenShiftAsync(new OpenShiftDto { AccountId = 2, InitialCash = 1000000m });
        var s2 = await shiftRepo.OpenShiftAsync(new OpenShiftDto { AccountId = 3, InitialCash = 500000m });
        Assert.True(s1.Success);
        Assert.True(s2.Success);

        var staffOrder = await orderRepo.CreateOrderAsync(new CreateOrderDto
        {
            TableId = 2,
            PhoneNumber = "0908888888", // Member One (Account 8, currently 300 pts)
            Items = new List<CreateOrderItemDto> { new() { ProductId = 1, Quantity = 2 } } // 90,000đ
        }, authenticatedAccountId: 2);
        Assert.True(staffOrder.Success);

        // Generate VNPay URL for partial payment 40,000đ and build matching signed callback
        string hashSecret = "TEST_VNP_HASH_SECRET_123456";
        var vnpUrl = await payRepo.GenerateVnPayUrlAsync(
            staffOrder.Order!.OrderId,
            "TESTTMN",
            hashSecret,
            "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html",
            "http://localhost/return",
            "127.0.0.1",
            customAmount: 40000m);
        Assert.True(vnpUrl.Success);

        var queryUri = new Uri(vnpUrl.PaymentUrl!);
        var vnpParams = ParseQuery(queryUri.Query);
        var callbackParams = new SortedDictionary<string, string>(StringComparer.Ordinal)
        {
            ["vnp_Amount"] = vnpParams["vnp_Amount"],
            ["vnp_ResponseCode"] = "00",
            ["vnp_TmnCode"] = "TESTTMN",
            ["vnp_TransactionNo"] = "VNP-999001",
            ["vnp_TransactionStatus"] = "00",
            ["vnp_TxnRef"] = vnpParams["vnp_TxnRef"]
        };
        callbackParams["vnp_SecureHash"] = ComputeVnPayHash(hashSecret, callbackParams);

        var cbRes = await payRepo.ProcessVnPayCallbackAsync(callbackParams, hashSecret, "TESTTMN");
        Assert.True(cbRes.Success);
        var afterPartial = await orderRepo.GetOrderByIdAsync(staffOrder.Order.OrderId);
        Assert.Equal(40000m, afterPartial!.PaidAmount);
        Assert.Equal(50000m, afterPartial.RemainingAmount);
        Assert.Equal(0, afterPartial.PaymentStatus);

        // Cannot cancel an order that already has real payment
        var blockedCancel = await orderRepo.UpdateOrderStatusAsync(staffOrder.Order.OrderId, 4, canCompleteOrCancel: true);
        Assert.False(blockedCancel.Success);

        // Pay remaining 50,000đ by Cash via Cashier 1 (Account 2) -> awards +90 loyalty pts to Member 8
        var finalCash = await payRepo.ProcessPaymentAsync(staffOrder.Order.OrderId, "Cash", 50000m, null, null, processedByAccountId: 2);
        Assert.True(finalCash.Success);
        Assert.True(finalCash.Payment!.IsFullyPaid);

        Assert.Equal(390, (await fx.Context.Accounts.FindAsync(8))!.LoyaltyPoints); // 300 + floor(90000 / 1000) = 390

        // Cashier 1 Z-report gets 50k Cash + 40k VNPay = 90k; Cashier 2 gets 0!
        var close1 = await shiftRepo.CloseShiftAsync(new CloseShiftDto { ShiftId = s1.Shift!.ShiftId, ActualCash = 1050000m }, 2, false);
        var close2 = await shiftRepo.CloseShiftAsync(new CloseShiftDto { ShiftId = s2.Shift!.ShiftId, ActualCash = 500000m }, 3, false);
        Assert.True(close1.Success);
        Assert.True(close2.Success);
        Assert.Equal(50000m, close1.Report!.TotalSalesCash);
        Assert.Equal(40000m, close1.Report.TotalSalesVnPay);
        Assert.Equal(0m, close2.Report!.TotalRevenue);
    }

    [Fact]
    public async Task TopSellingProducts_CountsOnlyPaidOrders_And_ExcludesUnpaid()
    {
        using var fx = new TestFixture();
        var orderRepo = new OrderRepository(fx.Context);
        var payRepo = new PaymentRepository(fx.Context);

        // Increase coffee stock so multiple orders succeed
        var coffee = await fx.Context.Ingredients.FindAsync(1);
        coffee!.CurrentStock = 1000m;
        var milk = await fx.Context.Ingredients.FindAsync(2);
        milk!.CurrentStock = 1000m;
        await fx.Context.SaveChangesAsync();

        // Unpaid order: 3x Product 1 (must NOT be counted in top-selling)
        var unpaid = await orderRepo.CreateOrderAsync(new CreateOrderDto
        {
            TableId = 1,
            Items = new List<CreateOrderItemDto> { new() { ProductId = 1, Quantity = 3 } }
        }, authenticatedAccountId: 2);
        Assert.True(unpaid.Success);

        // Paid order: 2x Product 1 (MUST be counted in top-selling)
        var paid = await orderRepo.CreateOrderAsync(new CreateOrderDto
        {
            TableId = 2,
            Items = new List<CreateOrderItemDto> { new() { ProductId = 1, Quantity = 2 } }
        }, authenticatedAccountId: 2);
        Assert.True(paid.Success);

        var payRes = await payRepo.ProcessPaymentAsync(paid.Order!.OrderId, "Cash", paid.Order.FinalAmount, null, null, 2);
        Assert.True(payRes.Success);

        var top = await orderRepo.GetTopSellingProductsAsync();
        Assert.Single(top);
        Assert.Equal(1, top[0].ProductId);
        Assert.Equal(2, top[0].TotalQuantity);
        Assert.Equal(90000m, top[0].TotalRevenue);
    }

    [Fact]
    public async Task RequiredAttributes_EnforcedOnOrder_And_IncludedInProductList()
    {
        using var fx = new TestFixture();
        fx.Context.Products.Add(new Product
        {
            ProductId = 3,
            CategoryId = 1,
            ProductName = "Trà Sữa Đặc Biệt",
            Price = 50000m,
            Unit = "Ly",
            ImageUrl = "/img/3.png",
            IsAvailable = true,
            IsFeatured = true
        });
        fx.Context.ProductAttributes.AddRange(
            new ProductAttribute { AttributeId = 10, ProductId = 3, AttributeGroup = "Độ ngọt", AttributeName = "50% Đường", ExtraPrice = 0, IsRequired = true },
            new ProductAttribute { AttributeId = 11, ProductId = 3, AttributeGroup = "Độ ngọt", AttributeName = "100% Đường", ExtraPrice = 0, IsRequired = true },
            new ProductAttribute { AttributeId = 12, ProductId = 3, AttributeGroup = "Topping", AttributeName = "Kem Cheese", ExtraPrice = 10000m, IsRequired = false }
        );
        await fx.Context.SaveChangesAsync();

        var prodRepo = new ProductRepository(fx.Context);
        var paged = await prodRepo.GetPagedProductsAsync(1, 20);
        var p3Dto = paged.Items.FirstOrDefault(p => p.ProductId == 3);
        Assert.NotNull(p3Dto);
        Assert.Equal(3, p3Dto!.Attributes.Count);
        Assert.Contains(p3Dto.Attributes, a => a.IsRequired && a.AttributeGroup == "Độ ngọt");

        var orderRepo = new OrderRepository(fx.Context);

        // Missing required group "Độ ngọt" (only optional Topping selected) -> rejected
        var missingReq = await orderRepo.CreateOrderAsync(new CreateOrderDto
        {
            TableId = 1,
            Items = new List<CreateOrderItemDto>
            {
                new()
                {
                    ProductId = 3,
                    Quantity = 1,
                    Modifiers = new List<OrderItemModifierDto>
                    {
                        new() { AttributeId = 12, ModifierName = "Kem Cheese", ExtraPrice = 10000m }
                    }
                }
            }
        }, authenticatedAccountId: 2);
        Assert.False(missingReq.Success);
        Assert.Contains("Độ ngọt", missingReq.Message);

        // Selecting required attribute succeeds
        var withReq = await orderRepo.CreateOrderAsync(new CreateOrderDto
        {
            TableId = 1,
            Items = new List<CreateOrderItemDto>
            {
                new()
                {
                    ProductId = 3,
                    Quantity = 1,
                    Modifiers = new List<OrderItemModifierDto>
                    {
                        new() { AttributeId = 10, ModifierName = "50% Đường", ExtraPrice = 0 }
                    }
                }
            }
        }, authenticatedAccountId: 2);
        Assert.True(withReq.Success);
    }

    [Fact]
    public async Task OtpExpiries_AreSeparated_BetweenEmailVerification_And_PasswordReset()
    {
        using var fx = new TestFixture();
        var acc = await fx.Context.Accounts.FindAsync(8);
        acc!.Email = "member1@example.com";
        acc.IsEmailVerified = false;
        await fx.Context.SaveChangesAsync();

        var accRepo = new AccountRepository(fx.Context);

        // Issue password reset OTP (+5m) first
        var resetIssued = await accRepo.IssuePasswordResetOtpAsync("member1@example.com");
        Assert.True(resetIssued.Success);
        var resetExpiryBefore = resetIssued.Account!.ResetPasswordExpiry;
        Assert.NotNull(resetExpiryBefore);
        Assert.InRange((resetExpiryBefore!.Value - DateTime.Now).TotalMinutes, 4.0, 5.5);

        // Issue email verification OTP (+15m) -> must NOT overwrite ResetPasswordExpiry!
        var emailIssued = await accRepo.IssueEmailVerificationOtpAsync("member1@example.com");
        Assert.True(emailIssued.Success);
        Assert.NotNull(emailIssued.Account!.EmailVerificationExpiry);
        Assert.InRange((emailIssued.Account.EmailVerificationExpiry!.Value - DateTime.Now).TotalMinutes, 14.0, 15.5);
        Assert.Equal(resetExpiryBefore, emailIssued.Account.ResetPasswordExpiry);

        // Verify email OTP clears EmailVerificationExpiry without touching ResetPasswordExpiry
        var verified = await accRepo.VerifyEmailOtpAsync("member1@example.com", emailIssued.Otp!);
        Assert.True(verified.Success);
        Assert.True(emailIssued.Account.IsEmailVerified);
        Assert.Null(emailIssued.Account.EmailVerificationExpiry);
        Assert.Equal(resetExpiryBefore, emailIssued.Account.ResetPasswordExpiry);

        // Password reset OTP still works independently
        var resetRes = await accRepo.ResetPasswordWithOtpAsync("member1@example.com", resetIssued.Otp!, "newpass123");
        Assert.True(resetRes.Success);
        Assert.Null(emailIssued.Account.ResetPasswordExpiry);
    }

    [Fact]
    public async Task OfflineDineInOrder_OnOccupiedTable_MergesIntoActiveOrder_And_RespectsIdempotency()
    {
        using var fx = new TestFixture();
        var coffee = await fx.Context.Ingredients.FindAsync(1);
        coffee!.CurrentStock = 1000m;
        var milk = await fx.Context.Ingredients.FindAsync(2);
        milk!.CurrentStock = 1000m;
        await fx.Context.SaveChangesAsync();

        var orderRepo = new OrderRepository(fx.Context);

        // Table 1 already has an active unpaid order (1x Bạc Xỉu = 45k)
        var initial = await orderRepo.CreateOrderAsync(new CreateOrderDto
        {
            TableId = 1,
            Items = new List<CreateOrderItemDto> { new() { ProductId = 1, Quantity = 1 } }
        }, authenticatedAccountId: 2);
        Assert.True(initial.Success);

        // Non-offline order on occupied Table 1 still fails
        var onlineReject = await orderRepo.CreateOrderAsync(new CreateOrderDto
        {
            TableId = 1,
            Items = new List<CreateOrderItemDto> { new() { ProductId = 1, Quantity = 1 } }
        }, authenticatedAccountId: 2);
        Assert.False(onlineReject.Success);
        Assert.Contains("hiện đang có khách", onlineReject.Message);

        // Offline dine-in sync (OfflineOrderId > 0 + IdempotencyKey) merges into existing active order
        string idempKey = "offline-merge-key-001";
        var merged = await orderRepo.CreateOrderAsync(new CreateOrderDto
        {
            TableId = 1,
            OfflineOrderId = 42,
            IdempotencyKey = idempKey,
            Items = new List<CreateOrderItemDto> { new() { ProductId = 1, Quantity = 2 } }
        }, authenticatedAccountId: 2);
        Assert.True(merged.Success);
        Assert.Equal(initial.Order!.OrderId, merged.Order!.OrderId);
        Assert.Equal(135000m, merged.Order.TotalAmount); // 45k + 90k
        Assert.Equal(1, await fx.Context.Orders.CountAsync());

        // Retry with same IdempotencyKey returns existing merged order without duplicating items
        var retry = await orderRepo.CreateOrderAsync(new CreateOrderDto
        {
            TableId = 1,
            OfflineOrderId = 42,
            IdempotencyKey = idempKey,
            Items = new List<CreateOrderItemDto> { new() { ProductId = 1, Quantity = 2 } }
        }, authenticatedAccountId: 2);
        Assert.True(retry.Success);
        Assert.Equal(initial.Order.OrderId, retry.Order!.OrderId);
        Assert.Equal(135000m, retry.Order.TotalAmount);
    }

    [Fact]
    public async Task LockingAccount_SetsIsActiveFalse_And_BlocksLogin()
    {
        using var fx = new TestFixture();
        var accRepo = new AccountRepository(fx.Context);

        var member = await fx.Context.Accounts.FindAsync(8);
        member!.PasswordHash = WebApi.Services.PasswordHasher.HashPassword("secret123");
        await fx.Context.SaveChangesAsync();

        var lockRes = await accRepo.UpdateStatusAsync(8, isActive: false, actorAccountId: 1);
        Assert.True(lockRes.Success);
        Assert.False((await fx.Context.Accounts.FindAsync(8))!.IsActive);

        var loginAfterLock = await accRepo.LoginAsync(new LoginDto { Username = "member1", Password = "secret123" });
        Assert.False(loginAfterLock.Success);
    }

    private static Dictionary<string, string> ParseQuery(string query)
    {
        var dict = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var pair in query.TrimStart('?').Split('&', StringSplitOptions.RemoveEmptyEntries))
        {
            var idx = pair.IndexOf('=');
            if (idx <= 0) continue;
            dict[WebUtility.UrlDecode(pair[..idx])] = WebUtility.UrlDecode(pair[(idx + 1)..]);
        }
        return dict;
    }

    private static string ComputeVnPayHash(string secret, SortedDictionary<string, string> sorted)
    {
        var sb = new StringBuilder();
        foreach (var kv in sorted)
        {
            if (sb.Length > 0) sb.Append('&');
            sb.Append(WebUtility.UrlEncode(kv.Key)).Append('=').Append(WebUtility.UrlEncode(kv.Value));
        }
        using var hmac = new HMACSHA512(Encoding.UTF8.GetBytes(secret));
        return Convert.ToHexString(hmac.ComputeHash(Encoding.UTF8.GetBytes(sb.ToString()))).ToLowerInvariant();
    }
}
