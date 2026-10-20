using Microsoft.EntityFrameworkCore;

namespace WebApi.Models;

public class OrderRepository : BaseRepository
{
    public OrderRepository(RestaurantPosContext context) : base(context) { }

    /// <summary>
    /// Tạo đơn hàng mới từ client với Database Transaction toàn vẹn.
    /// Tự động sinh mã đơn hàng ORD-yyyyMMdd-XXX, tính tổng tiền,
    /// chèn chi tiết món và cập nhật trạng thái bàn ăn (Status = 1: Có khách).
    /// </summary>
    public (bool Success, string Message, Order? Order) CreateOrder(CreateOrderRequest request)
    {
        if (request == null || request.Items == null || request.Items.Count == 0)
        {
            return (false, "Đơn hàng phải chứa ít nhất 1 món ăn/thức uống", null);
        }

        using var transaction = context.Database.BeginTransaction();
        try
        {
            // Kiểm tra bàn ăn (nếu có chọn bàn)
            DiningTable? table = null;
            if (request.TableId.HasValue && request.TableId.Value > 0)
            {
                table = context.DiningTables.Find(request.TableId.Value);
                if (table == null)
                {
                    return (false, $"Không tìm thấy bàn ăn có ID = {request.TableId.Value}", null);
                }
            }

            // Sinh mã đơn hàng dạng ORD-yyyyMMdd-XXX
            string todayPrefix = $"ORD-{DateTime.Now:yyyyMMdd}-";
            int countToday = context.Orders.Count(o => o.OrderCode.StartsWith(todayPrefix));
            string orderCode = $"{todayPrefix}{(countToday + 1):D3}";

            // Đảm bảo không trùng OrderCode
            while (context.Orders.Any(o => o.OrderCode == orderCode))
            {
                countToday++;
                orderCode = $"{todayPrefix}{(countToday + 1):D3}";
            }

            // Tính tổng tiền từ danh sách món
            decimal totalAmount = 0;
            foreach (var item in request.Items)
            {
                decimal itemSubtotal = item.UnitPrice * item.Quantity;
                totalAmount += itemSubtotal;
            }

            decimal discount = request.DiscountAmount ?? 0;
            if (discount < 0) discount = 0;
            if (discount > totalAmount) discount = totalAmount;
            decimal finalAmount = totalAmount - discount;

            var order = new Order
            {
                OrderCode = orderCode,
                TableId = request.TableId > 0 ? request.TableId : null,
                AccountId = request.AccountId > 0 ? request.AccountId : null,
                CustomerName = string.IsNullOrWhiteSpace(request.CustomerName) ? "Khách vãng lai" : request.CustomerName.Trim(),
                PhoneNumber = request.PhoneNumber?.Trim(),
                OrderType = request.OrderType > 0 ? request.OrderType : 1, // 1: DineIn, 2: Takeaway, 3: Delivery
                Note = request.Note?.Trim(),
                TotalAmount = totalAmount,
                DiscountAmount = discount,
                FinalAmount = finalAmount,
                Status = 0, // 0: Mới
                PaymentStatus = 0, // 0: Chưa thanh toán
                CreatedAt = DateTime.Now
            };

            context.Orders.Add(order);
            context.SaveChanges(); // Lưu để sinh OrderId

            // Lưu các chi tiết món ăn (OrderDetails)
            foreach (var item in request.Items)
            {
                var detail = new OrderDetail
                {
                    OrderId = order.OrderId,
                    ProductId = item.ProductId,
                    Quantity = item.Quantity > 0 ? item.Quantity : 1,
                    UnitPrice = item.UnitPrice,
                    SubTotal = item.UnitPrice * (item.Quantity > 0 ? item.Quantity : 1),
                    ItemNote = item.ItemNote?.Trim(),
                    CookingStatus = 0 // 0: Chờ nấu (Pending)
                };
                context.OrderDetails.Add(detail);
            }
            context.SaveChanges();

            // Cập nhật trạng thái bàn ăn nếu có bàn gắn liền
            if (table != null)
            {
                table.Status = 1; // 1: Có khách (Occupied)
                table.CurrentOrderId = order.OrderId;
                table.UpdatedAt = DateTime.Now;
                context.SaveChanges();
            }

            transaction.Commit();
            return (true, "Tạo đơn hàng thành công, đơn đã được chuyển vào bếp", order);
        }
        catch (Exception ex)
        {
            transaction.Rollback();
            return (false, $"Lỗi xử lý tạo đơn hàng: {ex.Message}", null);
        }
    }

    /// <summary>
    /// Lấy danh sách đơn hàng cho Admin / Thu ngân kèm bộ lọc ngày, trạng thái, tìm kiếm
    /// </summary>
    public OrderAdminResult GetAdminOrders(
        DateTime? fromDate,
        DateTime? toDate,
        int? status,
        string? search,
        int page = 1,
        int pageSize = 50)
    {
        var query = context.Orders.AsQueryable();

        if (fromDate.HasValue)
        {
            var start = fromDate.Value.Date;
            query = query.Where(o => o.CreatedAt >= start);
        }

        if (toDate.HasValue)
        {
            var end = toDate.Value.Date.AddDays(1).AddTicks(-1);
            query = query.Where(o => o.CreatedAt <= end);
        }

        if (status.HasValue && status.Value >= 0)
        {
            query = query.Where(o => o.Status == status.Value);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            string s = search.Trim().ToLower();
            query = query.Where(o => o.OrderCode.ToLower().Contains(s)
                                || (o.CustomerName != null && o.CustomerName.ToLower().Contains(s))
                                || (o.PhoneNumber != null && o.PhoneNumber.Contains(s)));
        }

        int totalOrders = query.Count();
        decimal totalRevenue = query
            .Where(o => o.Status != 4) // Bỏ qua đơn bị hủy
            .Sum(o => (decimal?)o.FinalAmount) ?? 0;

        var pagedOrders = query
            .OrderByDescending(o => o.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToList();

        // Lấy tên bàn và danh sách chi tiết
        var tableIds = pagedOrders.Where(o => o.TableId.HasValue).Select(o => o.TableId!.Value).Distinct().ToList();
        var tables = context.DiningTables.Where(t => tableIds.Contains(t.TableId)).ToDictionary(t => t.TableId, t => t.TableName);

        var orderIds = pagedOrders.Select(o => o.OrderId).ToList();
        var detailsCount = context.OrderDetails
            .Where(d => orderIds.Contains(d.OrderId))
            .GroupBy(d => d.OrderId)
            .ToDictionary(g => g.Key, g => g.Sum(x => x.Quantity));

        var dtos = pagedOrders.Select(o => new OrderAdminDto
        {
            OrderId = o.OrderId,
            OrderCode = o.OrderCode,
            TableId = o.TableId,
            TableName = o.TableId.HasValue && tables.ContainsKey(o.TableId.Value) ? tables[o.TableId.Value] : "Mang về / Vãng lai",
            CustomerName = o.CustomerName ?? "Khách vãng lai",
            PhoneNumber = o.PhoneNumber,
            OrderType = o.OrderType,
            TotalAmount = o.TotalAmount,
            DiscountAmount = o.DiscountAmount,
            FinalAmount = o.FinalAmount,
            Status = o.Status,
            StatusText = GetStatusText(o.Status),
            PaymentStatus = o.PaymentStatus,
            PaymentStatusText = o.PaymentStatus == 1 ? "Đã thanh toán" : "Chưa thanh toán",
            TotalItems = detailsCount.ContainsKey(o.OrderId) ? detailsCount[o.OrderId] : 0,
            CreatedAt = o.CreatedAt,
            CompletedAt = o.CompletedAt
        }).ToList();

        return new OrderAdminResult
        {
            TotalOrders = totalOrders,
            TotalRevenue = totalRevenue,
            Page = page,
            PageSize = pageSize,
            Orders = dtos
        };
    }

    /// <summary>
    /// Lấy chi tiết toàn bộ đơn hàng kèm danh sách món
    /// </summary>
    public OrderDetailResult? GetOrderById(int orderId)
    {
        var order = context.Orders.Find(orderId);
        if (order == null) return null;

        string tableName = "Mang về";
        if (order.TableId.HasValue)
        {
            var table = context.DiningTables.Find(order.TableId.Value);
            if (table != null) tableName = table.TableName;
        }

        var details = (from d in context.OrderDetails
                       join p in context.Products on d.ProductId equals p.ProductId into prodGroup
                       from p in prodGroup.DefaultIfEmpty()
                       where d.OrderId == orderId
                       select new OrderItemDetailDto
                       {
                           OrderDetailId = d.OrderDetailId,
                           ProductId = d.ProductId,
                           ProductName = p != null ? p.ProductName : $"Món #{d.ProductId}",
                           ProductImage = p != null ? p.ImageUrl : "default.png",
                           Quantity = d.Quantity,
                           UnitPrice = d.UnitPrice,
                           SubTotal = d.SubTotal,
                           ItemNote = d.ItemNote,
                           CookingStatus = d.CookingStatus,
                           CookingStatusText = GetCookingStatusText(d.CookingStatus),
                           StartedCookingAt = d.StartedCookingAt,
                           FinishedCookingAt = d.FinishedCookingAt
                       }).ToList();

        var payment = context.Payments
            .Where(p => p.OrderId == orderId)
            .OrderByDescending(p => p.PaymentId)
            .FirstOrDefault();

        return new OrderDetailResult
        {
            OrderId = order.OrderId,
            OrderCode = order.OrderCode,
            TableId = order.TableId,
            TableName = tableName,
            AccountId = order.AccountId,
            CustomerName = order.CustomerName ?? "Khách vãng lai",
            PhoneNumber = order.PhoneNumber,
            OrderType = order.OrderType,
            Note = order.Note,
            TotalAmount = order.TotalAmount,
            DiscountAmount = order.DiscountAmount,
            FinalAmount = order.FinalAmount,
            Status = order.Status,
            StatusText = GetStatusText(order.Status),
            PaymentStatus = order.PaymentStatus,
            PaymentStatusText = order.PaymentStatus == 1 ? "Đã thanh toán" : "Chưa thanh toán",
            PaymentMethod = payment?.PaymentMethod,
            CreatedAt = order.CreatedAt,
            CompletedAt = order.CompletedAt,
            Items = details
        };
    }

    /// <summary>
    /// Lấy đơn hàng đang hoạt động của một bàn ăn cụ thể
    /// </summary>
    public OrderDetailResult? GetActiveOrderByTable(int tableId)
    {
        var order = context.Orders
            .Where(o => o.TableId == tableId && o.Status < 3)
            .OrderByDescending(o => o.OrderId)
            .FirstOrDefault();

        if (order == null) return null;
        return GetOrderById(order.OrderId);
    }

    /// <summary>
    /// Cập nhật trạng thái đơn hàng (0: Mới, 1: Đang nấu, 2: Đã phục vụ, 3: Hoàn thành, 4: Hủy)
    /// Khi Hoàn thành hoặc Hủy, tự động giải phóng bàn ăn (Status = 0: Trống).
    /// </summary>
    public (bool Success, string Message) UpdateOrderStatus(int orderId, int newStatus)
    {
        if (newStatus < 0 || newStatus > 4)
        {
            return (false, "Trạng thái đơn hàng không hợp lệ (0: Mới, 1: Đang nấu, 2: Đã phục vụ, 3: Hoàn thành, 4: Hủy)");
        }

        var order = context.Orders.Find(orderId);
        if (order == null)
        {
            return (false, $"Không tìm thấy đơn hàng có ID = {orderId}");
        }

        order.Status = newStatus;
        if (newStatus == 3)
        {
            order.CompletedAt = DateTime.Now;
        }

        // Nếu hoàn thành (3) hoặc hủy (4), kiểm tra bàn ăn để giải phóng
        if ((newStatus == 3 || newStatus == 4) && order.TableId.HasValue)
        {
            // Kiểm tra xem còn đơn hàng nào khác đang hoạt động trên bàn này không
            bool hasOtherActiveOrders = context.Orders
                .Any(o => o.TableId == order.TableId.Value && o.OrderId != orderId && o.Status < 3);

            if (!hasOtherActiveOrders)
            {
                var table = context.DiningTables.Find(order.TableId.Value);
                if (table != null)
                {
                    table.Status = 0; // Trống
                    table.CurrentOrderId = null;
                    table.UpdatedAt = DateTime.Now;
                }
            }
        }

        context.SaveChanges();
        return (true, $"Cập nhật trạng thái đơn #{order.OrderCode} sang '{GetStatusText(newStatus)}' thành công");
    }

    /// <summary>
    /// Lấy danh sách các món ăn cần chế biến cho màn hình Bếp / Pha chế (KDS)
    /// Sắp xếp theo FIFO (đơn vào trước ưu tiên hiển thị trước).
    /// </summary>
    public List<KdsItemDto> GetKdsActiveItems()
    {
        var activeOrders = context.Orders
            .Where(o => o.Status < 3 && o.Status != 4)
            .ToDictionary(o => o.OrderId, o => o);

        var activeOrderIds = activeOrders.Keys.ToList();

        var query = from d in context.OrderDetails
                    where activeOrderIds.Contains(d.OrderId) && d.CookingStatus < 2
                    join p in context.Products on d.ProductId equals p.ProductId into prodGroup
                    from p in prodGroup.DefaultIfEmpty()
                    orderby d.OrderId ascending, d.OrderDetailId ascending
                    select new
                    {
                        d.OrderDetailId,
                        d.OrderId,
                        d.ProductId,
                        ProductName = p != null ? p.ProductName : $"Món #{d.ProductId}",
                        ProductImage = p != null ? p.ImageUrl : "default.png",
                        d.Quantity,
                        d.ItemNote,
                        d.CookingStatus,
                        d.StartedCookingAt,
                        d.FinishedCookingAt
                    };

        var rawList = query.ToList();

        var tableIds = activeOrders.Values.Where(o => o.TableId.HasValue).Select(o => o.TableId!.Value).Distinct().ToList();
        var tables = context.DiningTables.Where(t => tableIds.Contains(t.TableId)).ToDictionary(t => t.TableId, t => t.TableName);

        var result = rawList.Select(item =>
        {
            var ord = activeOrders[item.OrderId];
            string tbl = ord.TableId.HasValue && tables.ContainsKey(ord.TableId.Value) ? tables[ord.TableId.Value] : "Mang về";
            return new KdsItemDto
            {
                OrderDetailId = item.OrderDetailId,
                OrderId = item.OrderId,
                OrderCode = ord.OrderCode,
                TableId = ord.TableId,
                TableName = tbl,
                CustomerName = ord.CustomerName ?? "Khách vãng lai",
                ProductId = item.ProductId,
                ProductName = item.ProductName,
                ProductImage = item.ProductImage,
                Quantity = item.Quantity,
                ItemNote = item.ItemNote,
                CookingStatus = item.CookingStatus,
                CookingStatusText = GetCookingStatusText(item.CookingStatus),
                CreatedAt = ord.CreatedAt,
                StartedCookingAt = item.StartedCookingAt,
                FinishedCookingAt = item.FinishedCookingAt
            };
        }).ToList();

        return result;
    }

    /// <summary>
    /// Cập nhật trạng thái chế biến món ăn trên màn hình KDS
    /// (0: Chờ nấu -> 1: Đang làm -> 2: Đã nấu xong)
    /// </summary>
    public (bool Success, string Message) UpdateCookingStatus(int orderDetailId, int cookingStatus)
    {
        if (cookingStatus < 0 || cookingStatus > 3)
        {
            return (false, "Trạng thái chế biến không hợp lệ (0: Chờ nấu, 1: Đang làm, 2: Đã xong)");
        }

        var detail = context.OrderDetails.Find(orderDetailId);
        if (detail == null)
        {
            return (false, $"Không tìm thấy chi tiết món #{orderDetailId}");
        }

        detail.CookingStatus = cookingStatus;
        if (cookingStatus == 1 && !detail.StartedCookingAt.HasValue)
        {
            detail.StartedCookingAt = DateTime.Now;
        }
        else if (cookingStatus == 2)
        {
            detail.FinishedCookingAt = DateTime.Now;
        }

        context.SaveChanges();

        // Kiểm tra xem toàn bộ món trong đơn đã xong chưa để cập nhật Order.Status
        var allOrderDetails = context.OrderDetails.Where(d => d.OrderId == detail.OrderId).ToList();
        var parentOrder = context.Orders.Find(detail.OrderId);

        if (parentOrder != null)
        {
            if (allOrderDetails.All(d => d.CookingStatus >= 2) && parentOrder.Status < 2)
            {
                parentOrder.Status = 2; // Đã phục vụ / Sẵn sàng phục vụ
                context.SaveChanges();
            }
            else if (allOrderDetails.Any(d => d.CookingStatus == 1) && parentOrder.Status == 0)
            {
                parentOrder.Status = 1; // Đang chế biến
                context.SaveChanges();
            }
        }

        return (true, $"Đã cập nhật món sang '{GetCookingStatusText(cookingStatus)}'");
    }

    public static string GetStatusText(int status) => status switch
    {
        0 => "Mới tạo",
        1 => "Đang chế biến",
        2 => "Đã phục vụ",
        3 => "Hoàn thành & Thu tiền",
        4 => "Đã hủy",
        _ => "Không xác định"
    };

    public static string GetCookingStatusText(int cookingStatus) => cookingStatus switch
    {
        0 => "Chờ nấu",
        1 => "Đang làm",
        2 => "Đã nấu xong",
        3 => "Đã ra món",
        _ => "Chờ nấu"
    };
}

public class CreateOrderRequest
{
    public int? TableId { get; set; }
    public int? AccountId { get; set; }
    public string? CustomerName { get; set; }
    public string? PhoneNumber { get; set; }
    public int OrderType { get; set; } = 1; // 1: DineIn, 2: Takeaway, 3: Delivery
    public string? Note { get; set; }
    public decimal? DiscountAmount { get; set; } = 0;
    public List<CreateOrderItemRequest> Items { get; set; } = new();
}

public class CreateOrderItemRequest
{
    public int ProductId { get; set; }
    public int Quantity { get; set; } = 1;
    public decimal UnitPrice { get; set; }
    public string? ItemNote { get; set; }
}

public class OrderAdminResult
{
    public int TotalOrders { get; set; }
    public decimal TotalRevenue { get; set; }
    public int Page { get; set; }
    public int PageSize { get; set; }
    public List<OrderAdminDto> Orders { get; set; } = new();
}

public class OrderAdminDto
{
    public int OrderId { get; set; }
    public string OrderCode { get; set; } = string.Empty;
    public int? TableId { get; set; }
    public string TableName { get; set; } = string.Empty;
    public string CustomerName { get; set; } = string.Empty;
    public string? PhoneNumber { get; set; }
    public int OrderType { get; set; }
    public decimal TotalAmount { get; set; }
    public decimal DiscountAmount { get; set; }
    public decimal FinalAmount { get; set; }
    public int Status { get; set; }
    public string StatusText { get; set; } = string.Empty;
    public int PaymentStatus { get; set; }
    public string PaymentStatusText { get; set; } = string.Empty;
    public int TotalItems { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? CompletedAt { get; set; }
}

public class OrderDetailResult
{
    public int OrderId { get; set; }
    public string OrderCode { get; set; } = string.Empty;
    public int? TableId { get; set; }
    public string TableName { get; set; } = string.Empty;
    public int? AccountId { get; set; }
    public string CustomerName { get; set; } = string.Empty;
    public string? PhoneNumber { get; set; }
    public int OrderType { get; set; }
    public string? Note { get; set; }
    public decimal TotalAmount { get; set; }
    public decimal DiscountAmount { get; set; }
    public decimal FinalAmount { get; set; }
    public int Status { get; set; }
    public string StatusText { get; set; } = string.Empty;
    public int PaymentStatus { get; set; }
    public string PaymentStatusText { get; set; } = string.Empty;
    public string? PaymentMethod { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? CompletedAt { get; set; }
    public List<OrderItemDetailDto> Items { get; set; } = new();
}

public class OrderItemDetailDto
{
    public int OrderDetailId { get; set; }
    public int ProductId { get; set; }
    public string ProductName { get; set; } = string.Empty;
    public string ProductImage { get; set; } = string.Empty;
    public int Quantity { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal SubTotal { get; set; }
    public string? ItemNote { get; set; }
    public int CookingStatus { get; set; }
    public string CookingStatusText { get; set; } = string.Empty;
    public DateTime? StartedCookingAt { get; set; }
    public DateTime? FinishedCookingAt { get; set; }
}

public class KdsItemDto
{
    public int OrderDetailId { get; set; }
    public int OrderId { get; set; }
    public string OrderCode { get; set; } = string.Empty;
    public int? TableId { get; set; }
    public string TableName { get; set; } = string.Empty;
    public string CustomerName { get; set; } = string.Empty;
    public int ProductId { get; set; }
    public string ProductName { get; set; } = string.Empty;
    public string ProductImage { get; set; } = string.Empty;
    public int Quantity { get; set; }
    public string? ItemNote { get; set; }
    public int CookingStatus { get; set; }
    public string CookingStatusText { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime? StartedCookingAt { get; set; }
    public DateTime? FinishedCookingAt { get; set; }
}
