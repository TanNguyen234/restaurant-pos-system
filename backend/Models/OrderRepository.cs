using Microsoft.EntityFrameworkCore;

namespace WebApi.Models;

public class OrderRepository : BaseRepository
{
    public OrderRepository(RestaurantPosContext context) : base(context) { }

    private static readonly object _orderCodeLock = new object();

    private string GenerateOrderCode(int? offlineOrderId, int? tableId)
    {
        if (offlineOrderId.HasValue && offlineOrderId.Value > 0)
        {
            return $"ORD-OFF-{offlineOrderId.Value:D6}";
        }

        lock (_orderCodeLock)
        {
            string datePart = DateTime.Now.ToString("yyyyMMdd");
            string randomPart = Guid.NewGuid().ToString("N").Substring(0, 6).ToUpper();
            return $"ORD-{datePart}-{randomPart}";
        }
    }

    public async Task<(bool Success, string Message, OrderDto? Order)> CreateOrderAsync(CreateOrderDto dto)
    {
        if (dto.Items == null || dto.Items.Count == 0)
        {
            return (false, "Đơn hàng phải có ít nhất một món ăn hoặc thức uống", null);
        }

        // Idempotency check for offline sync or retry
        if (dto.OfflineOrderId.HasValue && dto.OfflineOrderId.Value > 0)
        {
            string expectedOfflineCode = $"ORD-OFF-{dto.OfflineOrderId.Value:D6}";
            var existingOrder = await context.Orders
                .FirstOrDefaultAsync(o => o.OrderCode == expectedOfflineCode);
            if (existingOrder != null)
            {
                var existingDto = await GetOrderByIdAsync(existingOrder.OrderId);
                return (true, "Đơn hàng đã được đồng bộ trước đó (Idempotent)", existingDto);
            }
        }

        // Validate table if specified
        DiningTable? table = null;
        if (dto.TableId.HasValue && dto.TableId.Value > 0)
        {
            table = await context.DiningTables.FindAsync(dto.TableId.Value);
            if (table == null)
            {
                return (false, "Bàn ăn được chọn không tồn tại trong hệ thống", null);
            }
            if (table.Status == 1 && table.CurrentOrderId.HasValue)
            {
                // Table is already occupied
                var currentActive = await context.Orders.FindAsync(table.CurrentOrderId.Value);
                if (currentActive != null && currentActive.Status != 3 && currentActive.Status != 4)
                {
                    return (false, $"Bàn '{table.TableName}' hiện đang có khách (Đơn #{currentActive.OrderCode})", null);
                }
            }
        }

        // Calculate server-side total from official Product prices
        var productIds = dto.Items.Select(i => i.ProductId).Distinct().ToList();
        var products = await context.Products
            .Where(p => productIds.Contains(p.ProductId))
            .ToDictionaryAsync(p => p.ProductId);

        decimal serverTotal = 0;
        var orderDetailsToCreate = new List<OrderDetail>();

        foreach (var item in dto.Items)
        {
            if (item.Quantity <= 0)
            {
                return (false, "Số lượng món ăn phải lớn hơn 0", null);
            }

            if (!products.TryGetValue(item.ProductId, out var product))
            {
                return (false, $"Món ăn với ID {item.ProductId} không tồn tại trong thực đơn", null);
            }

            if (!product.IsAvailable)
            {
                return (false, $"Món '{product.ProductName}' hiện đang tạm hết, không thể đặt", null);
            }

            decimal unitPrice = product.Price;
            decimal subTotal = unitPrice * item.Quantity;
            serverTotal += subTotal;

            orderDetailsToCreate.Add(new OrderDetail
            {
                ProductId = item.ProductId,
                Quantity = item.Quantity,
                UnitPrice = unitPrice,
                SubTotal = subTotal,
                ItemNote = item.ItemNote,
                CookingStatus = 0 // Pending
            });
        }

        string orderCode = GenerateOrderCode(dto.OfflineOrderId, dto.TableId);

        using var transaction = await context.Database.BeginTransactionAsync();
        try
        {
            var order = new Order
            {
                OrderCode = orderCode,
                TableId = dto.TableId,
                AccountId = dto.AccountId,
                CustomerName = string.IsNullOrWhiteSpace(dto.CustomerName) ? "Khách vãng lai" : dto.CustomerName.Trim(),
                PhoneNumber = dto.PhoneNumber,
                OrderType = dto.OrderType,
                Note = dto.Note,
                TotalAmount = serverTotal,
                DiscountAmount = 0,
                FinalAmount = serverTotal,
                Status = 0, // New
                PaymentStatus = 0, // Unpaid
                CreatedAt = dto.CreatedAt ?? DateTime.Now
            };

            context.Orders.Add(order);
            await context.SaveChangesAsync();

            foreach (var detail in orderDetailsToCreate)
            {
                detail.OrderId = order.OrderId;
                context.OrderDetails.Add(detail);
            }

            // Update dining table to occupied
            if (table != null)
            {
                table.Status = 1; // Occupied
                table.CurrentOrderId = order.OrderId;
                table.UpdatedAt = DateTime.Now;
                context.DiningTables.Update(table);
            }

            await context.SaveChangesAsync();
            await transaction.CommitAsync();

            var createdDto = await GetOrderByIdAsync(order.OrderId);
            return (true, "Tạo đơn hàng thành công", createdDto);
        }
        catch (Exception ex)
        {
            await transaction.RollbackAsync();
            return (false, $"Lỗi xử lý đặt hàng: {ex.Message}", null);
        }
    }

    public async Task<PagedResult<OrderDto>> GetOrdersAsync(
        int page = 1,
        int pageSize = 10,
        int? status = null,
        int? paymentStatus = null,
        DateTime? fromDate = null,
        DateTime? toDate = null,
        string? search = null)
    {
        if (page < 1) page = 1;
        if (pageSize < 1) pageSize = 10;

        var query = from o in context.Orders
                    join t in context.DiningTables on o.TableId equals t.TableId into tGroup
                    from t in tGroup.DefaultIfEmpty()
                    join a in context.Accounts on o.AccountId equals a.AccountId into aGroup
                    from a in aGroup.DefaultIfEmpty()
                    select new
                    {
                        Order = o,
                        TableName = t != null ? t.TableName : "Mang về / Khác",
                        WaiterName = a != null ? a.FullName : "Nhân viên"
                    };

        if (status.HasValue)
        {
            query = query.Where(x => x.Order.Status == status.Value);
        }

        if (paymentStatus.HasValue)
        {
            query = query.Where(x => x.Order.PaymentStatus == paymentStatus.Value);
        }

        if (fromDate.HasValue)
        {
            query = query.Where(x => x.Order.CreatedAt >= fromDate.Value.Date);
        }

        if (toDate.HasValue)
        {
            DateTime endOfDay = toDate.Value.Date.AddDays(1).AddTicks(-1);
            query = query.Where(x => x.Order.CreatedAt <= endOfDay);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            string kw = search.Trim().ToLower();
            query = query.Where(x => x.Order.OrderCode.ToLower().Contains(kw) ||
                                     (x.Order.CustomerName != null && x.Order.CustomerName.ToLower().Contains(kw)) ||
                                     (x.Order.PhoneNumber != null && x.Order.PhoneNumber.Contains(kw)));
        }

        int total = await query.CountAsync();
        var rawOrders = await query.OrderByDescending(x => x.Order.OrderId)
                                   .Skip((page - 1) * pageSize)
                                   .Take(pageSize)
                                   .ToListAsync();

        var orderIds = rawOrders.Select(x => x.Order.OrderId).ToList();
        var details = await (from d in context.OrderDetails
                             join p in context.Products on d.ProductId equals p.ProductId into pGroup
                             from p in pGroup.DefaultIfEmpty()
                             where orderIds.Contains(d.OrderId)
                             select new
                             {
                                 Detail = d,
                                 ProductName = p != null ? p.ProductName : "Món",
                                 ImageUrl = p != null ? p.ImageUrl : null
                             }).ToListAsync();

        var dtos = rawOrders.Select(x =>
        {
            var ord = x.Order;
            var itemDtos = details.Where(d => d.Detail.OrderId == ord.OrderId)
                                  .Select(d => new OrderDetailDto
                                  {
                                      OrderDetailId = d.Detail.OrderDetailId,
                                      OrderId = d.Detail.OrderId,
                                      ProductId = d.Detail.ProductId,
                                      ProductName = d.ProductName,
                                      ImageUrl = d.ImageUrl,
                                      Quantity = d.Detail.Quantity,
                                      UnitPrice = d.Detail.UnitPrice,
                                      SubTotal = d.Detail.SubTotal,
                                      ItemNote = d.Detail.ItemNote,
                                      CookingStatus = d.Detail.CookingStatus,
                                      StartedCookingAt = d.Detail.StartedCookingAt,
                                      FinishedCookingAt = d.Detail.FinishedCookingAt
                                  }).ToList();

            return new OrderDto
            {
                OrderId = ord.OrderId,
                OrderCode = ord.OrderCode,
                TableId = ord.TableId,
                TableName = x.TableName,
                AccountId = ord.AccountId,
                WaiterName = x.WaiterName,
                CustomerName = ord.CustomerName,
                PhoneNumber = ord.PhoneNumber,
                OrderType = ord.OrderType,
                Note = ord.Note,
                TotalAmount = ord.TotalAmount,
                DiscountAmount = ord.DiscountAmount,
                FinalAmount = ord.FinalAmount,
                Status = ord.Status,
                PaymentStatus = ord.PaymentStatus,
                CreatedAt = ord.CreatedAt,
                CompletedAt = ord.CompletedAt,
                Details = itemDtos
            };
        }).ToList();

        return new PagedResult<OrderDto>
        {
            Items = dtos,
            TotalItems = total,
            Page = page,
            PageSize = pageSize
        };
    }

    public async Task<OrderDto?> GetOrderByIdAsync(int orderId)
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
                             TableName = t != null ? t.TableName : "Khác",
                             WaiterName = a != null ? a.FullName : null
                         }).FirstOrDefaultAsync();

        if (raw == null) return null;

        var details = await (from d in context.OrderDetails
                             join p in context.Products on d.ProductId equals p.ProductId into pGroup
                             from p in pGroup.DefaultIfEmpty()
                             where d.OrderId == orderId
                             select new OrderDetailDto
                             {
                                 OrderDetailId = d.OrderDetailId,
                                 OrderId = d.OrderId,
                                 ProductId = d.ProductId,
                                 ProductName = p != null ? p.ProductName : "Món",
                                 ImageUrl = p != null ? p.ImageUrl : null,
                                 Quantity = d.Quantity,
                                 UnitPrice = d.UnitPrice,
                                 SubTotal = d.SubTotal,
                                 ItemNote = d.ItemNote,
                                 CookingStatus = d.CookingStatus,
                                 StartedCookingAt = d.StartedCookingAt,
                                 FinishedCookingAt = d.FinishedCookingAt
                             }).ToListAsync();

        var ord = raw.Order;
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
            Note = ord.Note,
            TotalAmount = ord.TotalAmount,
            DiscountAmount = ord.DiscountAmount,
            FinalAmount = ord.FinalAmount,
            Status = ord.Status,
            PaymentStatus = ord.PaymentStatus,
            CreatedAt = ord.CreatedAt,
            CompletedAt = ord.CompletedAt,
            Details = details
        };
    }

    public async Task<(bool Success, string Message)> UpdateOrderStatusAsync(int orderId, int newStatus)
    {
        var order = await context.Orders.FindAsync(orderId);
        if (order == null)
        {
            return (false, "Không tìm thấy đơn hàng");
        }

        // Validate illegal transitions
        if (order.Status == 4 && newStatus != 4)
        {
            return (false, "Đơn hàng đã bị hủy, không thể kích hoạt lại");
        }
        if (order.Status == 3 && newStatus < 3)
        {
            return (false, "Đơn hàng đã hoàn thành, không thể chuyển về trạng thái trước");
        }

        order.Status = newStatus;
        if (newStatus == 3)
        {
            order.CompletedAt = DateTime.Now;
        }

        // If order is completed or cancelled, and table was assigned, release table
        if ((newStatus == 3 || newStatus == 4) && order.TableId.HasValue)
        {
            var table = await context.DiningTables.FindAsync(order.TableId.Value);
            if (table != null && table.CurrentOrderId == order.OrderId)
            {
                table.Status = 0; // Empty
                table.CurrentOrderId = null;
                table.UpdatedAt = DateTime.Now;
                context.DiningTables.Update(table);
            }
        }

        await context.SaveChangesAsync();
        return (true, "Cập nhật trạng thái đơn hàng thành công");
    }

    public async Task<List<KdsItemDto>> GetKdsItemsAsync()
    {
        var query = from d in context.OrderDetails
                    join o in context.Orders on d.OrderId equals o.OrderId
                    join p in context.Products on d.ProductId equals p.ProductId
                    join t in context.DiningTables on o.TableId equals t.TableId into tGroup
                    from t in tGroup.DefaultIfEmpty()
                    where o.Status != 3 && o.Status != 4 && d.CookingStatus < 2 // 0: Pending, 1: Cooking
                    orderby d.CookingStatus descending, o.CreatedAt ascending
                    select new KdsItemDto
                    {
                        OrderDetailId = d.OrderDetailId,
                        OrderId = d.OrderId,
                        OrderCode = o.OrderCode,
                        TableName = t != null ? t.TableName : "Mang về",
                        ProductId = d.ProductId,
                        ProductName = p.ProductName,
                        Quantity = d.Quantity,
                        ItemNote = d.ItemNote,
                        CookingStatus = d.CookingStatus,
                        OrderCreatedAt = o.CreatedAt,
                        StartedCookingAt = d.StartedCookingAt,
                        FinishedCookingAt = d.FinishedCookingAt
                    };

        return await query.ToListAsync();
    }

    public async Task<(bool Success, string Message)> UpdateCookingStatusAsync(int orderDetailId, int newStatus)
    {
        var detail = await context.OrderDetails.FindAsync(orderDetailId);
        if (detail == null)
        {
            return (false, "Không tìm thấy món ăn trong đơn hàng");
        }

        detail.CookingStatus = newStatus;
        if (newStatus == 1) // In Progress
        {
            detail.StartedCookingAt = DateTime.Now;
        }
        else if (newStatus == 2) // Ready
        {
            detail.FinishedCookingAt = DateTime.Now;
        }

        context.OrderDetails.Update(detail);
        await context.SaveChangesAsync();

        // Check if all details in this order are completed
        var allDetails = await context.OrderDetails
            .Where(d => d.OrderId == detail.OrderId)
            .ToListAsync();

        var order = await context.Orders.FindAsync(detail.OrderId);
        if (order != null)
        {
            if (allDetails.All(d => d.CookingStatus == 2))
            {
                // All items ready -> order served
                order.Status = 2; // Served
            }
            else if (allDetails.Any(d => d.CookingStatus >= 1) && order.Status == 0)
            {
                // Cooking started
                order.Status = 1; // Cooking
            }
            context.Orders.Update(order);
            await context.SaveChangesAsync();
        }

        return (true, "Cập nhật trạng thái chế biến món ăn thành công");
    }
}
