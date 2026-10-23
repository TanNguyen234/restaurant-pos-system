namespace WebApi.Models;

public class CreateOrderItemDto
{
    public int ProductId { get; set; }
    public int Quantity { get; set; }
    public string? ItemNote { get; set; }
}

public class CreateOrderDto
{
    public string? IdempotencyKey { get; set; }
    public int? OfflineOrderId { get; set; }
    public int? TableId { get; set; }
    public int? AccountId { get; set; }
    public string? CustomerName { get; set; }
    public string? PhoneNumber { get; set; }
    public int OrderType { get; set; } = 1; // 1: DineIn, 2: Takeaway, 3: Delivery
    public string? Note { get; set; }
    public decimal? TotalAmount { get; set; }
    public List<CreateOrderItemDto> Items { get; set; } = new();
    public DateTime? CreatedAt { get; set; }
}

public class OrderDetailDto
{
    public int OrderDetailId { get; set; }
    public int OrderId { get; set; }
    public int ProductId { get; set; }
    public string ProductName { get; set; } = string.Empty;
    public string? ImageUrl { get; set; }
    public int Quantity { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal SubTotal { get; set; }
    public string? ItemNote { get; set; }
    public int CookingStatus { get; set; } // 0: Pending, 1: Cooking, 2: Ready
    public string CookingStatusText => CookingStatus switch
    {
        1 => "Đang nấu",
        2 => "Đã xong",
        _ => "Chờ nấu"
    };
    public DateTime? StartedCookingAt { get; set; }
    public DateTime? FinishedCookingAt { get; set; }
}

public class OrderDto
{
    public int OrderId { get; set; }
    public string OrderCode { get; set; } = string.Empty;
    public int? TableId { get; set; }
    public string? TableName { get; set; }
    public int? AccountId { get; set; }
    public string? WaiterName { get; set; }
    public string? CustomerName { get; set; }
    public string? PhoneNumber { get; set; }
    public int OrderType { get; set; }
    public string OrderTypeText => OrderType switch
    {
        2 => "Mang về (Takeaway)",
        3 => "Giao hàng (Delivery)",
        _ => "Tại bàn (Dine-in)"
    };
    public string? Note { get; set; }
    public decimal TotalAmount { get; set; }
    public decimal DiscountAmount { get; set; }
    public decimal FinalAmount { get; set; }
    public int Status { get; set; } // 0: New, 1: Cooking, 2: Served, 3: Completed, 4: Cancelled
    public string StatusText => Status switch
    {
        1 => "Đang chế biến",
        2 => "Đã phục vụ",
        3 => "Hoàn thành",
        4 => "Đã hủy",
        _ => "Đơn mới"
    };
    public int PaymentStatus { get; set; } // 0: Unpaid, 1: Paid
    public string PaymentStatusText => PaymentStatus == 1 ? "Đã thanh toán" : "Chưa thanh toán";
    public DateTime CreatedAt { get; set; }
    public DateTime? CompletedAt { get; set; }
    public List<OrderDetailDto> Details { get; set; } = new();
}

public class KdsItemDto
{
    public int OrderDetailId { get; set; }
    public int OrderId { get; set; }
    public string OrderCode { get; set; } = string.Empty;
    public string? TableName { get; set; }
    public int ProductId { get; set; }
    public string ProductName { get; set; } = string.Empty;
    public int Quantity { get; set; }
    public string? ItemNote { get; set; }
    public int CookingStatus { get; set; } // 0: Pending, 1: Cooking, 2: Ready
    public DateTime OrderCreatedAt { get; set; }
    public DateTime? StartedCookingAt { get; set; }
    public DateTime? FinishedCookingAt { get; set; }
}
