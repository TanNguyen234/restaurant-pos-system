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
