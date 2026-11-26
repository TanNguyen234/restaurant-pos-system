using Microsoft.EntityFrameworkCore;

namespace WebApi.Models;

public class TableRepository : BaseRepository
{
    public const int DefaultDurationMinutes = 120;
    public const int DefaultHoldGraceMinutes = 30;
    public const int PreArrivalLockMinutes = 60;

    public TableRepository(RestaurantPosContext context) : base(context) { }

    public List<Area> GetAreas()
    {
        return context.Areas
            .Where(a => a.IsActive)
            .OrderBy(a => a.SortOrder)
            .ThenBy(a => a.AreaId)
            .ToList();
    }

    public List<TableResponseDto> GetTablesByArea(int areaId) => GetAllEnrichedTables(areaId);

    public List<DiningTable> GetAllTables()
    {
        return context.DiningTables
            .OrderBy(t => t.AreaId)
            .ThenBy(t => t.TableId)
            .ToList();
    }

    public DiningTable? GetById(int tableId) => context.DiningTables.Find(tableId);

    public TableResponseDto? GetEnrichedById(int tableId) =>
        GetAllEnrichedTables().FirstOrDefault(t => t.TableId == tableId);

    private static DateTime ResolveExpiresAt(Reservation r) =>
        r.ExpiresAt ?? r.ArrivalTime.AddMinutes(r.HoldGraceMinutes > 0 ? r.HoldGraceMinutes : DefaultHoldGraceMinutes);

    /// <summary>
    /// Đồng bộ trạng thái đặt bàn:
    /// 1) Quá hạn giữ chỗ (ExpiresAt &lt;= now) -> tự động chuyển Status = 4 (NoShow) và mở trống bàn nếu không có đơn.
    /// 2) Còn trong cửa sổ khóa bàn (ArrivalTime &lt;= now + 60 phút) -> tự động khóa bàn trống sang Status = 3.
    /// </summary>
    public (int ExpiredCount, int LockedCount, List<int> ChangedTableIds) SyncReservationStates(DateTime? nowOverride = null)
    {
        var now = nowOverride ?? DateTime.Now;
        var activeReservations = context.Reservations
            .Where(r => r.Status == 0 || r.Status == 1)
            .ToList();

        if (activeReservations.Count == 0)
        {
            return (0, 0, new List<int>());
        }

        int expiredCount = 0;
        int lockedCount = 0;
        var touchedTableIds = new HashSet<int>();
        var lockWindowTableIds = new HashSet<int>();
        bool anyMutation = false;

        foreach (var r in activeReservations)
        {
            var expiresAt = ResolveExpiresAt(r);
            if (!r.ExpiresAt.HasValue)
            {
                r.ExpiresAt = expiresAt;
                anyMutation = true;
            }

            if (expiresAt <= now)
            {
                r.Status = 4; // NoShow
                r.Note = string.IsNullOrWhiteSpace(r.Note)
                    ? "[Tự động hết hạn giữ bàn - No-Show]"
                    : (r.Note.Contains("No-Show", StringComparison.OrdinalIgnoreCase) ? r.Note : $"{r.Note} | [Hết hạn giữ bàn]");
                touchedTableIds.Add(r.TableId);
                expiredCount++;
                anyMutation = true;
            }
            else if (r.ArrivalTime <= now.AddMinutes(PreArrivalLockMinutes))
            {
                lockWindowTableIds.Add(r.TableId);
                touchedTableIds.Add(r.TableId);
            }
        }

        var changedTableIds = new HashSet<int>();
        if (touchedTableIds.Count > 0)
        {
            var tables = context.DiningTables
                .Where(t => touchedTableIds.Contains(t.TableId))
                .ToList();

            var unpaidOrderTableIds = context.Orders
                .Where(o => o.TableId.HasValue && touchedTableIds.Contains(o.TableId.Value) && o.Status < 3 && o.PaymentStatus == 0)
                .Select(o => o.TableId!.Value)
                .ToHashSet();

            foreach (var t in tables)
            {
                bool hasUnpaid = unpaidOrderTableIds.Contains(t.TableId) || t.CurrentOrderId.HasValue;
                if (hasUnpaid) continue;

                bool shouldBeReserved = lockWindowTableIds.Contains(t.TableId);
                if (t.Status == 3 && !shouldBeReserved)
                {
                    t.Status = 0;
                    t.UpdatedAt = now;
                    changedTableIds.Add(t.TableId);
                    anyMutation = true;
                }
                else if (t.Status == 0 && shouldBeReserved)
                {
                    t.Status = 3;
                    t.UpdatedAt = now;
                    changedTableIds.Add(t.TableId);
                    lockedCount++;
                    anyMutation = true;
                }
            }
        }

        if (anyMutation)
        {
            context.SaveChanges();
        }

        return (expiredCount, lockedCount, changedTableIds.ToList());
    }

    public (bool Success, string Message, DiningTable? Table) UpdateStatusSafe(int tableId, int status)
    {
        if (status < 0 || status > 3)
            return (false, "Trạng thái bàn không hợp lệ (0..3)", null);

        SyncReservationStates();
        var table = context.DiningTables.Find(tableId);
        if (table == null) return (false, $"Không tìm thấy bàn có ID = {tableId}", null);

        if (status == 0)
        {
            bool hasUnpaidActiveOrder = context.Orders.Any(o =>
                o.TableId == tableId && o.Status < 3 && o.PaymentStatus == 0);
            if (hasUnpaidActiveOrder)
            {
                return (false, $"Bàn '{table.TableName}' vẫn còn đơn hàng chưa thanh toán, không thể trả bàn trống trực tiếp!", null);
            }

            var now = DateTime.Now;
            var lockLimit = now.AddMinutes(PreArrivalLockMinutes);
            bool hasLockedReservation = context.Reservations.Any(r =>
                r.TableId == tableId &&
                (r.Status == 0 || r.Status == 1) &&
                r.ArrivalTime <= lockLimit &&
                (r.ExpiresAt ?? r.ArrivalTime.AddMinutes(DefaultHoldGraceMinutes)) > now);

            if (hasLockedReservation)
            {
                return (false, $"Bàn '{table.TableName}' đang có lịch đặt trước sắp tới, vui lòng Check-In hoặc Hủy lịch đặt trước khi mở trống!", null);
            }

            table.CurrentOrderId = null;
        }

        table.Status = status;
        table.UpdatedAt = DateTime.Now;
        context.SaveChanges();
        return (true, "Cập nhật trạng thái thành công", table);
    }

    public DiningTable? UpdateStatus(int tableId, int status)
    {
        var res = UpdateStatusSafe(tableId, status);
        return res.Table;
    }

    public (bool Success, string Message, int? FromTableId, int? ToTableId) TransferTable(int fromTableId, int toTableId)
    {
        if (fromTableId == toTableId)
            return (false, "Bàn nguồn và bàn đích không được trùng nhau", fromTableId, toTableId);

        using var transaction = context.Database.BeginTransaction();
        try
        {
            var result = TransferTableInternal(fromTableId, toTableId);
            if (!result.Success)
            {
                transaction.Rollback();
                return result;
            }
            transaction.Commit();
            return result;
        }
        catch (Exception)
        {
            transaction.Rollback();
            return (false, "Lỗi trong quá trình chuyển bàn", fromTableId, toTableId);
        }
    }

    private (bool Success, string Message, int? FromTableId, int? ToTableId) TransferTableInternal(int fromTableId, int toTableId)
    {
        var fromTable = context.DiningTables.Find(fromTableId);
        if (fromTable == null)
            return (false, $"Không tìm thấy bàn nguồn (ID: {fromTableId})", fromTableId, toTableId);

        var toTable = context.DiningTables.Find(toTableId);
        if (toTable == null)
            return (false, $"Không tìm thấy bàn đích (ID: {toTableId})", fromTableId, toTableId);

        var activeOrders = context.Orders
            .Where(o => o.TableId == fromTableId && o.Status < 3 && o.PaymentStatus == 0)
            .ToList();

        var activeReservations = context.Reservations
            .Where(r => r.TableId == fromTableId && (r.Status == 0 || r.Status == 1))
            .ToList();

        if (fromTable.Status == 0 && !fromTable.CurrentOrderId.HasValue && activeOrders.Count == 0 && activeReservations.Count == 0)
            return (false, $"Bàn nguồn '{fromTable.TableName}' hiện đang trống, không thể chuyển bàn", fromTableId, toTableId);

        if (toTable.Status != 0)
            return (false, $"Bàn đích '{toTable.TableName}' đang có khách hoặc đã đặt trước, không thể chuyển đến", fromTableId, toTableId);

        // Nếu bàn nguồn đang giữ đặt trước, chuyển luôn lịch đặt sang bàn đích nếu đủ chỗ & không trùng giờ
        if (fromTable.Status == 3 && activeReservations.Count > 0)
        {
            var targetReservations = context.Reservations
                .Where(r => r.TableId == toTableId && (r.Status == 0 || r.Status == 1))
                .ToList();

            foreach (var r in activeReservations)
            {
                if (r.GuestCount > toTable.Capacity)
                    return (false, $"Bàn đích '{toTable.TableName}' ({toTable.Capacity} chỗ) không đủ cho lịch đặt {r.GuestCount} khách", fromTableId, toTableId);

                int dur = r.DurationMinutes > 0 ? r.DurationMinutes : DefaultDurationMinutes;
                var rEnd = r.ArrivalTime.AddMinutes(dur);
                bool overlap = targetReservations.Any(tr =>
                {
                    int trDur = tr.DurationMinutes > 0 ? tr.DurationMinutes : DefaultDurationMinutes;
                    return r.ArrivalTime < tr.ArrivalTime.AddMinutes(trDur) && tr.ArrivalTime < rEnd;
                });
                if (overlap)
                    return (false, $"Bàn đích '{toTable.TableName}' bị trùng khung giờ đặt bàn", fromTableId, toTableId);

                r.TableId = toTableId;
            }
        }

        foreach (var order in activeOrders)
        {
            order.TableId = toTableId;
        }

        if (fromTable.CurrentOrderId.HasValue && activeOrders.All(o => o.OrderId != fromTable.CurrentOrderId.Value))
        {
            var currentOrder = context.Orders.Find(fromTable.CurrentOrderId.Value);
            if (currentOrder != null && currentOrder.Status < 3)
            {
                currentOrder.TableId = toTableId;
            }
        }

        toTable.CurrentOrderId = activeOrders.OrderByDescending(o => o.OrderId).FirstOrDefault()?.OrderId ?? fromTable.CurrentOrderId;
        toTable.Status = fromTable.Status != 0 ? fromTable.Status : 1;
        toTable.UpdatedAt = DateTime.Now;

        fromTable.Status = 0;
        fromTable.CurrentOrderId = null;
        fromTable.UpdatedAt = DateTime.Now;

        context.SaveChanges();
        return (true, $"Chuyển bàn thành công từ '{fromTable.TableName}' sang '{toTable.TableName}'", fromTableId, toTableId);
    }

    public int Add(DiningTable table)
    {
        context.DiningTables.Add(table);
        return context.SaveChanges();
    }

    public int Update(DiningTable table)
    {
        context.DiningTables.Update(table);
        return context.SaveChanges();
    }

    public int Delete(int tableId)
    {
        var table = context.DiningTables.Find(tableId);
        if (table != null)
        {
            context.DiningTables.Remove(table);
            return context.SaveChanges();
        }
        return 0;
    }

    private void ReleaseOrderDiscountState(Order order)
    {
        if (!string.IsNullOrWhiteSpace(order.DiscountCode))
        {
            string norm = order.DiscountCode.Trim().ToUpperInvariant();
            var disc = context.Discounts.FirstOrDefault(d => d.Code.ToUpper() == norm);
            if (disc != null && disc.UsedCount > 0)
            {
                disc.UsedCount -= 1;
            }
        }

        var usedVouchers = context.AccountVouchers
            .Where(av => av.UsedOrderId == order.OrderId && av.Status == 1)
            .ToList();
        foreach (var uv in usedVouchers)
        {
            uv.Status = 0;
            uv.UsedAt = null;
            uv.UsedOrderId = null;
        }
    }

    private void RecalculateOrderDiscount(Order order)
    {
        order.TotalAmount = Math.Max(0, order.TotalAmount);
        if (!string.IsNullOrWhiteSpace(order.DiscountCode))
        {
            string norm = order.DiscountCode.Trim().ToUpperInvariant();
            var disc = context.Discounts.FirstOrDefault(d => d.Code.ToUpper() == norm);
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

    public (bool Success, string Message, int FromTableId, int ToTableId) MergeTables(int fromTableId, int toTableId)
    {
        if (fromTableId == toTableId)
            return (false, "Không thể gộp bàn vào chính nó", fromTableId, toTableId);

        using var transaction = context.Database.BeginTransaction();
        try
        {
            var fromTable = context.DiningTables.Find(fromTableId);
            var toTable = context.DiningTables.Find(toTableId);

            if (fromTable == null || toTable == null)
            {
                transaction.Rollback();
                return (false, "Bàn nguồn hoặc bàn đích không tồn tại", fromTableId, toTableId);
            }

            if (fromTable.Status == 0)
            {
                transaction.Rollback();
                return (false, $"Bàn nguồn '{fromTable.TableName}' hiện đang trống, không có hóa đơn để gộp", fromTableId, toTableId);
            }

            var fromOrders = context.Orders
                .Where(o => o.TableId == fromTableId && o.Status < 3 && o.PaymentStatus == 0)
                .ToList();

            if (fromOrders.Count == 0)
            {
                transaction.Rollback();
                return (false, $"Bàn nguồn '{fromTable.TableName}' không có đơn hàng chưa thanh toán để gộp", fromTableId, toTableId);
            }

            var fromOrderIds = fromOrders.Select(o => o.OrderId).ToList();
            bool hasPaidOnSource = context.Payments.Any(p => fromOrderIds.Contains(p.OrderId) && p.Status == 1);
            if (hasPaidOnSource)
            {
                transaction.Rollback();
                return (false, $"Đơn trên bàn nguồn '{fromTable.TableName}' đã phát sinh thanh toán/tiền cọc trước đó, không thể gộp trực tiếp!", fromTableId, toTableId);
            }

            var toOrder = context.Orders
                .Where(o => o.TableId == toTableId && o.Status < 3 && o.PaymentStatus == 0)
                .OrderByDescending(o => o.OrderId)
                .FirstOrDefault();

            if (toOrder == null)
            {
                var transferResult = TransferTableInternal(fromTableId, toTableId);
                if (!transferResult.Success)
                {
                    transaction.Rollback();
                    return (false, transferResult.Message, fromTableId, toTableId);
                }
                transaction.Commit();
                return (true, transferResult.Message, transferResult.FromTableId ?? fromTableId, transferResult.ToTableId ?? toTableId);
            }

            decimal movedAmount = 0;
            decimal carriedManualDiscount = 0;
            foreach (var fo in fromOrders)
            {
                var activeDetails = context.OrderDetails
                    .Where(d => d.OrderId == fo.OrderId && d.CookingStatus != 4)
                    .ToList();

                foreach (var d in activeDetails)
                {
                    d.OrderId = toOrder.OrderId;
                    d.ItemNote = string.IsNullOrWhiteSpace(d.ItemNote)
                        ? $"[GỘP TỪ {fromTable.TableName}]"
                        : $"[GỘP TỪ {fromTable.TableName}] {d.ItemNote}";
                    movedAmount += d.SubTotal;
                }

                // Nếu bàn nguồn dùng voucher mà bàn đích chưa có voucher -> chuyển quyền voucher sang bàn đích; ngược lại hoàn trả voucher bàn nguồn
                if (!string.IsNullOrWhiteSpace(fo.DiscountCode) && string.IsNullOrWhiteSpace(toOrder.DiscountCode))
                {
                    toOrder.DiscountCode = fo.DiscountCode;
                    var movedVouchers = context.AccountVouchers.Where(av => av.UsedOrderId == fo.OrderId && av.Status == 1).ToList();
                    foreach (var v in movedVouchers) v.UsedOrderId = toOrder.OrderId;
                }
                else
                {
                    if (!string.IsNullOrWhiteSpace(fo.DiscountCode))
                    {
                        ReleaseOrderDiscountState(fo);
                    }
                    else if (fo.DiscountAmount > 0 && string.IsNullOrWhiteSpace(toOrder.DiscountCode))
                    {
                        carriedManualDiscount += fo.DiscountAmount;
                    }
                }

                fo.Status = 4; // Merged/Cancelled
                fo.DiscountCode = null;
                fo.TotalAmount = 0;
                fo.DiscountAmount = 0;
                fo.FinalAmount = 0;
                fo.Note = string.IsNullOrWhiteSpace(fo.Note)
                    ? $"Đã gộp vào bàn {toTable.TableName} (Đơn #{toOrder.OrderCode})"
                    : $"{fo.Note} | Đã gộp vào {toTable.TableName}";
            }

            toOrder.TotalAmount += movedAmount;
            if (carriedManualDiscount > 0 && string.IsNullOrWhiteSpace(toOrder.DiscountCode))
            {
                toOrder.DiscountAmount += carriedManualDiscount;
            }
            RecalculateOrderDiscount(toOrder);

            fromTable.Status = 0;
            fromTable.CurrentOrderId = null;
            fromTable.UpdatedAt = DateTime.Now;

            toTable.Status = 1;
            toTable.CurrentOrderId = toOrder.OrderId;
            toTable.UpdatedAt = DateTime.Now;

            context.SaveChanges();
            transaction.Commit();

            return (true, $"Gộp bàn thành công từ '{fromTable.TableName}' vào '{toTable.TableName}' (Hóa đơn #{toOrder.OrderCode})", fromTableId, toTableId);
        }
        catch (Exception)
        {
            transaction.Rollback();
            return (false, "Lỗi khi thực hiện gộp bàn", fromTableId, toTableId);
        }
    }

    public (bool Success, string Message, int? NewOrderId) SplitTable(int fromTableId, int toTableId, List<int> orderDetailIds)
    {
        if (fromTableId == toTableId) return (false, "Không thể tách món sang cùng một bàn", null);
        if (orderDetailIds == null || orderDetailIds.Count == 0) return (false, "Vui lòng chọn ít nhất 1 món để tách bàn", null);

        using var tx = context.Database.BeginTransaction();
        try
        {
            var fromTable = context.DiningTables.Find(fromTableId);
            var toTable = context.DiningTables.Find(toTableId);

            if (fromTable == null || toTable == null)
            {
                tx.Rollback();
                return (false, "Bàn nguồn hoặc bàn đích không tồn tại", null);
            }
            if (toTable.Status != 0)
            {
                tx.Rollback();
                return (false, $"Bàn đích '{toTable.TableName}' đang có khách hoặc đã đặt trước, vui lòng chọn bàn trống", null);
            }

            var fromOrder = context.Orders
                .Where(o => o.TableId == fromTableId && o.Status < 3 && o.PaymentStatus == 0)
                .OrderByDescending(o => o.OrderId)
                .FirstOrDefault();

            if (fromOrder == null)
            {
                tx.Rollback();
                return (false, $"Bàn '{fromTable.TableName}' không có hóa đơn chưa thanh toán", null);
            }

            bool hasPaidOnSource = context.Payments.Any(p => p.OrderId == fromOrder.OrderId && p.Status == 1);
            if (hasPaidOnSource)
            {
                tx.Rollback();
                return (false, $"Đơn #{fromOrder.OrderCode} đã thanh toán một phần hoặc gắn tiền cọc, không thể tách bàn!", null);
            }

            var allActiveDetails = context.OrderDetails
                .Where(d => d.OrderId == fromOrder.OrderId && d.CookingStatus != 4)
                .ToList();

            var detailsToMove = allActiveDetails
                .Where(d => orderDetailIds.Contains(d.OrderDetailId))
                .ToList();

            if (detailsToMove.Count == 0)
            {
                tx.Rollback();
                return (false, "Không tìm thấy món hợp lệ cần tách", null);
            }

            decimal splitTotal = detailsToMove.Sum(d => d.SubTotal);
            string newOrderCode = $"ORD-{DateTime.Now:yyyyMMdd}-{Guid.NewGuid().ToString("N")[..6].ToUpper()}";

            int maxCooking = detailsToMove.Max(d => d.CookingStatus);
            int derivedOrderStatus = maxCooking >= 2 ? 2 : (maxCooking == 1 ? 1 : 0);

            var newOrder = new Order
            {
                OrderCode = newOrderCode,
                TableId = toTableId,
                AccountId = fromOrder.AccountId,
                CustomerName = $"Tách từ {fromTable.TableName}",
                PhoneNumber = fromOrder.PhoneNumber,
                OrderType = 1,
                TotalAmount = splitTotal,
                DiscountAmount = 0,
                FinalAmount = splitTotal,
                Status = derivedOrderStatus,
                PaymentStatus = 0,
                CreatedAt = DateTime.Now,
                Note = $"Tách từ bàn {fromTable.TableName} (Đơn #{fromOrder.OrderCode})"
            };
            context.Orders.Add(newOrder);
            context.SaveChanges();

            foreach (var d in detailsToMove)
            {
                d.OrderId = newOrder.OrderId;
            }

            int remainingCount = allActiveDetails.Count - detailsToMove.Count;
            if (remainingCount == 0)
            {
                if (!string.IsNullOrWhiteSpace(fromOrder.DiscountCode))
                {
                    newOrder.DiscountCode = fromOrder.DiscountCode;
                    var usedVouchers = context.AccountVouchers.Where(av => av.UsedOrderId == fromOrder.OrderId && av.Status == 1).ToList();
                    foreach (var v in usedVouchers) v.UsedOrderId = newOrder.OrderId;
                    newOrder.DiscountAmount = fromOrder.DiscountAmount;
                    RecalculateOrderDiscount(newOrder);
                }

                fromOrder.DiscountCode = null;
                fromOrder.TotalAmount = 0;
                fromOrder.DiscountAmount = 0;
                fromOrder.FinalAmount = 0;
                fromOrder.Status = 4; // All items moved -> close source order & release source table
                fromTable.Status = 0;
                fromTable.CurrentOrderId = null;
                fromTable.UpdatedAt = DateTime.Now;
            }
            else
            {
                fromOrder.TotalAmount = Math.Max(0, fromOrder.TotalAmount - splitTotal);
                RecalculateOrderDiscount(fromOrder);
            }

            toTable.Status = 1;
            toTable.CurrentOrderId = newOrder.OrderId;
            toTable.UpdatedAt = DateTime.Now;

            context.SaveChanges();
            tx.Commit();

            return (true, $"Tách {detailsToMove.Count} món từ '{fromTable.TableName}' sang '{toTable.TableName}' thành công", newOrder.OrderId);
        }
        catch (Exception)
        {
            tx.Rollback();
            return (false, "Lỗi khi tách bàn", null);
        }
    }

    public (bool Success, string Message, Reservation? Reservation) ReserveTable(
        int tableId,
        string customerName,
        string phoneNumber,
        int guestCount,
        DateTime arrivalTime,
        decimal depositAmount,
        string? note,
        int durationMinutes = DefaultDurationMinutes,
        int holdGraceMinutes = DefaultHoldGraceMinutes,
        int? accountId = null)
    {
        if (guestCount <= 0) return (false, "Số lượng khách phải lớn hơn 0", null);
        if (depositAmount < 0) return (false, "Tiền đặt cọc không được âm", null);

        var now = DateTime.Now;
        if (arrivalTime < now.AddMinutes(-5))
            return (false, "Thời gian đặt bàn không được ở quá khứ", null);

        SyncReservationStates(now);

        var table = context.DiningTables.Find(tableId);
        if (table == null) return (false, "Không tìm thấy bàn được chọn", null);
        if (guestCount > table.Capacity)
            return (false, $"Số lượng khách ({guestCount}) vượt quá sức chứa của bàn '{table.TableName}' ({table.Capacity} chỗ)", null);

        int dur = Math.Clamp(durationMinutes <= 0 ? DefaultDurationMinutes : durationMinutes, 30, 480);
        int grace = Math.Clamp(holdGraceMinutes <= 0 ? DefaultHoldGraceMinutes : holdGraceMinutes, 5, 120);
        var expiresAt = arrivalTime.AddMinutes(grace);
        var windowEnd = arrivalTime.AddMinutes(dur);

        // Kiểm tra trùng khung giờ với các lịch đặt đang hoạt động của bàn
        var existingBookings = context.Reservations
            .Where(r => r.TableId == tableId && (r.Status == 0 || r.Status == 1))
            .ToList();

        foreach (var ex in existingBookings)
        {
            int exDur = ex.DurationMinutes > 0 ? ex.DurationMinutes : DefaultDurationMinutes;
            var exEnd = ex.ArrivalTime.AddMinutes(exDur);
            if (arrivalTime < exEnd && ex.ArrivalTime < windowEnd)
            {
                return (false, $"Bàn '{table.TableName}' đã có khách '{ex.CustomerName}' đặt từ {ex.ArrivalTime:HH:mm dd/MM} đến {exEnd:HH:mm}", null);
            }
        }

        bool isImmediateWindow = arrivalTime <= now.AddMinutes(PreArrivalLockMinutes);
        if (isImmediateWindow)
        {
            bool hasUnpaidOrder = context.Orders.Any(o => o.TableId == tableId && o.Status < 3 && o.PaymentStatus == 0);
            if (table.Status != 0 || hasUnpaidOrder)
                return (false, $"Bàn '{table.TableName}' hiện không trống trong khung giờ giữ bàn (trong vòng 60 phút tới)", null);
        }

        var reservation = new Reservation
        {
            TableId = tableId,
            AccountId = accountId,
            CustomerName = customerName.Trim(),
            PhoneNumber = phoneNumber.Trim(),
            GuestCount = guestCount,
            ArrivalTime = arrivalTime,
            DurationMinutes = dur,
            HoldGraceMinutes = grace,
            ExpiresAt = expiresAt,
            DepositAmount = depositAmount,
            DepositApplied = false,
            Note = note?.Trim(),
            Status = 1, // Confirmed
            CreatedAt = now
        };

        context.Reservations.Add(reservation);
        if (isImmediateWindow)
        {
            table.Status = 3; // Canonical: 3 = Reserved
            table.UpdatedAt = now;
            context.DiningTables.Update(table);
        }
        context.SaveChanges();

        string windowMsg = isImmediateWindow
            ? $"Giữ bàn đến {expiresAt:HH:mm dd/MM} (tối đa trễ {grace} phút)"
            : $"Sẽ tự động khóa bàn trước giờ hẹn {PreArrivalLockMinutes} phút (hết hạn giữ lúc {expiresAt:HH:mm dd/MM})";
        return (true, $"Đặt bàn '{table.TableName}' cho '{customerName.Trim()}' thành công. {windowMsg}.", reservation);
    }

    public List<ReservationDto> GetReservations(
        DateTime? fromDate = null,
        int? onlyAccountId = null,
        string? onlyPhone = null,
        bool includeInactive = false)
    {
        SyncReservationStates();

        var query = from r in context.Reservations
                    join t in context.DiningTables on r.TableId equals t.TableId
                    join a in context.Areas on t.AreaId equals a.AreaId into aGroup
                    from a in aGroup.DefaultIfEmpty()
                    select new { r, TableName = t.TableName, AreaName = a != null ? a.AreaName : "" };

        if (onlyAccountId.HasValue)
        {
            string? cleanPhone = string.IsNullOrWhiteSpace(onlyPhone) ? null : onlyPhone.Trim();
            query = query.Where(x =>
                x.r.AccountId == onlyAccountId.Value ||
                (cleanPhone != null && x.r.PhoneNumber == cleanPhone));
        }

        if (!includeInactive)
        {
            query = query.Where(x => x.r.Status != 3 && x.r.Status != 4);
        }

        if (fromDate.HasValue)
        {
            query = query.Where(x => x.r.ArrivalTime >= fromDate.Value);
        }

        return query
            .OrderBy(x => x.r.Status <= 1 ? 0 : 1)
            .ThenBy(x => x.r.ArrivalTime)
            .Select(x => new ReservationDto
            {
                ReservationId = x.r.ReservationId,
                TableId = x.r.TableId,
                TableName = x.TableName,
                AreaName = x.AreaName,
                AccountId = x.r.AccountId,
                CustomerName = x.r.CustomerName,
                PhoneNumber = x.r.PhoneNumber,
                GuestCount = x.r.GuestCount,
                ArrivalTime = x.r.ArrivalTime,
                DurationMinutes = x.r.DurationMinutes,
                HoldGraceMinutes = x.r.HoldGraceMinutes,
                ExpiresAt = x.r.ExpiresAt ?? x.r.ArrivalTime.AddMinutes(x.r.HoldGraceMinutes),
                DepositAmount = x.r.DepositAmount,
                DepositApplied = x.r.DepositApplied,
                CheckedInOrderId = x.r.CheckedInOrderId,
                Note = x.r.Note,
                Status = x.r.Status,
                CreatedAt = x.r.CreatedAt
            })
            .ToList();
    }

    public (bool Success, string Message, int? TableId, decimal DepositAmount) CheckInReservation(int reservationId)
    {
        SyncReservationStates();

        var res = context.Reservations.Find(reservationId);
        if (res == null) return (false, "Không tìm thấy thông tin đặt bàn", null, 0);
        if (res.Status == 3) return (false, "Lịch đặt bàn này đã bị hủy trước đó", res.TableId, 0);
        if (res.Status == 4) return (false, "Lịch đặt bàn đã quá thời hạn giữ chỗ (No-Show) và bị hủy tự động", res.TableId, 0);
        if (res.Status == 2) return (false, "Khách đã nhận bàn trước đó rồi", res.TableId, 0);

        var table = context.DiningTables.Find(res.TableId);
        if (table == null) return (false, "Không tìm thấy bàn của lịch đặt này", null, 0);

        bool hasUnpaidOrder = context.Orders.Any(o => o.TableId == table.TableId && o.Status < 3 && o.PaymentStatus == 0);
        if (hasUnpaidOrder || table.Status == 1 || table.Status == 2)
        {
            return (false, $"Bàn '{table.TableName}' hiện đang phục vụ khách khác, vui lòng thanh toán hoặc chuyển bàn trước khi Check-In", table.TableId, 0);
        }

        res.Status = 2; // CheckedIn
        table.Status = 1; // Occupied
        table.UpdatedAt = DateTime.Now;
        context.DiningTables.Update(table);
        context.Reservations.Update(res);
        context.SaveChanges();

        string depText = res.DepositAmount > 0
            ? $" (tiền cọc {res.DepositAmount:N0}đ sẽ tự cấn trừ khi tạo hóa đơn đầu tiên)"
            : "";
        return (true, $"Đã nhận bàn '{table.TableName}' cho khách '{res.CustomerName}'{depText}", table.TableId, res.DepositAmount);
    }

    public (bool Success, bool Forbidden, string Message, int? TableId) CancelReservation(
        int reservationId,
        int? callerAccountId = null,
        bool isStaff = true)
    {
        SyncReservationStates();

        var res = context.Reservations.Find(reservationId);
        if (res == null) return (false, false, "Không tìm thấy thông tin đặt bàn", null);

        if (!isStaff)
        {
            if (!callerAccountId.HasValue || !res.AccountId.HasValue || res.AccountId.Value != callerAccountId.Value)
                return (false, true, "Bạn chỉ có thể hủy lịch đặt bàn của chính mình", res.TableId);
        }

        if (res.Status == 2) return (false, false, "Khách đã check-in vào bàn, không thể hủy lịch đặt", res.TableId);
        if (res.Status == 3) return (false, false, "Lịch đặt bàn này đã được hủy trước đó", res.TableId);
        if (res.Status == 4) return (false, false, "Lịch đặt bàn này đã hết hạn (No-Show)", res.TableId);

        res.Status = 3; // Cancelled
        context.Reservations.Update(res);
        context.SaveChanges();

        var now = DateTime.Now;
        var lockLimit = now.AddMinutes(PreArrivalLockMinutes);
        var table = context.DiningTables.Find(res.TableId);
        if (table != null && table.Status == 3 && !table.CurrentOrderId.HasValue)
        {
            bool hasOtherLock = context.Reservations.Any(r =>
                r.ReservationId != res.ReservationId &&
                r.TableId == table.TableId &&
                (r.Status == 0 || r.Status == 1) &&
                r.ArrivalTime <= lockLimit &&
                (r.ExpiresAt ?? r.ArrivalTime.AddMinutes(DefaultHoldGraceMinutes)) > now);

            bool hasUnpaidOrder = context.Orders.Any(o => o.TableId == table.TableId && o.Status < 3 && o.PaymentStatus == 0);
            if (!hasOtherLock && !hasUnpaidOrder)
            {
                table.Status = 0; // Empty
                table.UpdatedAt = now;
                context.DiningTables.Update(table);
                context.SaveChanges();
            }
        }

        return (true, false, $"Đã hủy đặt bàn cho khách '{res.CustomerName}'", res.TableId);
    }

    public List<TableResponseDto> GetAllEnrichedTables(int? areaId = null)
    {
        SyncReservationStates();

        var tablesQuery = context.DiningTables.AsQueryable();
        if (areaId.HasValue && areaId.Value > 0)
        {
            tablesQuery = tablesQuery.Where(t => t.AreaId == areaId.Value);
        }

        var tables = tablesQuery
            .OrderBy(t => t.AreaId)
            .ThenBy(t => t.TableId)
            .ToList();

        var tableIds = tables.Select(t => t.TableId).ToList();

        var activeOrders = context.Orders
            .Where(o => o.TableId.HasValue && tableIds.Contains(o.TableId.Value) && o.Status < 3 && o.PaymentStatus == 0)
            .OrderByDescending(o => o.OrderId)
            .ToList();

        var explicitOrderIds = tables
            .Where(t => t.CurrentOrderId.HasValue)
            .Select(t => t.CurrentOrderId!.Value)
            .Except(activeOrders.Select(o => o.OrderId))
            .ToList();

        if (explicitOrderIds.Count > 0)
        {
            var extraOrders = context.Orders
                .Where(o => explicitOrderIds.Contains(o.OrderId) && o.Status < 3 && o.PaymentStatus == 0)
                .ToList();
            activeOrders.AddRange(extraOrders);
        }

        var orderById = activeOrders.GroupBy(o => o.OrderId).ToDictionary(g => g.Key, g => g.First());
        var orderByTable = activeOrders
            .Where(o => o.TableId.HasValue)
            .GroupBy(o => o.TableId!.Value)
            .ToDictionary(g => g.Key, g => g.OrderByDescending(o => o.OrderId).First());

        var orderIds = orderById.Keys.ToList();
        var detailsCount = orderIds.Count == 0
            ? new Dictionary<int, int>()
            : context.OrderDetails
                .Where(d => orderIds.Contains(d.OrderId) && d.CookingStatus != 4)
                .GroupBy(d => d.OrderId)
                .ToDictionary(g => g.Key, g => g.Sum(x => x.Quantity));

        var upcomingReservations = context.Reservations
            .Where(r => tableIds.Contains(r.TableId) && (r.Status == 0 || r.Status == 1))
            .OrderBy(r => r.ArrivalTime)
            .ToList()
            .GroupBy(r => r.TableId)
            .ToDictionary(g => g.Key, g => g.First());

        return tables.Select(t =>
        {
            Order? ord = null;
            if (t.CurrentOrderId.HasValue && orderById.TryGetValue(t.CurrentOrderId.Value, out var explicitOrd))
            {
                ord = explicitOrd;
            }
            else if (orderByTable.TryGetValue(t.TableId, out var fallbackOrd))
            {
                ord = fallbackOrd;
            }

            int count = 0;
            if (ord != null)
            {
                detailsCount.TryGetValue(ord.OrderId, out count);
            }

            upcomingReservations.TryGetValue(t.TableId, out var nextRes);

            return new TableResponseDto
            {
                TableId = t.TableId,
                AreaId = t.AreaId,
                TableName = t.TableName,
                Capacity = t.Capacity,
                Status = t.Status,
                CurrentOrderId = ord?.OrderId ?? t.CurrentOrderId,
                UpdatedAt = t.UpdatedAt,
                OrderCreatedAt = ord?.CreatedAt,
                RunningTotal = ord?.FinalAmount ?? (ord?.TotalAmount ?? 0),
                ItemCount = count,
                NextReservationId = nextRes?.ReservationId,
                NextReservationCustomer = nextRes?.CustomerName,
                NextReservationTime = nextRes?.ArrivalTime,
                NextReservationExpiresAt = nextRes != null ? ResolveExpiresAt(nextRes) : null,
                NextReservationDeposit = nextRes?.DepositAmount
            };
        }).ToList();
    }

    public (bool Success, string Message, DiningTable? Table) CreateTable(int areaId, string tableName, int capacity)
    {
        var area = context.Areas.Find(areaId);
        if (area == null) return (false, "Khu vực được chọn không tồn tại", null);

        var table = new DiningTable
        {
            AreaId = areaId,
            TableName = tableName.Trim(),
            Capacity = capacity > 0 ? capacity : 4,
            Status = 0,
            UpdatedAt = DateTime.Now
        };

        context.DiningTables.Add(table);
        context.SaveChanges();
        return (true, $"Đã tạo bàn '{table.TableName}' thành công", table);
    }

    public (bool Success, string Message, DiningTable? Table) UpdateTable(int tableId, int? areaId, string? tableName, int? capacity, int? status)
    {
        var table = context.DiningTables.Find(tableId);
        if (table == null) return (false, "Không tìm thấy bàn cần cập nhật", null);

        if (areaId.HasValue && areaId.Value > 0)
        {
            var area = context.Areas.Find(areaId.Value);
            if (area == null) return (false, "Khu vực được chọn không tồn tại", null);
            table.AreaId = areaId.Value;
        }

        if (!string.IsNullOrWhiteSpace(tableName)) table.TableName = tableName.Trim();
        if (capacity.HasValue && capacity.Value > 0) table.Capacity = capacity.Value;
        if (status.HasValue && status.Value >= 0 && status.Value <= 3)
        {
            if (status.Value == 0)
            {
                bool hasUnpaid = context.Orders.Any(o => o.TableId == tableId && o.Status < 3 && o.PaymentStatus == 0);
                if (hasUnpaid) return (false, "Bàn còn đơn hàng chưa thanh toán, không thể đặt trống", null);
                table.CurrentOrderId = null;
            }
            table.Status = status.Value;
        }

        table.UpdatedAt = DateTime.Now;
        context.SaveChanges();
        return (true, $"Cập nhật bàn '{table.TableName}' thành công", table);
    }

    public (bool Success, string Message) DeleteTable(int tableId)
    {
        var table = context.DiningTables.Find(tableId);
        if (table == null) return (false, "Không tìm thấy bàn để xóa");

        if (table.Status != 0 || table.CurrentOrderId.HasValue)
        {
            return (false, $"Bàn '{table.TableName}' hiện đang có khách hoặc đang có đơn phục vụ, không thể xóa!");
        }

        if (context.Orders.Any(o => o.TableId == tableId))
        {
            return (false, $"Không thể xóa bàn '{table.TableName}' vì đã có dữ liệu đơn hàng lịch sử gắn với bàn này!");
        }

        if (context.Reservations.Any(r => r.TableId == tableId))
        {
            return (false, $"Không thể xóa bàn '{table.TableName}' vì đã có lịch sử đặt bàn!");
        }

        context.DiningTables.Remove(table);
        context.SaveChanges();
        return (true, $"Đã xóa bàn '{table.TableName}' thành công");
    }

    public (bool Success, string Message, Area? Area) CreateArea(string areaName, string? description, int sortOrder)
    {
        if (string.IsNullOrWhiteSpace(areaName)) return (false, "Tên khu vực không được để trống", null);

        var area = new Area
        {
            AreaName = areaName.Trim(),
            Description = description?.Trim(),
            SortOrder = sortOrder,
            IsActive = true,
            CreatedAt = DateTime.Now
        };

        context.Areas.Add(area);
        context.SaveChanges();
        return (true, $"Đã tạo khu vực '{area.AreaName}' thành công", area);
    }

    public (bool Success, string Message, Area? Area) UpdateArea(int areaId, string areaName, string? description, int sortOrder, bool isActive)
    {
        var area = context.Areas.Find(areaId);
        if (area == null) return (false, "Không tìm thấy khu vực cần cập nhật", null);

        if (!string.IsNullOrWhiteSpace(areaName)) area.AreaName = areaName.Trim();
        if (description != null) area.Description = description.Trim();
        area.SortOrder = sortOrder;
        area.IsActive = isActive;

        context.SaveChanges();
        return (true, $"Cập nhật khu vực '{area.AreaName}' thành công", area);
    }

    public (bool Success, string Message) DeleteArea(int areaId)
    {
        var area = context.Areas.Find(areaId);
        if (area == null) return (false, "Không tìm thấy khu vực để xóa");

        bool hasTables = context.DiningTables.Any(t => t.AreaId == areaId);
        if (hasTables)
        {
            return (false, $"Không thể xóa khu vực '{area.AreaName}' vì vẫn còn bàn thuộc khu vực này!");
        }

        context.Areas.Remove(area);
        context.SaveChanges();
        return (true, $"Đã xóa khu vực '{area.AreaName}' thành công");
    }
}
