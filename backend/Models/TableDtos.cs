namespace WebApi.Models;

public class TableResponseDto
{
    public int TableId { get; set; }
    public int AreaId { get; set; }
    public string TableName { get; set; } = string.Empty;
    public int Capacity { get; set; } = 4;
    public int Status { get; set; } = 0;
    public int? CurrentOrderId { get; set; }
    public DateTime UpdatedAt { get; set; }
    public DateTime? OrderCreatedAt { get; set; }
    public decimal RunningTotal { get; set; } = 0;
    public int ItemCount { get; set; } = 0;
    public int? NextReservationId { get; set; }
    public string? NextReservationCustomer { get; set; }
    public DateTime? NextReservationTime { get; set; }
    public DateTime? NextReservationExpiresAt { get; set; }
    public decimal? NextReservationDeposit { get; set; }
}

public class ReservationDto
{
    public int ReservationId { get; set; }
    public int TableId { get; set; }
    public string TableName { get; set; } = string.Empty;
    public string AreaName { get; set; } = string.Empty;
    public int? AccountId { get; set; }
    public string CustomerName { get; set; } = string.Empty;
    public string PhoneNumber { get; set; } = string.Empty;
    public int GuestCount { get; set; }
    public DateTime ArrivalTime { get; set; }
    public int DurationMinutes { get; set; }
    public int HoldGraceMinutes { get; set; }
    public DateTime? ExpiresAt { get; set; }
    public decimal DepositAmount { get; set; }
    public bool DepositApplied { get; set; }
    public int? CheckedInOrderId { get; set; }
    public string? Note { get; set; }
    public int Status { get; set; }
    public string StatusText => Status switch
    {
        0 => "Chờ xác nhận",
        1 => "Đã xác nhận",
        2 => "Đã nhận bàn",
        3 => "Đã hủy",
        4 => "Quá hạn (No-Show)",
        _ => "Không xác định"
    };
    public DateTime CreatedAt { get; set; }
}

public class CreateTableRequest
{
    public int AreaId { get; set; }
    public string TableName { get; set; } = string.Empty;
    public int Capacity { get; set; } = 4;
}

public class UpdateTableRequest
{
    public int? AreaId { get; set; }
    public string? TableName { get; set; }
    public int? Capacity { get; set; }
    public int? Status { get; set; }
}

public class CreateAreaRequest
{
    public string AreaName { get; set; } = string.Empty;
    public string? Description { get; set; }
    public int SortOrder { get; set; } = 0;
}

public class UpdateAreaRequest
{
    public string AreaName { get; set; } = string.Empty;
    public string? Description { get; set; }
    public int SortOrder { get; set; } = 0;
    public bool IsActive { get; set; } = true;
}
