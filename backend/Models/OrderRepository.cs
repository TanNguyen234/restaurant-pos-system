using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;

namespace WebApi.Models;

public class OrderRepository : BaseRepository
{
    public OrderRepository(RestaurantPosContext context) : base(context) { }

    public List<Ingredient> LastLowStockAlerts { get; private set; } = new();
    public List<ProductAvailabilityChangeDto> LastAvailabilityChanges { get; private set; } = new();

    private static readonly object _orderCodeLock = new();

    private void ClearInventoryEventBuffer()
    {
        LastLowStockAlerts = new();
        LastAvailabilityChanges = new();
    }

    private static string GenerateOrderCode(int? offlineOrderId)
    {
        if (offlineOrderId.HasValue && offlineOrderId.Value > 0)
        {
            return $"ORD-OFF-{offlineOrderId.Value:D6}-{Guid.NewGuid().ToString("N")[..4].ToUpper()}";
        }

        lock (_orderCodeLock)
        {
            string datePart = DateTime.Now.ToString("yyyyMMdd");
            string randomPart = Guid.NewGuid().ToString("N")[..6].ToUpper();
            return $"ORD-{datePart}-{randomPart}";
        }
    }

    private static bool TokensEqual(string? a, string? b)
    {
        if (string.IsNullOrWhiteSpace(a) || string.IsNullOrWhiteSpace(b)) return false;
        byte[] ba = Encoding.UTF8.GetBytes(a.Trim());
        byte[] bb = Encoding.UTF8.GetBytes(b.Trim());
        return ba.Length == bb.Length && CryptographicOperations.FixedTimeEquals(ba, bb);
    }

    public async Task<bool> VerifyGuestTokenAsync(int orderId, string? guestToken)
    {
        if (string.IsNullOrWhiteSpace(guestToken)) return false;
        var token = await context.Orders
            .Where(o => o.OrderId == orderId)
            .Select(o => o.GuestAccessToken)
            .FirstOrDefaultAsync();
        return TokensEqual(token, guestToken);
    }

    private async Task<(bool Success, string Message, List<(OrderDetail Detail, List<OrderItemModifierDto> VerifiedModifiers)> Items, decimal Total)>
        ValidateAndBuildOrderItemsAsync(List<CreateOrderItemDto> rawItems, string? notePrefix = null)
    {
        var result = new List<(OrderDetail, List<OrderItemModifierDto>)>();
        decimal total = 0;

        var productIds = rawItems.Select(i => i.ProductId).Distinct().ToList();
        var products = await context.Products
            .Where(p => productIds.Contains(p.ProductId))
            .ToDictionaryAsync(p => p.ProductId);

        var dbAttributes = await context.ProductAttributes
            .Where(a => productIds.Contains(a.ProductId))
            .ToListAsync();

        foreach (var item in rawItems)
        {
            if (item.Quantity <= 0)
                return (false, "Số lượng món ăn phải lớn hơn 0", result, 0);

            if (!products.TryGetValue(item.ProductId, out var product))
                return (false, $"Món ăn với ID {item.ProductId} không tồn tại trong thực đơn", result, 0);

            if (!product.IsAvailable)
                return (false, $"Món '{product.ProductName}' hiện đang tạm hết, không thể đặt", result, 0);

            var productAttrs = dbAttributes.Where(a => a.ProductId == item.ProductId).ToList();
            var verifiedMods = new List<OrderItemModifierDto>();
            decimal modifierExtra = 0;

            if (item.Modifiers != null && item.Modifiers.Count > 0)
            {
                foreach (var mod in item.Modifiers)
                {
                    if (mod.ExtraPrice < 0)
                    {
                        return (false, $"Phụ thu tùy chọn '{mod.ModifierName}' không hợp lệ (không được âm)", result, 0);
                    }

                    ProductAttribute? matched = null;
                    if (mod.AttributeId.HasValue && mod.AttributeId.Value > 0)
                    {
                        matched = productAttrs.FirstOrDefault(a => a.AttributeId == mod.AttributeId.Value);
                        if (matched == null)
                        {
                            return (false, $"Thuộc tính #{mod.AttributeId} không thuộc về món '{product.ProductName}'", result, 0);
                        }
                    }
                    else if (!string.IsNullOrWhiteSpace(mod.ModifierName))
                    {
                        var modNameTrim = mod.ModifierName.Trim();
                        matched = productAttrs.FirstOrDefault(a =>
                            modNameTrim.Equals(a.AttributeName, StringComparison.OrdinalIgnoreCase) ||
                            modNameTrim.Equals($"{a.AttributeGroup}: {a.AttributeName}", StringComparison.OrdinalIgnoreCase));
                    }

                    if (matched != null)
                    {
                        modifierExtra += matched.ExtraPrice;
                        verifiedMods.Add(new OrderItemModifierDto
                        {
                            AttributeId = matched.AttributeId,
                            ModifierName = string.IsNullOrWhiteSpace(mod.ModifierName) ? matched.AttributeName : mod.ModifierName.Trim(),
                            ExtraPrice = matched.ExtraPrice
                        });
                    }
                    else
                    {
                        if (mod.ExtraPrice > 0)
                        {
                            return (false, $"Tùy chọn '{mod.ModifierName}' không có phụ thu hợp lệ trên hệ thống", result, 0);
                        }
                        if (!string.IsNullOrWhiteSpace(mod.ModifierName))
                        {
                            verifiedMods.Add(new OrderItemModifierDto
                            {
                                ModifierName = mod.ModifierName.Trim(),
                                ExtraPrice = 0
                            });
                        }
                    }
                }
            }

            var requiredGroups = productAttrs
                .Where(a => a.IsRequired)
                .Select(a => a.AttributeGroup)
                .Where(g => !string.IsNullOrWhiteSpace(g))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();

            foreach (var reqGroup in requiredGroups)
            {
                var groupAttrIds = productAttrs
                    .Where(a => a.AttributeGroup.Equals(reqGroup, StringComparison.OrdinalIgnoreCase))
                    .Select(a => a.AttributeId)
                    .ToHashSet();

                if (!verifiedMods.Any(m => m.AttributeId.HasValue && groupAttrIds.Contains(m.AttributeId.Value)))
                {
                    return (false, $"Vui lòng chọn tùy chọn bắt buộc '{reqGroup}' cho món '{product.ProductName}'", result, 0);
                }
            }

            decimal unitPrice = product.Price + modifierExtra;
            decimal subTotal = unitPrice * item.Quantity;
            total += subTotal;

            string? finalNote = item.ItemNote?.Trim();
            if (!string.IsNullOrEmpty(notePrefix))
            {
                finalNote = string.IsNullOrWhiteSpace(finalNote) ? notePrefix : $"{notePrefix} {finalNote}";
            }

            var detail = new OrderDetail
            {
                ProductId = item.ProductId,
                Quantity = item.Quantity,
                UnitPrice = unitPrice,
                SubTotal = subTotal,
                ItemNote = finalNote,
                CookingStatus = 0
            };

            result.Add((detail, verifiedMods));
        }

        return (true, "OK", result, total);
    }

    private async Task<(bool Success, string Message, decimal DiscountAmount, string? AppliedCode, AccountVoucher? ConsumedVoucher)>
        ValidateAndReserveVoucherAsync(string? rawCode, decimal orderTotal, int? callerAccountId)
    {
        if (string.IsNullOrWhiteSpace(rawCode))
            return (true, "OK", 0, null, null);

        string normCode = rawCode.Trim().ToUpperInvariant();
        var disc = await context.Discounts.FirstOrDefaultAsync(d => d.Code.ToUpper() == normCode);
        if (disc == null || !disc.IsActive)
            return (false, $"Mã giảm giá '{rawCode}' không tồn tại hoặc đã ngừng áp dụng", 0, null, null);

        if (disc.ExpiryDate.HasValue && disc.ExpiryDate.Value < DateTime.Now)
            return (false, $"Mã giảm giá '{rawCode}' đã hết hạn sử dụng", 0, null, null);

        if (disc.MaxUsageCount.HasValue && disc.UsedCount >= disc.MaxUsageCount.Value)
            return (false, $"Mã giảm giá '{rawCode}' đã hết lượt sử dụng", 0, null, null);

        AccountVoucher? matchedVoucher = null;
        if (disc.PointsCost > 0)
        {
            if (!callerAccountId.HasValue || callerAccountId.Value <= 0)
            {
                return (false, $"Mã '{disc.Code}' yêu cầu đăng nhập và đổi {disc.PointsCost} PTS trước khi áp dụng", 0, null, null);
            }

            matchedVoucher = await context.AccountVouchers
                .Where(av => av.AccountId == callerAccountId.Value && av.DiscountId == disc.DiscountId && av.Status == 0)
                .OrderBy(av => av.RedeemedAt)
                .FirstOrDefaultAsync();

            if (matchedVoucher == null)
            {
                return (false, $"Bạn chưa đổi mã '{disc.Code}' ({disc.PointsCost} PTS) hoặc đã hết lượt dùng. Vui lòng vào mục Hội viên để đổi trước.", 0, null, null);
            }
        }

        if (orderTotal < disc.MinOrderAmount)
            return (false, $"Mã '{disc.Code}' yêu cầu đơn hàng tối thiểu {disc.MinOrderAmount:N0}đ", 0, null, null);

        decimal discountAmount = 0;
        if (disc.DiscountAmount > 0) discountAmount = disc.DiscountAmount;
        else if (disc.DiscountPercent > 0)
        {
            discountAmount = Math.Round(orderTotal * (disc.DiscountPercent / 100m), 0);
            if (disc.MaxDiscountAmount > 0 && discountAmount > disc.MaxDiscountAmount)
                discountAmount = disc.MaxDiscountAmount;
        }
        discountAmount = Math.Min(discountAmount, orderTotal);
        disc.UsedCount += 1;

        return (true, "OK", discountAmount, disc.Code, matchedVoucher);
    }

    private async Task RecalculateDiscountForOrderAsync(Order order)
    {
        order.TotalAmount = Math.Max(0, order.TotalAmount);
        if (!string.IsNullOrWhiteSpace(order.DiscountCode))
        {
            string normCode = order.DiscountCode.Trim().ToUpperInvariant();
            var disc = await context.Discounts.FirstOrDefaultAsync(d => d.Code.ToUpper() == normCode);
            if (disc != null)
            {
                if (order.TotalAmount < disc.MinOrderAmount)
                {
                    order.DiscountAmount = 0;
                }
                else
                {
                    decimal discAmt = 0;
                    if (disc.DiscountAmount > 0) discAmt = disc.DiscountAmount;
                    else if (disc.DiscountPercent > 0)
                    {
                        discAmt = Math.Round(order.TotalAmount * (disc.DiscountPercent / 100m), 0);
                        if (disc.MaxDiscountAmount > 0 && discAmt > disc.MaxDiscountAmount)
                            discAmt = disc.MaxDiscountAmount;
                    }
                    order.DiscountAmount = Math.Min(discAmt, order.TotalAmount);
                }
                order.FinalAmount = Math.Max(0, order.TotalAmount - order.DiscountAmount);
                return;
            }
        }

        order.DiscountAmount = Math.Min(Math.Max(0, order.DiscountAmount), order.TotalAmount);
        order.FinalAmount = Math.Max(0, order.TotalAmount - order.DiscountAmount);
    }

    private async Task ReleaseOrderDiscountsAsync(Order order)
    {
        if (!string.IsNullOrWhiteSpace(order.DiscountCode))
        {
            string norm = order.DiscountCode.Trim().ToUpperInvariant();
            var disc = await context.Discounts.FirstOrDefaultAsync(d => d.Code.ToUpper() == norm);
            if (disc != null && disc.UsedCount > 0)
            {
                disc.UsedCount -= 1;
            }
        }

        var usedVouchers = await context.AccountVouchers
            .Where(av => av.UsedOrderId == order.OrderId && av.Status == 1)
            .ToListAsync();
        foreach (var uv in usedVouchers)
        {
            uv.Status = 0;
            uv.UsedAt = null;
            uv.UsedOrderId = null;
        }
    }

    private static string? ResolveDeliveryAddress(CreateOrderDto dto)
    {
        if (!string.IsNullOrWhiteSpace(dto.DeliveryAddress)) return dto.DeliveryAddress.Trim();
        // Tương thích đơn xếp hàng offline cũ: địa chỉ nằm trong ghi chú dạng "Giao tới: <địa chỉ> | <ghi chú>"
        const string prefix = "Giao tới:";
        var note = dto.Note?.Trim();
        if (string.IsNullOrEmpty(note) || !note.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) return null;
        var addr = note.Substring(prefix.Length).Split('|')[0].Trim();
        return addr.Length == 0 ? null : addr;
    }

    public async Task<(bool Success, string Message, OrderDto? Order)> CreateOrderAsync(CreateOrderDto dto, int? authenticatedAccountId = null)
    {
        ClearInventoryEventBuffer();
        if (dto.Items == null || dto.Items.Count == 0)
            return (false, "Đơn hàng phải có ít nhất một món ăn hoặc thức uống", null);

        string? idempotencyKey = string.IsNullOrWhiteSpace(dto.IdempotencyKey) ? null : dto.IdempotencyKey.Trim();

        if (idempotencyKey != null)
        {
            var existingIdemp = await context.OrderIdempotencyKeys.FirstOrDefaultAsync(k => k.IdempotencyKey == idempotencyKey);
            if (existingIdemp != null)
            {
                var existingDto = await GetOrderByIdAsync(existingIdemp.OrderId, includeGuestToken: true);
                return (true, "Đơn hàng đã được đồng bộ trước đó (Idempotent)", existingDto);
            }

            var existingByKey = await context.Orders.FirstOrDefaultAsync(o => o.IdempotencyKey == idempotencyKey);
            if (existingByKey != null)
            {
                var existingDto = await GetOrderByIdAsync(existingByKey.OrderId, includeGuestToken: true);
                return (true, "Đơn hàng đã được đồng bộ trước đó (Idempotent)", existingDto);
            }
        }
        else if (dto.OfflineOrderId.HasValue && dto.OfflineOrderId.Value > 0)
        {
            string legacyPrefix = $"ORD-OFF-{dto.OfflineOrderId.Value:D6}";
            var existingIdemp = await context.OrderIdempotencyKeys.FirstOrDefaultAsync(k => k.IdempotencyKey == legacyPrefix);
            if (existingIdemp != null)
            {
                var existingDto = await GetOrderByIdAsync(existingIdemp.OrderId, includeGuestToken: true);
                return (true, "Đơn hàng đã được đồng bộ trước đó (Idempotent)", existingDto);
            }
            var existingByOffline = await context.Orders.FirstOrDefaultAsync(o => o.OrderCode == legacyPrefix);
            if (existingByOffline != null)
            {
                var existingDto = await GetOrderByIdAsync(existingByOffline.OrderId, includeGuestToken: true);
                return (true, "Đơn hàng đã được đồng bộ trước đó (Idempotent)", existingDto);
            }
        }

        // Ràng buộc loại đơn: 1 = Tại bàn (bắt buộc có bàn), 2 = Mang về (không gắn bàn), 3 = Giao hàng (không gắn bàn, cần SĐT + địa chỉ)
        int orderType = dto.OrderType is >= 1 and <= 3 ? dto.OrderType : 1;
        string? deliveryAddress = null;
        if (orderType == 1)
        {
            if (!dto.TableId.HasValue || dto.TableId.Value <= 0)
                return (false, "Đơn tại bàn phải chọn bàn. Nếu khách mang về hoặc cần giao hàng, hãy chọn loại đơn tương ứng.", null);
        }
        else
        {
            dto.TableId = null;
            if (orderType == 3)
            {
                deliveryAddress = ResolveDeliveryAddress(dto);
                if (string.IsNullOrWhiteSpace(dto.PhoneNumber))
                    return (false, "Đơn giao hàng bắt buộc có số điện thoại khách", null);
                if (string.IsNullOrWhiteSpace(deliveryAddress))
                    return (false, "Đơn giao hàng bắt buộc có địa chỉ giao", null);
            }
        }

        var validatedItems = await ValidateAndBuildOrderItemsAsync(dto.Items);
        if (!validatedItems.Success)
            return (false, validatedItems.Message, null);

        decimal serverTotal = validatedItems.Total;
        string orderCode = idempotencyKey != null
            ? GenerateOrderCode(null)
            : (dto.OfflineOrderId.HasValue && dto.OfflineOrderId.Value > 0 ? $"ORD-OFF-{dto.OfflineOrderId.Value:D6}" : GenerateOrderCode(null));

        int? mergeTargetOrderId = null;
        using (var transaction = await context.Database.BeginTransactionAsync())
        {
            try
            {
                if (idempotencyKey != null)
                {
                    var dup = await context.Orders.FirstOrDefaultAsync(o => o.IdempotencyKey == idempotencyKey);
                    if (dup != null)
                    {
                        await transaction.RollbackAsync();
                        return (true, "Đơn hàng đã được đồng bộ trước đó (Idempotent)", await GetOrderByIdAsync(dup.OrderId, includeGuestToken: true));
                    }
                }

                new TableRepository(context).SyncReservationStates();

                DiningTable? table = null;
                if (dto.TableId.HasValue && dto.TableId.Value > 0)
                {
                    table = await context.DiningTables.FindAsync(dto.TableId.Value);
                    if (table == null)
                    {
                        await transaction.RollbackAsync();
                        return (false, "Bàn ăn được chọn không tồn tại trong hệ thống", null);
                    }

                    var activeTableOrder = await context.Orders
                        .FirstOrDefaultAsync(o => o.TableId == table.TableId && o.Status < 3 && o.PaymentStatus == 0);
                    if (activeTableOrder != null)
                    {
                        await transaction.RollbackAsync();
                        if (dto.OfflineOrderId.HasValue && dto.OfflineOrderId.Value > 0)
                        {
                            mergeTargetOrderId = activeTableOrder.OrderId;
                        }
                        else
                        {
                            return (false, $"Bàn '{table.TableName}' hiện đang có khách (Đơn #{activeTableOrder.OrderCode})", null);
                        }
                    }
                    else if (table.Status == 3)
                    {
                        await transaction.RollbackAsync();
                        return (false, $"Bàn '{table.TableName}' đang được đặt trước, vui lòng check-in trước khi gọi món", null);
                    }
                }

                if (!mergeTargetOrderId.HasValue)
                {
                    int? effectiveAccountId = authenticatedAccountId ?? dto.AccountId;
                    var voucherCheck = await ValidateAndReserveVoucherAsync(dto.DiscountCode, serverTotal, effectiveAccountId);
                    if (!voucherCheck.Success)
                    {
                        await transaction.RollbackAsync();
                        return (false, voucherCheck.Message, null);
                    }

                    decimal discountAmount = voucherCheck.DiscountAmount;
                    string? appliedCode = voucherCheck.AppliedCode;
                    decimal finalAmount = Math.Max(0, serverTotal - discountAmount);
                    string? guestToken = effectiveAccountId == null ? Guid.NewGuid().ToString("N") : null;

                    var order = new Order
                    {
                        OrderCode = orderCode,
                        IdempotencyKey = idempotencyKey,
                        GuestAccessToken = guestToken,
                        TableId = dto.TableId,
                        AccountId = effectiveAccountId,
                        CustomerName = string.IsNullOrWhiteSpace(dto.CustomerName) ? "Khách vãng lai" : dto.CustomerName.Trim(),
                        PhoneNumber = string.IsNullOrWhiteSpace(dto.PhoneNumber) ? null : dto.PhoneNumber.Trim(),
                        OrderType = orderType,
                        DeliveryAddress = deliveryAddress,
                        Note = dto.Note?.Trim(),
                        DiscountCode = appliedCode,
                        TotalAmount = serverTotal,
                        DiscountAmount = discountAmount,
                        FinalAmount = finalAmount,
                        Status = 0,
                        PaymentStatus = 0,
                        CreatedAt = DateTime.Now
                    };

                    context.Orders.Add(order);
                    await context.SaveChangesAsync();

                    if (voucherCheck.ConsumedVoucher != null)
                    {
                        voucherCheck.ConsumedVoucher.Status = 1;
                        voucherCheck.ConsumedVoucher.UsedAt = DateTime.Now;
                        voucherCheck.ConsumedVoucher.UsedOrderId = order.OrderId;
                        await context.SaveChangesAsync();
                    }

                    if (idempotencyKey != null)
                    {
                        context.OrderIdempotencyKeys.Add(new OrderIdempotencyKey
                        {
                            IdempotencyKey = idempotencyKey,
                            OrderId = order.OrderId,
                            CreatedAt = DateTime.Now
                        });
                        await context.SaveChangesAsync();
                    }

                    foreach (var (detail, _) in validatedItems.Items)
                    {
                        detail.OrderId = order.OrderId;
                        context.OrderDetails.Add(detail);
                    }
                    await context.SaveChangesAsync();

                    foreach (var (detail, modifiers) in validatedItems.Items)
                    {
                        foreach (var mod in modifiers)
                        {
                            context.OrderDetailModifiers.Add(new OrderDetailModifier
                            {
                                OrderDetailId = detail.OrderDetailId,
                                AttributeId = mod.AttributeId,
                                ModifierName = mod.ModifierName,
                                ExtraPrice = mod.ExtraPrice
                            });
                        }
                    }
                    await context.SaveChangesAsync();

                    if (table != null)
                    {
                        table.Status = 1; // Occupied
                        table.CurrentOrderId = order.OrderId;
                        table.UpdatedAt = DateTime.Now;
                        context.DiningTables.Update(table);

                        // Tự động cấn trừ tiền cọc đặt bàn (nếu bàn vừa Check-In và chưa áp dụng cọc vào đơn nào)
                        var checkedInRes = await context.Reservations
                            .Where(r => r.TableId == table.TableId &&
                                        r.Status == 2 &&
                                        !r.DepositApplied &&
                                        r.DepositAmount > 0 &&
                                        r.CheckedInOrderId == null)
                            .OrderByDescending(r => r.ReservationId)
                            .FirstOrDefaultAsync();

                        if (checkedInRes != null)
                        {
                            checkedInRes.DepositApplied = true;
                            checkedInRes.CheckedInOrderId = order.OrderId;

                            int? activeShiftId = null;
                            if (effectiveAccountId.HasValue)
                            {
                                activeShiftId = await context.Shifts
                                    .Where(s => s.AccountId == effectiveAccountId.Value && s.Status == 1)
                                    .OrderByDescending(s => s.StartTime)
                                    .Select(s => (int?)s.ShiftId)
                                    .FirstOrDefaultAsync();
                            }

                            context.Payments.Add(new Payment
                            {
                                OrderId = order.OrderId,
                                ShiftId = activeShiftId,
                                ProcessedByAccountId = effectiveAccountId,
                                PaymentMethod = "Deposit",
                                Amount = checkedInRes.DepositAmount,
                                TransactionRef = $"DEPOSIT-RES-{checkedInRes.ReservationId}",
                                Status = 1,
                                Note = $"Cấn trừ tiền cọc đặt bàn #{checkedInRes.ReservationId} ({checkedInRes.CustomerName})",
                                PaymentTime = DateTime.Now
                            });
                        }

                        await context.SaveChangesAsync();
                    }

                    var invRepo = new InventoryRepository(context);
                    var deductResult = await invRepo.DeductForOrderItemsAsync(
                        order.OrderId,
                        validatedItems.Items.Select(x => (
                            x.Detail.ProductId,
                            x.Detail.Quantity,
                            (IEnumerable<int>?)x.VerifiedModifiers.Where(m => m.AttributeId.HasValue).Select(m => m.AttributeId!.Value).ToList())),
                        effectiveAccountId);

                    if (!deductResult.Success)
                    {
                        await transaction.RollbackAsync();
                        return (false, deductResult.Message, null);
                    }

                    LastLowStockAlerts = deductResult.LowStockAlerts;
                    LastAvailabilityChanges = deductResult.AvailabilityChanges;

                    await transaction.CommitAsync();

                    var createdDto = await GetOrderByIdAsync(order.OrderId, includeGuestToken: true);
                    return (true, "Tạo đơn hàng thành công", createdDto);
                }
            }
            catch (Exception)
            {
                await transaction.RollbackAsync();
                return (false, "Lỗi lưu đơn hàng vào hệ thống", null);
            }
        }

        string mergeIdempKey = idempotencyKey ?? $"ORD-OFF-{dto.OfflineOrderId!.Value:D6}";
        return await AddItemsToOrderAsync(
            mergeTargetOrderId.Value,
            dto.Items,
            mergeIdempKey,
            dto.DiscountCode,
            authenticatedAccountId ?? dto.AccountId);
    }

    public async Task<List<OrderDto>> GetOrdersAsync(
        int? status = null,
        DateTime? fromDate = null,
        DateTime? toDate = null,
        string? search = null,
        int? onlyAccountId = null)
    {
        var query = from o in context.Orders
                    join t in context.DiningTables on o.TableId equals t.TableId into tGroup
                    from t in tGroup.DefaultIfEmpty()
                    join a in context.Accounts on o.AccountId equals a.AccountId into aGroup
                    from a in aGroup.DefaultIfEmpty()
                    select new
                    {
                        Order = o,
                        TableName = t != null ? t.TableName : null,
                        WaiterName = a != null ? a.FullName : null
                    };

        if (onlyAccountId.HasValue)
        {
            query = query.Where(x => x.Order.AccountId == onlyAccountId.Value);
        }

        if (status.HasValue)
        {
            query = query.Where(x => x.Order.Status == status.Value);
        }

        if (fromDate.HasValue)
        {
            var start = fromDate.Value.Date;
            query = query.Where(x => x.Order.CreatedAt >= start);
        }

        if (toDate.HasValue)
        {
            var endExclusive = toDate.Value.Date.AddDays(1);
            query = query.Where(x => x.Order.CreatedAt < endExclusive);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            string kw = search.Trim().ToLower();
            query = query.Where(x =>
                x.Order.OrderCode.ToLower().Contains(kw) ||
                (x.Order.CustomerName != null && x.Order.CustomerName.ToLower().Contains(kw)) ||
                (x.Order.PhoneNumber != null && x.Order.PhoneNumber.ToLower().Contains(kw)) ||
                (x.TableName != null && x.TableName.ToLower().Contains(kw)));
        }

        var rawList = await query.OrderByDescending(x => x.Order.CreatedAt).ToListAsync();
        var orderIds = rawList.Select(x => x.Order.OrderId).ToList();

        var paidRows = orderIds.Count == 0
            ? new List<Payment>()
            : await context.Payments
                .Where(p => orderIds.Contains(p.OrderId) && p.Status == 1)
                .ToListAsync();

        var paidByOrder = paidRows
            .GroupBy(p => p.OrderId)
            .ToDictionary(g => g.Key, g => g.Sum(p => p.Amount));

        var methodsByOrder = paidRows
            .GroupBy(p => p.OrderId)
            .ToDictionary(
                g => g.Key,
                g => string.Join(", ", g.Select(x => x.PaymentMethod).Distinct(StringComparer.OrdinalIgnoreCase)));

        var result = new List<OrderDto>();
        foreach (var item in rawList)
        {
            var ord = item.Order;
            paidByOrder.TryGetValue(ord.OrderId, out decimal paid);
            methodsByOrder.TryGetValue(ord.OrderId, out string? methods);
            result.Add(new OrderDto
            {
                OrderId = ord.OrderId,
                OrderCode = ord.OrderCode,
                TableId = ord.TableId,
                TableName = item.TableName,
                AccountId = ord.AccountId,
                WaiterName = item.WaiterName,
                CustomerName = ord.CustomerName,
                PhoneNumber = ord.PhoneNumber,
                OrderType = ord.OrderType,
            DeliveryAddress = ord.DeliveryAddress,
                Note = ord.Note,
                DiscountCode = ord.DiscountCode,
                TotalAmount = ord.TotalAmount,
                DiscountAmount = ord.DiscountAmount,
                FinalAmount = ord.FinalAmount,
                PaidAmount = paid,
                PaymentMethods = methods ?? string.Empty,
                Status = ord.Status,
                PaymentStatus = ord.PaymentStatus,
                CreatedAt = ord.CreatedAt,
                CompletedAt = ord.CompletedAt
            });
        }

        return result;
    }

    public async Task<List<TopSellingProductDto>> GetTopSellingProductsAsync(DateTime? fromDate = null, DateTime? toDate = null, int limit = 5)
    {
        var query = from d in context.OrderDetails
                    join o in context.Orders on d.OrderId equals o.OrderId
                    join p in context.Products on d.ProductId equals p.ProductId
                    where o.Status != 4 && o.PaymentStatus == 1 && d.CookingStatus != 4
                    select new { o.CreatedAt, d.ProductId, p.ProductName, p.Unit, d.Quantity, d.SubTotal };

        if (fromDate.HasValue)
        {
            var start = fromDate.Value.Date;
            query = query.Where(x => x.CreatedAt >= start);
        }
        if (toDate.HasValue)
        {
            var endExclusive = toDate.Value.Date.AddDays(1);
            query = query.Where(x => x.CreatedAt < endExclusive);
        }

        return await query
            .GroupBy(x => new { x.ProductId, x.ProductName, x.Unit })
            .Select(g => new TopSellingProductDto
            {
                ProductId = g.Key.ProductId,
                ProductName = g.Key.ProductName,
                Unit = g.Key.Unit,
                TotalQuantity = g.Sum(x => x.Quantity),
                TotalRevenue = g.Sum(x => x.SubTotal)
            })
            .OrderByDescending(x => x.TotalQuantity)
            .ThenByDescending(x => x.TotalRevenue)
            .Take(limit)
            .ToListAsync();
    }

    public async Task<List<OrderDto>> LookupOrdersAsync(string? queryText, int? callerAccountId, bool isStaff)
    {
        string kw = queryText?.Trim().ToLower() ?? string.Empty;

        string? callerPhone = null;
        if (callerAccountId.HasValue)
        {
            callerPhone = await context.Accounts
                .Where(a => a.AccountId == callerAccountId.Value)
                .Select(a => a.PhoneNumber)
                .FirstOrDefaultAsync();
            callerPhone = string.IsNullOrWhiteSpace(callerPhone) ? null : callerPhone.Trim();
        }
        bool hasCallerPhone = callerPhone != null;
        string callerPhoneVal = callerPhone ?? string.Empty;

        if (!isStaff && !callerAccountId.HasValue)
        {
            return new List<OrderDto>();
        }

        var baseQuery = from o in context.Orders
                        join t in context.DiningTables on o.TableId equals t.TableId into tGroup
                        from t in tGroup.DefaultIfEmpty()
                        join a in context.Accounts on o.AccountId equals a.AccountId into aGroup
                        from a in aGroup.DefaultIfEmpty()
                        select new
                        {
                            Order = o,
                            TableName = t != null ? t.TableName : null,
                            WaiterName = a != null ? a.FullName : null
                        };

        if (!isStaff)
        {
            // Khóa chặt IDOR: thành viên chỉ tra cứu được đơn thuộc AccountId hoặc SĐT của chính mình
            baseQuery = baseQuery.Where(x =>
                x.Order.AccountId == callerAccountId!.Value ||
                (hasCallerPhone && x.Order.PhoneNumber == callerPhoneVal));

            if (!string.IsNullOrEmpty(kw))
            {
                baseQuery = baseQuery.Where(x =>
                    x.Order.OrderCode.ToLower().Contains(kw) ||
                    (x.Order.PhoneNumber != null && x.Order.PhoneNumber.ToLower().Contains(kw)) ||
                    (x.Order.CustomerName != null && x.Order.CustomerName.ToLower().Contains(kw)));
            }
        }
        else if (string.IsNullOrEmpty(kw))
        {
            if (callerAccountId.HasValue)
            {
                baseQuery = baseQuery.Where(x => x.Order.AccountId == callerAccountId.Value);
            }
        }
        else
        {
            baseQuery = baseQuery.Where(x =>
                x.Order.OrderCode.ToLower().Contains(kw) ||
                (x.Order.PhoneNumber != null && x.Order.PhoneNumber.ToLower().Contains(kw)) ||
                (x.Order.CustomerName != null && x.Order.CustomerName.ToLower().Contains(kw)));
        }

        var rawList = await baseQuery
            .OrderByDescending(x => x.Order.CreatedAt)
            .Take(20)
            .ToListAsync();

        var ids = rawList.Select(x => x.Order.OrderId).ToList();
        var detailsByOrder = ids.Count == 0
            ? new List<OrderDetailDto>()
            : await (from d in context.OrderDetails
                     join p in context.Products on d.ProductId equals p.ProductId
                     where ids.Contains(d.OrderId) && d.CookingStatus != 4
                     select new OrderDetailDto
                     {
                         OrderDetailId = d.OrderDetailId,
                         OrderId = d.OrderId,
                         ProductId = d.ProductId,
                         ProductName = p.ProductName,
                         ImageUrl = p.ImageUrl,
                         Quantity = d.Quantity,
                         UnitPrice = d.UnitPrice,
                         SubTotal = d.SubTotal,
                         ItemNote = d.ItemNote,
                         CookingStatus = d.CookingStatus
                     }).ToListAsync();

        var paidByOrder = ids.Count == 0
            ? new Dictionary<int, decimal>()
            : await context.Payments
                .Where(p => ids.Contains(p.OrderId) && p.Status == 1)
                .GroupBy(p => p.OrderId)
                .ToDictionaryAsync(g => g.Key, g => g.Sum(p => p.Amount));

        return rawList.Select(item =>
        {
            var ord = item.Order;
            paidByOrder.TryGetValue(ord.OrderId, out decimal paidAmount);
            return new OrderDto
            {
                OrderId = ord.OrderId,
                OrderCode = ord.OrderCode,
                TableId = ord.TableId,
                TableName = item.TableName,
                AccountId = ord.AccountId,
                WaiterName = item.WaiterName,
                CustomerName = ord.CustomerName,
                PhoneNumber = ord.PhoneNumber,
                OrderType = ord.OrderType,
                DeliveryAddress = ord.DeliveryAddress,
                Note = ord.Note,
                DiscountCode = ord.DiscountCode,
                TotalAmount = ord.TotalAmount,
                DiscountAmount = ord.DiscountAmount,
                FinalAmount = ord.FinalAmount,
                PaidAmount = paidAmount,
                Status = ord.Status,
                PaymentStatus = ord.PaymentStatus,
                CreatedAt = ord.CreatedAt,
                CompletedAt = ord.CompletedAt,
                Details = detailsByOrder.Where(d => d.OrderId == ord.OrderId).ToList()
            };
        }).ToList();
    }

    public async Task<OrderDto?> GetOrderByIdAsync(int orderId, bool includeGuestToken = false)
    {
        var raw = await (from o in context.Orders
                         join t in context.DiningTables on o.TableId equals t.TableId into tGroup
                         from t in tGroup.DefaultIfEmpty()
                         join a in context.Accounts on o.AccountId equals a.AccountId into aGroup
                         from a in aGroup.DefaultIfEmpty()
                         where o.OrderId == orderId
                         select new
                         {
                             Order = o,
                             TableName = t != null ? t.TableName : null,
                             WaiterName = a != null ? a.FullName : null
                         }).FirstOrDefaultAsync();

        if (raw == null) return null;

        var ord = raw.Order;
        var details = await (from d in context.OrderDetails
                             join p in context.Products on d.ProductId equals p.ProductId
                             where d.OrderId == orderId
                             select new OrderDetailDto
                             {
                                 OrderDetailId = d.OrderDetailId,
                                 OrderId = d.OrderId,
                                 ProductId = d.ProductId,
                                 ProductName = p.ProductName,
                                 ImageUrl = p.ImageUrl,
                                 Quantity = d.Quantity,
                                 UnitPrice = d.UnitPrice,
                                 SubTotal = d.SubTotal,
                                 ItemNote = d.ItemNote,
                                 CookingStatus = d.CookingStatus,
                                 StartedCookingAt = d.StartedCookingAt,
                                 FinishedCookingAt = d.FinishedCookingAt
                             }).ToListAsync();

        var detailIds = details.Select(d => d.OrderDetailId).ToList();
        var allModifiers = detailIds.Count == 0
            ? new List<OrderDetailModifier>()
            : await context.OrderDetailModifiers
                .Where(m => detailIds.Contains(m.OrderDetailId))
                .ToListAsync();

        foreach (var d in details)
        {
            d.Modifiers = allModifiers
                .Where(m => m.OrderDetailId == d.OrderDetailId)
                .Select(m => new OrderItemModifierDto
                {
                    AttributeId = m.AttributeId,
                    ModifierName = m.ModifierName,
                    ExtraPrice = m.ExtraPrice
                })
                .ToList();
        }

        var paidRows = await context.Payments
            .Where(p => p.OrderId == orderId && p.Status == 1)
            .ToListAsync();

        decimal paidAmount = paidRows.Sum(p => p.Amount);
        string methods = string.Join(", ", paidRows.Select(p => p.PaymentMethod).Distinct(StringComparer.OrdinalIgnoreCase));

        return new OrderDto
        {
            OrderId = ord.OrderId,
            OrderCode = ord.OrderCode,
            TableId = ord.TableId,
            TableName = raw.TableName,
            AccountId = ord.AccountId,
            WaiterName = raw.WaiterName,
            CustomerName = ord.CustomerName,
            PhoneNumber = ord.PhoneNumber,
            OrderType = ord.OrderType,
                DeliveryAddress = ord.DeliveryAddress,
            Note = ord.Note,
            DiscountCode = ord.DiscountCode,
            TotalAmount = ord.TotalAmount,
            DiscountAmount = ord.DiscountAmount,
            FinalAmount = ord.FinalAmount,
            PaidAmount = paidAmount,
            PaymentMethods = methods,
            GuestAccessToken = includeGuestToken ? ord.GuestAccessToken : null,
            Status = ord.Status,
            PaymentStatus = ord.PaymentStatus,
            CreatedAt = ord.CreatedAt,
            CompletedAt = ord.CompletedAt,
            Details = details
        };
    }

    public async Task<OrderDto?> GetActiveOrderByTableIdAsync(int tableId)
    {
        var table = await context.DiningTables.FindAsync(tableId);
        if (table == null) return null;

        Order? active = null;
        if (table.CurrentOrderId.HasValue)
        {
            active = await context.Orders.FirstOrDefaultAsync(o =>
                o.OrderId == table.CurrentOrderId.Value && o.Status < 3 && o.PaymentStatus == 0);
        }

        active ??= await context.Orders
            .Where(o => o.TableId == tableId && o.Status < 3 && o.PaymentStatus == 0)
            .OrderByDescending(o => o.OrderId)
            .FirstOrDefaultAsync();

        return active == null ? null : await GetOrderByIdAsync(active.OrderId);
    }

    private async Task ReleaseTableOrPreserveReservationAsync(DiningTable table, int excludedOrderId)
    {
        bool hasOtherActive = await context.Orders.AnyAsync(o =>
            o.TableId == table.TableId &&
            o.OrderId != excludedOrderId &&
            o.Status < 3 &&
            o.PaymentStatus == 0);
        if (hasOtherActive) return;

        var now = DateTime.Now;
        var lockLimit = now.AddMinutes(TableRepository.PreArrivalLockMinutes);
        bool hasLockedReservation = await context.Reservations.AnyAsync(r =>
            r.TableId == table.TableId &&
            (r.Status == 0 || r.Status == 1) &&
            r.ArrivalTime <= lockLimit &&
            (r.ExpiresAt ?? r.ArrivalTime.AddMinutes(TableRepository.DefaultHoldGraceMinutes)) > now);

        table.Status = hasLockedReservation ? 3 : 0;
        table.CurrentOrderId = null;
        table.UpdatedAt = now;
        context.DiningTables.Update(table);
    }

    public async Task<(bool Success, string Message, int? TableId)> UpdateOrderStatusAsync(int orderId, int newStatus, bool canCompleteOrCancel)
    {
        ClearInventoryEventBuffer();
        if (newStatus < 0 || newStatus > 4)
            return (false, "Trạng thái đơn hàng không hợp lệ (0..4)", null);

        var order = await context.Orders.FindAsync(orderId);
        if (order == null) return (false, "Không tìm thấy đơn hàng", null);

        if ((newStatus == 3 || newStatus == 4) && !canCompleteOrCancel)
            return (false, "Chỉ Thu ngân, Quản lý hoặc Quản trị viên mới có quyền hoàn tất/hủy đơn hàng", order.TableId);

        if (order.Status == 4 && newStatus != 4)
            return (false, "Đơn hàng đã bị hủy, không thể kích hoạt lại", order.TableId);

        if (order.Status == 3 && newStatus == 4)
            return (false, "Đơn hàng đã hoàn thành, không thể hủy qua thao tác đổi trạng thái", order.TableId);

        if (order.Status == 3 && newStatus < 3)
            return (false, "Đơn hàng đã hoàn thành, không thể chuyển về trạng thái trước", order.TableId);

        if (newStatus == 3 && order.PaymentStatus == 0)
            return (false, "Đơn hàng chưa thanh toán, vui lòng thu tiền trước khi hoàn tất đơn", order.TableId);

        if (newStatus == 4)
        {
            if (order.PaymentStatus == 1)
                return (false, "Đơn hàng đã thanh toán, không thể hủy đơn", order.TableId);

            bool hasRealPaidTxn = await context.Payments.AnyAsync(p =>
                p.OrderId == orderId && p.Status == 1 && p.PaymentMethod != "Deposit");
            if (hasRealPaidTxn)
                return (false, "Đơn hàng đã ghi nhận giao dịch thanh toán, không thể hủy đơn", order.TableId);

            using var tx = await context.Database.BeginTransactionAsync();
            try
            {
                var activeDetails = await context.OrderDetails
                    .Where(d => d.OrderId == orderId && d.CookingStatus != 4)
                    .ToListAsync();
                var detailIds = activeDetails.Select(d => d.OrderDetailId).ToList();
                var mods = detailIds.Count == 0
                    ? new List<OrderDetailModifier>()
                    : await context.OrderDetailModifiers.Where(m => detailIds.Contains(m.OrderDetailId)).ToListAsync();

                var invRepo = new InventoryRepository(context);
                var availChanges = new List<ProductAvailabilityChangeDto>();
                foreach (var d in activeDetails)
                {
                    int qty = d.Quantity;
                    var attrIds = mods.Where(m => m.OrderDetailId == d.OrderDetailId && m.AttributeId.HasValue)
                        .Select(m => m.AttributeId!.Value)
                        .ToList();
                    d.CookingStatus = 4;
                    d.SubTotal = 0;
                    d.ItemNote = string.IsNullOrWhiteSpace(d.ItemNote) ? "[Đơn đã hủy]" : $"{d.ItemNote} [Đơn đã hủy]";
                    var restored = await invRepo.RestoreForVoidAsync(orderId, d.ProductId, qty, attrIds, order.AccountId);
                    availChanges.AddRange(restored);
                }

                await ReleaseOrderDiscountsAsync(order);

                var depositPayments = await context.Payments
                    .Where(p => p.OrderId == orderId && p.Status == 1 && p.PaymentMethod == "Deposit")
                    .ToListAsync();
                foreach (var dp in depositPayments) dp.Status = 2;

                var linkedRes = await context.Reservations.Where(r => r.CheckedInOrderId == orderId).ToListAsync();
                foreach (var r in linkedRes)
                {
                    r.DepositApplied = false;
                    r.CheckedInOrderId = null;
                }

                order.Status = 4;
                order.TotalAmount = 0;
                order.DiscountAmount = 0;
                order.FinalAmount = 0;
                context.Orders.Update(order);

                if (order.TableId.HasValue)
                {
                    var table = await context.DiningTables.FindAsync(order.TableId.Value);
                    if (table != null)
                    {
                        await ReleaseTableOrPreserveReservationAsync(table, order.OrderId);
                    }
                }

                await context.SaveChangesAsync();
                await tx.CommitAsync();
                LastAvailabilityChanges = availChanges;
                return (true, "Đã hủy đơn hàng, hoàn trả nguyên liệu BOM và giải phóng bàn thành công", order.TableId);
            }
            catch (Exception)
            {
                await tx.RollbackAsync();
                return (false, "Lỗi khi hủy đơn hàng", order.TableId);
            }
        }

        order.Status = newStatus;
        if (newStatus == 3)
        {
            order.CompletedAt = DateTime.Now;
            if (order.TableId.HasValue)
            {
                var table = await context.DiningTables.FindAsync(order.TableId.Value);
                if (table != null)
                {
                    await ReleaseTableOrPreserveReservationAsync(table, order.OrderId);
                }
            }
        }

        await context.SaveChangesAsync();
        return (true, "Cập nhật trạng thái đơn hàng thành công", order.TableId);
    }

    public async Task<(bool Success, bool Forbidden, string Message, int? TableId)> CancelUnpaidOrderAsync(
        int orderId,
        int? callerAccountId,
        bool isStaff,
        string? guestToken = null)
    {
        ClearInventoryEventBuffer();
        using var tx = await context.Database.BeginTransactionAsync();
        try
        {
            var order = await context.Orders.FindAsync(orderId);
            if (order == null) return (false, false, "Không tìm thấy đơn hàng", null);

            if (!isStaff)
            {
                if (order.AccountId.HasValue)
                {
                    if (!callerAccountId.HasValue || order.AccountId.Value != callerAccountId.Value)
                        return (false, true, "Bạn không có quyền hủy đơn hàng của người khác", order.TableId);
                }
                else
                {
                    if (!TokensEqual(order.GuestAccessToken, guestToken))
                        return (false, true, "Thiếu hoặc sai mã xác thực đơn khách vãng lai (X-Guest-Token)", order.TableId);
                }
            }

            if (order.Status == 4)
                return (true, false, "Đơn hàng đã được hủy trước đó", order.TableId);

            if (order.PaymentStatus == 1 || order.Status == 3)
                return (false, false, "Đơn hàng đã thanh toán hoặc hoàn thành, không thể hủy để hoàn giỏ", order.TableId);

            bool hasRealPaidTxn = await context.Payments.AnyAsync(p =>
                p.OrderId == orderId && p.Status == 1 && p.PaymentMethod != "Deposit");
            if (hasRealPaidTxn)
                return (false, false, "Đơn hàng đã ghi nhận giao dịch thanh toán, không thể hoàn giỏ", order.TableId);

            var details = await context.OrderDetails
                .Where(d => d.OrderId == orderId && d.CookingStatus != 4)
                .ToListAsync();

            if (!isStaff && details.Any(d => d.CookingStatus >= 2))
                return (false, false, "Bếp đã chế biến xong món trong đơn, vui lòng nhờ thu ngân/nhân viên hỗ trợ", order.TableId);

            var detailIds = details.Select(d => d.OrderDetailId).ToList();
            var mods = detailIds.Count == 0
                ? new List<OrderDetailModifier>()
                : await context.OrderDetailModifiers.Where(m => detailIds.Contains(m.OrderDetailId)).ToListAsync();

            var invRepo = new InventoryRepository(context);
            var availChanges = new List<ProductAvailabilityChangeDto>();
            foreach (var d in details)
            {
                int qty = d.Quantity;
                var attrIds = mods.Where(m => m.OrderDetailId == d.OrderDetailId && m.AttributeId.HasValue)
                    .Select(m => m.AttributeId!.Value)
                    .ToList();

                d.CookingStatus = 4;
                d.SubTotal = 0;
                d.ItemNote = string.IsNullOrEmpty(d.ItemNote)
                    ? "[Khách hủy thanh toán / Hoàn giỏ]"
                    : $"{d.ItemNote} [Hoàn giỏ]";
                var restored = await invRepo.RestoreForVoidAsync(orderId, d.ProductId, qty, attrIds, callerAccountId ?? order.AccountId);
                availChanges.AddRange(restored);
            }

            await ReleaseOrderDiscountsAsync(order);

            var depositPayments = await context.Payments
                .Where(p => p.OrderId == orderId && p.Status == 1 && p.PaymentMethod == "Deposit")
                .ToListAsync();
            foreach (var dp in depositPayments) dp.Status = 2;

            var linkedRes = await context.Reservations.Where(r => r.CheckedInOrderId == orderId).ToListAsync();
            foreach (var r in linkedRes)
            {
                r.DepositApplied = false;
                r.CheckedInOrderId = null;
            }

            order.Status = 4;
            order.TotalAmount = 0;
            order.DiscountAmount = 0;
            order.FinalAmount = 0;
            context.Orders.Update(order);

            int? freedTableId = null;
            if (order.TableId.HasValue)
            {
                var table = await context.DiningTables.FindAsync(order.TableId.Value);
                if (table != null)
                {
                    await ReleaseTableOrPreserveReservationAsync(table, order.OrderId);
                    freedTableId = table.TableId;
                }
            }

            await context.SaveChangesAsync();
            await tx.CommitAsync();
            LastAvailabilityChanges = availChanges;
            return (true, false, "Đã hủy đơn chưa thanh toán và hoàn lại tồn kho thành công", freedTableId);
        }
        catch (Exception)
        {
            await tx.RollbackAsync();
            return (false, false, "Lỗi khi hủy đơn chưa thanh toán", null);
        }
    }

    public async Task<List<KdsItemDto>> GetKdsItemsAsync()
    {
        var items = await (from d in context.OrderDetails
                           join o in context.Orders on d.OrderId equals o.OrderId
                           join p in context.Products on d.ProductId equals p.ProductId
                           join t in context.DiningTables on o.TableId equals t.TableId into tGroup
                           from t in tGroup.DefaultIfEmpty()
                           where o.Status != 3 && o.Status != 4 && d.CookingStatus >= 0 && d.CookingStatus <= 2
                           orderby d.CookingStatus ascending, o.CreatedAt ascending
                           select new KdsItemDto
                           {
                               OrderDetailId = d.OrderDetailId,
                               OrderId = d.OrderId,
                               OrderCode = o.OrderCode,
                               TableName = t != null ? t.TableName : (o.OrderType == 3 ? "Giao hàng" : "Mang về"),
                               ProductId = d.ProductId,
                               CategoryId = p.CategoryId,
                               ProductName = p.ProductName,
                               Quantity = d.Quantity,
                               ItemNote = d.ItemNote,
                               CookingStatus = d.CookingStatus,
                               OrderCreatedAt = o.CreatedAt,
                               StartedCookingAt = d.StartedCookingAt,
                               FinishedCookingAt = d.FinishedCookingAt
                           }).ToListAsync();

        var detailIds = items.Select(i => i.OrderDetailId).ToList();
        if (detailIds.Count > 0)
        {
            var mods = await context.OrderDetailModifiers
                .Where(m => detailIds.Contains(m.OrderDetailId))
                .ToListAsync();

            foreach (var item in items)
            {
                item.Modifiers = mods
                    .Where(m => m.OrderDetailId == item.OrderDetailId)
                    .Select(m => new OrderItemModifierDto
                    {
                        AttributeId = m.AttributeId,
                        ModifierName = m.ModifierName,
                        ExtraPrice = m.ExtraPrice
                    })
                    .ToList();
            }
        }

        return items;
    }

    /// <summary>
    /// Đồng bộ trạng thái bàn theo tiến độ bếp: có món đã xong chờ bưng và không còn món chưa xong thì bàn là "Chờ phục vụ" (2),
    /// ngược lại là "Có khách" (1). Chỉ đụng tới bàn đang ở trạng thái 1 hoặc 2.
    /// </summary>
    private async Task SyncTableWaitingStatusAsync(Order order)
    {
        if (!order.TableId.HasValue || order.PaymentStatus == 1 || order.Status >= 3) return;
        var table = await context.DiningTables.FindAsync(order.TableId.Value);
        if (table == null || (table.Status != 1 && table.Status != 2)) return;

        var statuses = await context.OrderDetails
            .Where(d => d.OrderId == order.OrderId && d.CookingStatus != 4)
            .Select(d => d.CookingStatus)
            .ToListAsync();

        bool waiting = statuses.Count > 0 && statuses.All(s => s >= 2) && statuses.Any(s => s == 2);
        int desired = waiting ? 2 : 1;
        if (table.Status == desired) return;

        table.Status = desired;
        table.UpdatedAt = DateTime.Now;
        context.DiningTables.Update(table);
        await context.SaveChangesAsync();
    }

    /// <summary>Đơn không còn món nào chưa giao (món đã hủy không tính).</summary>
    public static async Task<bool> AllActiveItemsServedAsync(RestaurantPosContext ctx, int orderId)
    {
        return !await ctx.OrderDetails.AnyAsync(d => d.OrderId == orderId && d.CookingStatus != 3 && d.CookingStatus != 4);
    }

    /// <summary>
    /// Đơn mang về trả trước được giữ mở cho tới khi phục vụ giao hết món. Khi đã thanh toán và mọi món đã giao
    /// thì chuyển sang Hoàn thành. Trả về true nếu đơn vừa được hoàn tất.
    /// </summary>
    public static async Task<bool> TryCompleteTakeawayAsync(RestaurantPosContext ctx, Order order)
    {
        if (order.OrderType != 2 || order.PaymentStatus != 1 || order.Status >= 3) return false;
        if (!await AllActiveItemsServedAsync(ctx, order.OrderId)) return false;
        order.Status = 3;
        order.CompletedAt = DateTime.Now;
        ctx.Orders.Update(order);
        await ctx.SaveChangesAsync();
        return true;
    }

    /// <summary>Danh sách món bếp đã làm xong (2) đang chờ phục vụ bưng ra bàn, cũ nhất trước.</summary>
    public async Task<List<KdsItemDto>> GetReadyToServeItemsAsync()
    {
        var items = await GetKdsItemsAsync();
        return items
            .Where(i => i.CookingStatus == 2)
            .OrderBy(i => i.FinishedCookingAt ?? i.OrderCreatedAt)
            .ToList();
    }

    /// <summary>Phục vụ/thu ngân đánh dấu một món đã xong (2) là đã giao (3).</summary>
    public async Task<(bool Success, string Message, int? OrderId)> ServeItemAsync(int orderDetailId)
    {
        using var tx = await context.Database.BeginTransactionAsync();
        try
        {
            var detail = await context.OrderDetails.FindAsync(orderDetailId);
            if (detail == null) return (false, "Không tìm thấy món ăn trong đơn hàng", null);
            if (detail.CookingStatus == 3) return (false, "Món này đã được giao trước đó", detail.OrderId);
            if (detail.CookingStatus != 2) return (false, "Món chưa được bếp làm xong nên chưa thể giao", detail.OrderId);

            var order = await context.Orders.FindAsync(detail.OrderId);
            if (order == null || order.Status == 3 || order.Status == 4)
                return (false, "Đơn hàng đã hoàn tất hoặc đã hủy", detail.OrderId);

            detail.CookingStatus = 3;
            await context.SaveChangesAsync();
            await SyncTableWaitingStatusAsync(order);
            bool completed = await TryCompleteTakeawayAsync(context, order);
            await tx.CommitAsync();
            return (true, completed ? "Đã giao món. Đơn mang về đã hoàn tất" : "Đã xác nhận giao món ra bàn", detail.OrderId);
        }
        catch (Exception)
        {
            await tx.RollbackAsync();
            return (false, "Lỗi cập nhật trạng thái giao món", null);
        }
    }

    /// <summary>Phục vụ/thu ngân đánh dấu mọi món đã xong (2) của đơn thành đã giao (3).</summary>
    public async Task<(bool Success, string Message, int ServedCount)> ServeReadyItemsAsync(int orderId)
    {
        using var tx = await context.Database.BeginTransactionAsync();
        try
        {
            var order = await context.Orders.FindAsync(orderId);
            if (order == null) return (false, "Không tìm thấy đơn hàng", 0);
            if (order.Status == 3 || order.Status == 4)
                return (false, "Đơn hàng đã hoàn tất hoặc đã hủy", 0);

            var ready = await context.OrderDetails
                .Where(d => d.OrderId == orderId && d.CookingStatus == 2)
                .ToListAsync();
            if (ready.Count == 0)
                return (false, "Không có món nào đã xong đang chờ bưng", 0);

            foreach (var d in ready) d.CookingStatus = 3;
            await context.SaveChangesAsync();
            await SyncTableWaitingStatusAsync(order);
            bool completed = await TryCompleteTakeawayAsync(context, order);
            await tx.CommitAsync();
            return (true,
                $"Đã đánh dấu {ready.Sum(d => d.Quantity)} phần đã giao ra bàn" + (completed ? ". Đơn mang về đã hoàn tất" : ""),
                ready.Sum(d => d.Quantity));
        }
        catch (Exception)
        {
            await tx.RollbackAsync();
            return (false, "Lỗi cập nhật trạng thái giao món", 0);
        }
    }

    public async Task<(bool Success, string Message)> UpdateCookingStatusAsync(int orderDetailId, int newStatus)
    {
        if (newStatus < 0 || newStatus > 3)
            return (false, "Trạng thái chế biến không hợp lệ (0: Chờ nấu, 1: Đang nấu, 2: Đã xong, 3: Đã giao)");

        using var tx = await context.Database.BeginTransactionAsync();
        try
        {
            var detail = await context.OrderDetails.FindAsync(orderDetailId);
            if (detail == null) return (false, "Không tìm thấy món ăn trong đơn hàng");
            if (detail.CookingStatus == 4) return (false, "Món ăn này đã bị hủy (Void), không thể cập nhật tiến độ nấu");

            var order = await context.Orders.FindAsync(detail.OrderId);
            if (order == null || order.Status == 3 || order.Status == 4)
                return (false, "Đơn hàng đã hoàn tất hoặc đã hủy, không thể thay đổi trạng thái bếp");

            detail.CookingStatus = newStatus;
            if (newStatus == 1) detail.StartedCookingAt = DateTime.Now;
            else if (newStatus == 2) detail.FinishedCookingAt ??= DateTime.Now;

            context.OrderDetails.Update(detail);
            await context.SaveChangesAsync();

            var activeDetails = await context.OrderDetails
                .Where(d => d.OrderId == detail.OrderId && d.CookingStatus != 4)
                .ToListAsync();

            if (activeDetails.Count > 0)
            {
                if (activeDetails.All(d => d.CookingStatus >= 2))
                {
                    order.Status = 2; // Served/Ready
                }
                else if (activeDetails.Any(d => d.CookingStatus >= 1) && order.Status == 0)
                {
                    order.Status = 1; // Cooking
                }
                context.Orders.Update(order);
                await context.SaveChangesAsync();
            }

            await SyncTableWaitingStatusAsync(order);
            await tx.CommitAsync();
            return (true, "Cập nhật trạng thái chế biến món ăn thành công");
        }
        catch (Exception)
        {
            await tx.RollbackAsync();
            return (false, "Lỗi cập nhật trạng thái chế biến");
        }
    }

    public async Task<(bool Success, string Message, OrderDto? Order)> AddItemsToOrderAsync(
        int orderId,
        List<CreateOrderItemDto> newItems,
        string? idempotencyKey = null,
        string? discountCode = null,
        int? callerAccountId = null)
    {
        ClearInventoryEventBuffer();
        if (newItems == null || newItems.Count == 0)
            return (false, "Vui lòng chọn ít nhất một món để thêm vào đơn hàng", null);

        string? cleanKey = string.IsNullOrWhiteSpace(idempotencyKey) ? null : idempotencyKey.Trim();
        if (cleanKey != null)
        {
            var existingKey = await context.OrderIdempotencyKeys.FirstOrDefaultAsync(k => k.IdempotencyKey == cleanKey);
            if (existingKey != null)
            {
                return (true, "Yêu cầu gọi thêm món đã được đồng bộ trước đó (Idempotent)", await GetOrderByIdAsync(existingKey.OrderId));
            }
        }

        var order = await context.Orders.FindAsync(orderId);
        if (order == null || order.Status == 3 || order.Status == 4 || order.PaymentStatus == 1)
            return (false, "Không tìm thấy đơn hàng hoặc đơn hàng đã thanh toán/đã hủy", null);

        var validated = await ValidateAndBuildOrderItemsAsync(newItems, "[GỌI THÊM]");
        if (!validated.Success) return (false, validated.Message, null);

        using var tx = await context.Database.BeginTransactionAsync();
        try
        {
            if (cleanKey != null)
            {
                var dupKey = await context.OrderIdempotencyKeys.FirstOrDefaultAsync(k => k.IdempotencyKey == cleanKey);
                if (dupKey != null)
                {
                    await tx.RollbackAsync();
                    return (true, "Yêu cầu gọi thêm món đã được đồng bộ trước đó (Idempotent)", await GetOrderByIdAsync(dupKey.OrderId));
                }
            }

            foreach (var (detail, _) in validated.Items)
            {
                detail.OrderId = order.OrderId;
                context.OrderDetails.Add(detail);
            }
            await context.SaveChangesAsync();

            foreach (var (detail, modifiers) in validated.Items)
            {
                foreach (var mod in modifiers)
                {
                    context.OrderDetailModifiers.Add(new OrderDetailModifier
                    {
                        OrderDetailId = detail.OrderDetailId,
                        AttributeId = mod.AttributeId,
                        ModifierName = mod.ModifierName,
                        ExtraPrice = mod.ExtraPrice
                    });
                }
            }
            await context.SaveChangesAsync();

            order.TotalAmount += validated.Total;

            if (!string.IsNullOrWhiteSpace(discountCode) && string.IsNullOrWhiteSpace(order.DiscountCode))
            {
                var voucherCheck = await ValidateAndReserveVoucherAsync(discountCode, order.TotalAmount, callerAccountId ?? order.AccountId);
                if (!voucherCheck.Success)
                {
                    await tx.RollbackAsync();
                    return (false, voucherCheck.Message, null);
                }
                order.DiscountCode = voucherCheck.AppliedCode;
                if (voucherCheck.ConsumedVoucher != null)
                {
                    voucherCheck.ConsumedVoucher.Status = 1;
                    voucherCheck.ConsumedVoucher.UsedAt = DateTime.Now;
                    voucherCheck.ConsumedVoucher.UsedOrderId = order.OrderId;
                }
            }

            await RecalculateDiscountForOrderAsync(order);
            if (order.Status == 2) order.Status = 1;

            if (cleanKey != null)
            {
                context.OrderIdempotencyKeys.Add(new OrderIdempotencyKey
                {
                    IdempotencyKey = cleanKey,
                    OrderId = order.OrderId,
                    CreatedAt = DateTime.Now
                });
            }

            context.Orders.Update(order);
            await context.SaveChangesAsync();

            var invRepo = new InventoryRepository(context);
            var deductResult = await invRepo.DeductForOrderItemsAsync(
                order.OrderId,
                validated.Items.Select(x => (
                    x.Detail.ProductId,
                    x.Detail.Quantity,
                    (IEnumerable<int>?)x.VerifiedModifiers.Where(m => m.AttributeId.HasValue).Select(m => m.AttributeId!.Value).ToList())),
                callerAccountId ?? order.AccountId);

            if (!deductResult.Success)
            {
                await tx.RollbackAsync();
                return (false, deductResult.Message, null);
            }

            LastLowStockAlerts = deductResult.LowStockAlerts;
            LastAvailabilityChanges = deductResult.AvailabilityChanges;

            await SyncTableWaitingStatusAsync(order);
            await tx.CommitAsync();

            return (true, $"Đã thêm thành công {validated.Items.Count} món vào đơn #{order.OrderCode}", await GetOrderByIdAsync(orderId));
        }
        catch (Exception)
        {
            await tx.RollbackAsync();
            return (false, "Lỗi khi thêm món vào đơn hàng", null);
        }
    }

    public async Task<(bool Success, string Message, OrderDto? Order)> ApplyManualDiscountAsync(int orderId, ApplyDiscountDto dto)
    {
        var order = await context.Orders.FindAsync(orderId);
        if (order == null) return (false, "Không tìm thấy đơn hàng", null);
        if (order.PaymentStatus == 1 || order.Status == 3 || order.Status == 4)
            return (false, "Không thể áp dụng chiết khấu cho đơn hàng đã thanh toán hoặc đã hủy", null);

        decimal discountAmt = 0;
        if (dto.DiscountPercent.HasValue && dto.DiscountPercent.Value > 0)
        {
            if (dto.DiscountPercent.Value > 100) return (false, "Phần trăm giảm giá không được vượt quá 100%", null);
            discountAmt = Math.Round(order.TotalAmount * (dto.DiscountPercent.Value / 100m), 0);
        }
        else if (dto.DiscountAmount.HasValue && dto.DiscountAmount.Value >= 0)
        {
            discountAmt = dto.DiscountAmount.Value;
        }
        else
        {
            return (false, "Giá trị giảm giá không hợp lệ", null);
        }

        if (!string.IsNullOrWhiteSpace(order.DiscountCode))
        {
            await ReleaseOrderDiscountsAsync(order);
            order.DiscountCode = null;
        }

        discountAmt = Math.Clamp(discountAmt, 0, order.TotalAmount);
        order.DiscountAmount = discountAmt;
        order.FinalAmount = Math.Max(0, order.TotalAmount - discountAmt);
        if (!string.IsNullOrWhiteSpace(dto.Reason))
        {
            order.Note = string.IsNullOrWhiteSpace(order.Note)
                ? $"[Chiết khấu: {dto.Reason.Trim()}]"
                : $"{order.Note} | [CK: {dto.Reason.Trim()}]";
        }

        await context.SaveChangesAsync();
        return (true, $"Đã áp dụng chiết khấu {discountAmt:N0}đ thành công", await GetOrderByIdAsync(orderId));
    }

    public async Task<(bool Success, string Message, OrderDto? Order)> VoidOrderItemAsync(int orderId, int orderDetailId, string reason, int voidQuantity)
    {
        ClearInventoryEventBuffer();
        using var tx = await context.Database.BeginTransactionAsync();
        try
        {
            var order = await context.Orders.FindAsync(orderId);
            if (order == null) return (false, "Không tìm thấy đơn hàng", null);

            if (order.Status == 3 || order.Status == 4 || order.PaymentStatus == 1)
                return (false, "Không thể hủy món trong đơn hàng đã hoàn tất, đã hủy hoặc đã thanh toán!", null);

            var detail = await context.OrderDetails.FirstOrDefaultAsync(d => d.OrderDetailId == orderDetailId && d.OrderId == orderId);
            if (detail == null) return (false, "Không tìm thấy món ăn trong đơn hàng này", null);

            if (detail.CookingStatus == 4)
                return (false, "Món ăn này đã được hủy trước đó rồi!", null);

            int actualVoidQty = (voidQuantity <= 0 || voidQuantity >= detail.Quantity) ? detail.Quantity : voidQuantity;
            if (voidQuantity <= 0 || voidQuantity >= detail.Quantity)
            {
                detail.CookingStatus = 4;
                detail.SubTotal = 0;
                detail.ItemNote = string.IsNullOrEmpty(detail.ItemNote)
                    ? $"[ĐÃ HỦY: {reason}]"
                    : $"{detail.ItemNote} [ĐÃ HỦY: {reason}]";
            }
            else
            {
                decimal unitPrice = detail.Quantity > 0 ? (detail.SubTotal / detail.Quantity) : detail.UnitPrice;
                detail.Quantity -= voidQuantity;
                detail.SubTotal = Math.Max(0, detail.Quantity * unitPrice);
                detail.ItemNote = string.IsNullOrEmpty(detail.ItemNote)
                    ? $"[HỦY {voidQuantity}x: {reason}]"
                    : $"{detail.ItemNote} [HỦY {voidQuantity}x: {reason}]";
            }

            await context.SaveChangesAsync();

            decimal activeTotal = await context.OrderDetails
                .Where(d => d.OrderId == orderId && d.CookingStatus != 4)
                .SumAsync(d => (decimal?)d.SubTotal) ?? 0;

            order.TotalAmount = activeTotal;
            await RecalculateDiscountForOrderAsync(order);
            await context.SaveChangesAsync();

            var modAttrIds = await context.OrderDetailModifiers
                .Where(m => m.OrderDetailId == orderDetailId && m.AttributeId.HasValue)
                .Select(m => m.AttributeId!.Value)
                .ToListAsync();

            var invRepo = new InventoryRepository(context);
            LastAvailabilityChanges = await invRepo.RestoreForVoidAsync(orderId, detail.ProductId, actualVoidQty, modAttrIds, order.AccountId);

            await SyncTableWaitingStatusAsync(order);
            await TryCompleteTakeawayAsync(context, order);
            await tx.CommitAsync();

            return (true, "Đã hủy món thành công", await GetOrderByIdAsync(orderId));
        }
        catch (Exception)
        {
            await tx.RollbackAsync();
            return (false, "Lỗi khi hủy món", null);
        }
    }

    public async Task<(bool Success, string Message, OrderDto? Order)> VoidDetailByIdAsync(int orderDetailId, string reason, int voidQuantity)
    {
        var detail = await context.OrderDetails.FindAsync(orderDetailId);
        if (detail == null) return (false, "Không tìm thấy món ăn", null);
        return await VoidOrderItemAsync(detail.OrderId, orderDetailId, reason, voidQuantity);
    }

    public async Task<object> GetAnalyticsAsync(int days = 7, DateTime? fromDate = null, DateTime? toDate = null)
    {
        int windowDays = Math.Clamp(days, 1, 90);
        DateTime end = (toDate?.Date ?? DateTime.Today).AddDays(1);
        DateTime start = fromDate?.Date ?? end.AddDays(-windowDays);

        var orders = await context.Orders
            .Where(o => o.CreatedAt >= start && o.CreatedAt < end)
            .ToListAsync();

        var paidOrders = orders.Where(o => o.PaymentStatus == 1 && o.Status != 4).ToList();
        decimal totalRevenue = paidOrders.Sum(o => o.FinalAmount);
        int totalOrders = orders.Count;
        decimal avgOrderValue = paidOrders.Count > 0 ? Math.Round(totalRevenue / paidOrders.Count, 0) : 0;

        var dailyRevenue = new List<object>();
        for (var dt = start.Date; dt < end.Date; dt = dt.AddDays(1))
        {
            var dayOrders = paidOrders.Where(o => o.CreatedAt.Date == dt).ToList();
            dailyRevenue.Add(new
            {
                date = dt.ToString("yyyy-MM-dd"),
                label = dt.ToString("dd/MM"),
                revenue = dayOrders.Sum(o => o.FinalAmount),
                orders = dayOrders.Count
            });
        }

        var hourlyRevenue = Enumerable.Range(0, 24)
            .Select(h => new
            {
                hour = h,
                label = $"{h:D2}h",
                revenue = paidOrders.Where(o => o.CreatedAt.Hour == h).Sum(o => o.FinalAmount),
                orders = paidOrders.Count(o => o.CreatedAt.Hour == h)
            })
            .Where(x => (int)x.orders > 0)
            .ToList();

        var payments = await context.Payments
            .Where(p => p.Status == 1 && p.PaymentTime >= start && p.PaymentTime < end)
            .ToListAsync();
        decimal totalPaidAmt = payments.Sum(p => p.Amount);
        var paymentBreakdown = payments
            .GroupBy(p => p.PaymentMethod)
            .Select(g => new
            {
                method = g.Key,
                amount = g.Sum(x => x.Amount),
                count = g.Count(),
                percent = totalPaidAmt > 0 ? Math.Round(g.Sum(x => x.Amount) * 100m / totalPaidAmt, 1) : 0
            })
            .OrderByDescending(x => x.amount)
            .ToList();

        int voidedItemCount = await context.OrderDetails
            .Join(context.Orders, d => d.OrderId, o => o.OrderId, (d, o) => new { d, o })
            .CountAsync(x => x.d.CookingStatus == 4 && x.o.CreatedAt >= start && x.o.CreatedAt < end);

        int lowStockCount = await context.Ingredients.CountAsync(i => i.IsActive && i.CurrentStock <= i.MinThreshold);
        var topProducts = await GetTopSellingProductsAsync(start, end.AddSeconds(-1), 5);

        return new
        {
            statusCode = 200,
            success = true,
            days = windowDays,
            totalRevenue,
            totalOrders,
            paidOrders = paidOrders.Count,
            avgOrderValue,
            voidedItemCount,
            lowStockCount,
            dailyRevenue,
            hourlyRevenue,
            paymentBreakdown,
            topProducts
        };
    }

    public static string SanitizeCsvCell(string? val)
    {
        string raw = val ?? string.Empty;
        string trimmed = raw.TrimStart();
        if (trimmed.Length > 0 && (trimmed[0] == '=' || trimmed[0] == '+' || trimmed[0] == '-' || trimmed[0] == '@' || raw[0] == '\t' || raw[0] == '\r'))
        {
            raw = "'" + raw;
        }
        return $"\"{raw.Replace("\"", "\"\"")}\"";
    }

    public async Task<string> ExportOrdersCsvAsync(DateTime? fromDate = null, DateTime? toDate = null, int? status = null, string? search = null)
    {
        var orders = await GetOrdersAsync(status, fromDate, toDate, search);
        var sb = new StringBuilder();
        sb.AppendLine("OrderId,OrderCode,CreatedAt,TableName,CustomerName,PhoneNumber,OrderType,DiscountCode,TotalAmount,DiscountAmount,FinalAmount,PaidAmount,PaymentMethods,Status,PaymentStatus,Note");
        foreach (var o in orders)
        {
            sb.AppendLine(string.Join(",",
                o.OrderId.ToString(CultureInfo.InvariantCulture),
                SanitizeCsvCell(o.OrderCode),
                SanitizeCsvCell(o.CreatedAt.ToString("yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture)),
                SanitizeCsvCell(o.TableName ?? "Mang về"),
                SanitizeCsvCell(o.CustomerName),
                SanitizeCsvCell(o.PhoneNumber),
                SanitizeCsvCell(o.OrderTypeText),
                SanitizeCsvCell(o.DiscountCode),
                o.TotalAmount.ToString("0.##", CultureInfo.InvariantCulture),
                o.DiscountAmount.ToString("0.##", CultureInfo.InvariantCulture),
                o.FinalAmount.ToString("0.##", CultureInfo.InvariantCulture),
                o.PaidAmount.ToString("0.##", CultureInfo.InvariantCulture),
                SanitizeCsvCell(o.PaymentMethods),
                SanitizeCsvCell(o.StatusText),
                SanitizeCsvCell(o.PaymentStatusText),
                SanitizeCsvCell(o.Note)));
        }
        return sb.ToString();
    }
}
