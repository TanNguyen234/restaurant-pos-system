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

        // Kiểm tra bàn nguồn có đang trống không
        if (fromTable.Status == 0 && !fromTable.CurrentOrderId.HasValue)
        {
            return (false, $"Bàn nguồn '{fromTable.TableName}' hiện đang trống, không thể thực hiện chuyển bàn", fromTableId, toTableId);
        }

        // Kiểm tra sơ bộ bàn đích trước khi mở transaction
        if (toTable.Status != 0)
        {
            return (false, $"Bàn đích '{toTable.TableName}' đang có khách hoặc đã đặt trước, không thể chuyển đến", fromTableId, toTableId);
        }

        using var transaction = context.Database.BeginTransaction();
        try
        {
            // Bảo vệ chống TOCTOU race condition: reload dữ liệu bàn đích từ database trong transaction
            context.Entry(toTable).Reload();
            if (toTable.Status != 0)
            {
                transaction.Rollback();
                return (false, $"Bàn đích '{toTable.TableName}' đang có khách hoặc đã đặt trước, không thể chuyển đến", fromTableId, toTableId);
            }

            // Reload dữ liệu bàn nguồn để đảm bảo tính nhất quán
            context.Entry(fromTable).Reload();
            if (fromTable.Status == 0 && !fromTable.CurrentOrderId.HasValue)
            {
                transaction.Rollback();
                return (false, $"Bàn nguồn '{fromTable.TableName}' hiện đang trống, không thể thực hiện chuyển bàn", fromTableId, toTableId);
            }

            // 1. Tìm tất cả đơn hàng đang hoạt động liên quan đến bàn nguồn (Status < 3: chưa hoàn thành / chưa hủy)
            var activeOrders = context.Orders
                .Where(o => o.TableId == fromTableId && o.Status < 3)
                .ToList();

            // 2. Chuyển tất cả đơn hàng đang hoạt động sang bàn đích
            foreach (var order in activeOrders)
            {
                order.TableId = toTableId;
            }

            // Nếu bàn nguồn có CurrentOrderId nhưng chưa nằm trong activeOrders, cũng cập nhật TableId
            if (fromTable.CurrentOrderId.HasValue && activeOrders.All(o => o.OrderId != fromTable.CurrentOrderId.Value))
            {
                var currentOrder = context.Orders.Find(fromTable.CurrentOrderId.Value);
                if (currentOrder != null)
                {
                    currentOrder.TableId = toTableId;
                }
            }

            // 3. Gán CurrentOrderId cho bàn đích
            toTable.CurrentOrderId = activeOrders.OrderByDescending(o => o.OrderId).FirstOrDefault()?.OrderId ?? fromTable.CurrentOrderId;

            // 4. Cập nhật trạng thái bàn đích
            toTable.Status = fromTable.Status != 0 ? fromTable.Status : 1;
            toTable.UpdatedAt = DateTime.Now;

            // 5. Giải phóng bàn nguồn
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
}
