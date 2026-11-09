namespace WebApi.Models;

public class TableRepository : BaseRepository
{
    public TableRepository(RestaurantPosContext context) : base(context) { }

    /// <summary>
    /// Lấy danh sách các khu vực đang hoạt động, sắp xếp theo SortOrder
    /// </summary>
    public List<Area> GetAreas()
    {
        return context.Areas
            .Where(a => a.IsActive)
            .OrderBy(a => a.SortOrder)
            .ToList();
    }

    /// <summary>
    /// Lấy danh sách bàn theo mã khu vực
    /// </summary>
    public List<DiningTable> GetTablesByArea(int areaId)
    {
        return context.DiningTables
            .Where(t => t.AreaId == areaId)
            .OrderBy(t => t.TableId)
            .ToList();
    }

    /// <summary>
    /// Lấy toàn bộ danh sách bàn ăn trong nhà hàng
    /// </summary>
    public List<DiningTable> GetAllTables()
    {
        return context.DiningTables
            .OrderBy(t => t.AreaId)
            .ThenBy(t => t.TableId)
            .ToList();
    }

    /// <summary>
    /// Lấy thông tin bàn theo TableId
    /// </summary>
    public DiningTable? GetById(int tableId)
    {
        return context.DiningTables.Find(tableId);
    }

    /// <summary>
    /// Cập nhật trạng thái bàn (0: Trống, 1: Có khách, 2: Chờ phục vụ, 3: Đã đặt trước)
    /// Khi bàn trống (status == 0), tự động reset CurrentOrderId = null
    /// </summary>
    public DiningTable? UpdateStatus(int tableId, int status)
    {
        if (status < 0 || status > 3) return null;

        var table = context.DiningTables.Find(tableId);
        if (table == null) return null;

        table.Status = status;
        table.UpdatedAt = DateTime.Now;

        if (status == 0)
        {
            table.CurrentOrderId = null;
        }

        context.SaveChanges();
        return table;
    }

    /// <summary>
    /// Thực hiện chuyển bàn từ bàn nguồn sang bàn đích bằng Transaction an toàn.
    /// Kiểm tra ràng buộc: bàn nguồn không được trùng bàn đích, bàn nguồn phải tồn tại và không được trống,
    /// bàn đích phải tồn tại và phải trống (status == 0).
    /// Chuyển tất cả đơn hàng đang hoạt động sang bàn mới, cập nhật CurrentOrderId và reset bàn nguồn.
    /// </summary>
    public (bool Success, string Message, int? FromTableId, int? ToTableId) TransferTable(int fromTableId, int toTableId)
    {
        if (fromTableId == toTableId)
        {
            return (false, "Bàn nguồn và bàn đích không được trùng nhau", fromTableId, toTableId);
        }

        var fromTable = context.DiningTables.Find(fromTableId);
        if (fromTable == null)
        {
            return (false, $"Không tìm thấy bàn nguồn (ID: {fromTableId})", fromTableId, toTableId);
        }

        var toTable = context.DiningTables.Find(toTableId);
        if (toTable == null)
        {
            return (false, $"Không tìm thấy bàn đích (ID: {toTableId})", fromTableId, toTableId);
        }

        if (fromTable.Status == 0 && !fromTable.CurrentOrderId.HasValue)
        {
            return (false, $"Bàn nguồn '{fromTable.TableName}' hiện đang trống, không thể thực hiện chuyển bàn", fromTableId, toTableId);
        }

        if (toTable.Status != 0)
        {
            return (false, $"Bàn đích '{toTable.TableName}' đang có khách hoặc đã đặt trước, không thể chuyển đến", fromTableId, toTableId);
        }

        using var transaction = context.Database.BeginTransaction();
        try
        {
            context.Entry(toTable).Reload();
            if (toTable.Status != 0)
            {
                transaction.Rollback();
                return (false, $"Bàn đích '{toTable.TableName}' đang có khách hoặc đã đặt trước, không thể chuyển đến", fromTableId, toTableId);
            }

            context.Entry(fromTable).Reload();
            if (fromTable.Status == 0 && !fromTable.CurrentOrderId.HasValue)
            {
                transaction.Rollback();
                return (false, $"Bàn nguồn '{fromTable.TableName}' hiện đang trống, không thể thực hiện chuyển bàn", fromTableId, toTableId);
            }

            var activeOrders = context.Orders
                .Where(o => o.TableId == fromTableId && o.Status < 3)
                .ToList();

            foreach (var order in activeOrders)
            {
                order.TableId = toTableId;
            }

            if (fromTable.CurrentOrderId.HasValue && activeOrders.All(o => o.OrderId != fromTable.CurrentOrderId.Value))
            {
                var currentOrder = context.Orders.Find(fromTable.CurrentOrderId.Value);
                if (currentOrder != null)
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
            transaction.Commit();

            return (true, $"Chuyển bàn thành công từ '{fromTable.TableName}' sang '{toTable.TableName}'", fromTableId, toTableId);
        }
        catch (Exception ex)
        {
            transaction.Rollback();
            return (false, $"Lỗi trong quá trình chuyển bàn: {ex.Message}", fromTableId, toTableId);
        }
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

    public (bool Success, string Message, int FromTableId, int ToTableId) MergeTables(int fromTableId, int toTableId)
    {
        if (fromTableId == toTableId)
        {
            return (false, "Không thể gộp bàn vào chính nó", fromTableId, toTableId);
        }

        var fromTable = context.DiningTables.Find(fromTableId);
        var toTable = context.DiningTables.Find(toTableId);

        if (fromTable == null || toTable == null)
        {
            return (false, "Bàn nguồn hoặc bàn đích không tồn tại", fromTableId, toTableId);
        }

        if (fromTable.Status == 0)
        {
            return (false, $"Bàn nguồn '{fromTable.TableName}' hiện đang trống, không có hóa đơn để gộp", fromTableId, toTableId);
        }

        using var transaction = context.Database.BeginTransaction();
        try
        {
            // Find active order of fromTable
            var fromOrders = context.Orders.Where(o => o.TableId == fromTableId && o.Status < 3).ToList();
            var toOrder = context.Orders.Where(o => o.TableId == toTableId && o.Status < 3).OrderByDescending(o => o.OrderId).FirstOrDefault();

            if (toOrder == null)
            {
                // toTable has no active order -> simple transfer
                var transferResult = TransferTable(fromTableId, toTableId);
                return (transferResult.Success, transferResult.Message, transferResult.FromTableId ?? fromTableId, transferResult.ToTableId ?? toTableId);
            }

            // Move details from fromOrders to toOrder
            decimal movedAmount = 0;
            foreach (var fo in fromOrders)
            {
                var details = context.OrderDetails.Where(d => d.OrderId == fo.OrderId).ToList();
                foreach (var d in details)
                {
                    d.OrderId = toOrder.OrderId;
                    d.ItemNote = string.IsNullOrWhiteSpace(d.ItemNote)
                        ? $"[GỘP TỪ {fromTable.TableName}]"
                        : $"[GỘP TỪ {fromTable.TableName}] {d.ItemNote}";
                }
                movedAmount += fo.TotalAmount;
                fo.Status = 4; // Cancelled/Merged
                fo.Note = string.IsNullOrWhiteSpace(fo.Note) ? $"Đã gộp vào bàn {toTable.TableName} (Đơn #{toOrder.OrderCode})" : $"{fo.Note} | Đã gộp vào {toTable.TableName}";
            }

            toOrder.TotalAmount += movedAmount;
            toOrder.FinalAmount = Math.Max(0, toOrder.TotalAmount - toOrder.DiscountAmount);

            fromTable.Status = 0;
            fromTable.CurrentOrderId = null;
            fromTable.UpdatedAt = DateTime.Now;

            toTable.Status = 1;
            toTable.UpdatedAt = DateTime.Now;

            context.SaveChanges();
            transaction.Commit();

            return (true, $"Gộp bàn thành công từ '{fromTable.TableName}' vào '{toTable.TableName}' (Hóa đơn #{toOrder.OrderCode})", fromTableId, toTableId);
        }
        catch (Exception ex)
        {
            transaction.Rollback();
            return (false, $"Lỗi khi gộp bàn: {ex.Message}", fromTableId, toTableId);
        }
    }

    public (bool Success, string Message, int? NewOrderId) SplitTable(int fromTableId, int toTableId, List<int> orderDetailIds)
    {
        if (fromTableId == toTableId) return (false, "Không thể tách món sang cùng một bàn", null);
        if (orderDetailIds == null || orderDetailIds.Count == 0) return (false, "Vui lòng chọn ít nhất 1 món để tách bàn", null);

        var fromTable = context.DiningTables.Find(fromTableId);
        var toTable = context.DiningTables.Find(toTableId);

        if (fromTable == null || toTable == null) return (false, "Bàn nguồn hoặc bàn đích không tồn tại", null);
        if (toTable.Status != 0) return (false, $"Bàn đích '{toTable.TableName}' đang có khách, vui lòng chọn bàn trống để tách sang", null);

        var fromOrder = context.Orders.Where(o => o.TableId == fromTableId && o.Status < 3).OrderByDescending(o => o.OrderId).FirstOrDefault();
        if (fromOrder == null) return (false, $"Bàn '{fromTable.TableName}' không có hóa đơn đang hoạt động", null);

        var detailsToMove = context.OrderDetails.Where(d => d.OrderId == fromOrder.OrderId && orderDetailIds.Contains(d.OrderDetailId)).ToList();
        if (detailsToMove.Count == 0) return (false, "Không tìm thấy món ăn cần tách", null);

        using var tx = context.Database.BeginTransaction();
        try
        {
            decimal splitTotal = detailsToMove.Sum(d => d.SubTotal);
            string newOrderCode = $"ORD-{DateTime.Now:yyyyMMdd}-{Guid.NewGuid().ToString("N")[..6].ToUpper()}";

            var newOrder = new Order
            {
                OrderCode = newOrderCode,
                TableId = toTableId,
                AccountId = fromOrder.AccountId,
                CustomerName = $"Tách từ {fromTable.TableName}",
                OrderType = 1,
                TotalAmount = splitTotal,
                DiscountAmount = 0,
                FinalAmount = splitTotal,
                Status = 1,
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

            fromOrder.TotalAmount = Math.Max(0, fromOrder.TotalAmount - splitTotal);
            fromOrder.FinalAmount = Math.Max(0, fromOrder.TotalAmount - fromOrder.DiscountAmount);

            toTable.Status = 1;
            toTable.CurrentOrderId = newOrder.OrderId;
            toTable.UpdatedAt = DateTime.Now;

            context.SaveChanges();
            tx.Commit();

            return (true, $"Tách {detailsToMove.Count} món từ '{fromTable.TableName}' sang '{toTable.TableName}' thành công", newOrder.OrderId);
        }
        catch (Exception ex)
        {
            tx.Rollback();
            return (false, $"Lỗi khi tách bàn: {ex.Message}", null);
        }
    }

    public (bool Success, string Message, Reservation? Reservation) ReserveTable(int tableId, string customerName, string phoneNumber, int guestCount, DateTime arrivalTime, decimal depositAmount, string? note)
    {
        var table = context.DiningTables.Find(tableId);
        if (table == null) return (false, "Không tìm thấy bàn được chọn", null);
        if (table.Status == 1) return (false, $"Bàn '{table.TableName}' đang có khách ngồi, không thể đặt trước", null);

        var reservation = new Reservation
        {
            TableId = tableId,
            CustomerName = customerName.Trim(),
            PhoneNumber = phoneNumber.Trim(),
            GuestCount = guestCount,
            ArrivalTime = arrivalTime,
            DepositAmount = depositAmount,
            Note = note,
            Status = 1 // Confirmed
        };

        table.Status = 2; // Reserved
        table.UpdatedAt = DateTime.Now;

        context.Reservations.Add(reservation);
        context.DiningTables.Update(table);
        context.SaveChanges();

        return (true, $"Đặt bàn '{table.TableName}' cho khách '{customerName}' thành công", reservation);
    }

    public List<Reservation> GetReservations(DateTime? fromDate = null)
    {
        var query = context.Reservations.AsQueryable();
        if (fromDate.HasValue)
        {
            query = query.Where(r => r.ArrivalTime >= fromDate.Value);
        }
        return query.OrderBy(r => r.ArrivalTime).ToList();
    }

    public (bool Success, string Message) CheckInReservation(int reservationId)
    {
        var res = context.Reservations.Find(reservationId);
        if (res == null) return (false, "Không tìm thấy thông tin đặt bàn");

        res.Status = 2; // CheckedIn
        var table = context.DiningTables.Find(res.TableId);
        if (table != null)
        {
            table.Status = 1; // Occupied
            table.UpdatedAt = DateTime.Now;
            context.DiningTables.Update(table);
        }

        context.Reservations.Update(res);
        context.SaveChanges();
        return (true, $"Đã nhận bàn cho khách '{res.CustomerName}'");
    }

    public (bool Success, string Message) CancelReservation(int reservationId)
    {
        var res = context.Reservations.Find(reservationId);
        if (res == null) return (false, "Không tìm thấy thông tin đặt bàn");

        res.Status = 3; // Cancelled
        var table = context.DiningTables.Find(res.TableId);
        if (table != null && table.Status == 2)
        {
            table.Status = 0; // Empty
            table.UpdatedAt = DateTime.Now;
            context.DiningTables.Update(table);
        }

        context.Reservations.Update(res);
        context.SaveChanges();
        return (true, $"Đã hủy đặt bàn cho khách '{res.CustomerName}'");
    }
}
