using Microsoft.EntityFrameworkCore;

namespace WebApi.Models;

public class TableRepository : BaseRepository
{
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

    public (bool Success, string Message, DiningTable? Table) UpdateStatusSafe(int tableId, int status)
    {
        if (status < 0 || status > 3)
            return (false, "Trạng thái bàn không hợp lệ (0..3)", null);

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

        if (fromTable.Status == 0 && !fromTable.CurrentOrderId.HasValue && activeOrders.Count == 0)
            return (false, $"Bàn nguồn '{fromTable.TableName}' hiện đang trống, không thể chuyển bàn", fromTableId, toTableId);

        if (toTable.Status != 0)
            return (false, $"Bàn đích '{toTable.TableName}' đang có khách hoặc đã đặt trước, không thể chuyển đến", fromTableId, toTableId);

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

            var toOrder = context.Orders
                .Where(o => o.TableId == toTableId && o.Status < 3 && o.PaymentStatus == 0)
                .OrderByDescending(o => o.OrderId)
                .FirstOrDefault();

            if (toOrder == null)
            {
                // Safe internal transfer inside the SAME transaction (no nested BeginTransaction!)
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

                fo.Status = 4; // Merged/Cancelled
                fo.TotalAmount = 0;
                fo.DiscountAmount = 0;
                fo.FinalAmount = 0;
                fo.Note = string.IsNullOrWhiteSpace(fo.Note)
                    ? $"Đã gộp vào bàn {toTable.TableName} (Đơn #{toOrder.OrderCode})"
                    : $"{fo.Note} | Đã gộp vào {toTable.TableName}";
            }

            toOrder.TotalAmount += movedAmount;
            toOrder.FinalAmount = Math.Max(0, toOrder.TotalAmount - toOrder.DiscountAmount);

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
                fromOrder.DiscountAmount = Math.Min(fromOrder.DiscountAmount, fromOrder.TotalAmount);
                fromOrder.FinalAmount = Math.Max(0, fromOrder.TotalAmount - fromOrder.DiscountAmount);
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
        int tableId, string customerName, string phoneNumber, int guestCount, DateTime arrivalTime, decimal depositAmount, string? note)
    {
        if (guestCount <= 0) return (false, "Số lượng khách phải lớn hơn 0", null);
        if (depositAmount < 0) return (false, "Tiền đặt cọc không được âm", null);

        var table = context.DiningTables.Find(tableId);
        if (table == null) return (false, "Không tìm thấy bàn được chọn", null);
        if (table.Status != 0)
            return (false, $"Bàn '{table.TableName}' hiện không trống (đang có khách hoặc đã đặt trước)", null);

        var reservation = new Reservation
        {
            TableId = tableId,
            CustomerName = customerName.Trim(),
            PhoneNumber = phoneNumber.Trim(),
            GuestCount = guestCount,
            ArrivalTime = arrivalTime,
            DepositAmount = depositAmount,
            Note = note?.Trim(),
            Status = 1 // Confirmed
        };

        table.Status = 3; // Canonical: 3 = Reserved
        table.UpdatedAt = DateTime.Now;

        context.Reservations.Add(reservation);
        context.DiningTables.Update(table);
        context.SaveChanges();

        return (true, $"Đặt bàn '{table.TableName}' cho khách '{customerName}' thành công", reservation);
    }

    public List<Reservation> GetReservations(DateTime? fromDate = null)
    {
        var query = context.Reservations.Where(r => r.Status != 3); // Exclude cancelled by default
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
        if (res.Status == 3) return (false, "Lịch đặt bàn này đã bị hủy trước đó");
        if (res.Status == 2) return (false, "Khách đã nhận bàn trước đó rồi");

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
        if (res.Status == 2) return (false, "Khách đã check-in vào bàn, không thể hủy lịch đặt");
        if (res.Status == 3) return (false, "Lịch đặt bàn này đã được hủy trước đó");

        res.Status = 3; // Cancelled
        var table = context.DiningTables.Find(res.TableId);
        if (table != null && table.Status == 3 && !table.CurrentOrderId.HasValue)
        {
            table.Status = 0; // Empty
            table.UpdatedAt = DateTime.Now;
            context.DiningTables.Update(table);
        }

        context.Reservations.Update(res);
        context.SaveChanges();
        return (true, $"Đã hủy đặt bàn cho khách '{res.CustomerName}'");
    }

    public List<TableResponseDto> GetAllEnrichedTables(int? areaId = null)
    {
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

        // Load ALL active unpaid orders for these tables (resilient even when CurrentOrderId is null!)
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
        var detailsCount = context.OrderDetails
            .Where(d => orderIds.Contains(d.OrderId) && d.CookingStatus != 4)
            .GroupBy(d => d.OrderId)
            .ToDictionary(g => g.Key, g => g.Sum(x => x.Quantity));

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
                ItemCount = count
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
