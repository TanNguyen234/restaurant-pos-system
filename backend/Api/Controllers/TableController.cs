using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebApi.Models;

namespace WebApi.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class TableController : BaseController
{
    /// <summary>
    /// GET /api/table/areas
    /// Lấy danh sách toàn bộ các khu vực đang hoạt động trong nhà hàng
    /// </summary>
    [HttpGet("areas")]
    public IActionResult GetAreas()
    {
        var areas = Provider.Table.GetAreas();
        return Ok(areas);
    }

    /// <summary>
    /// GET /api/table/by-area/{areaId}
    /// Lấy danh sách bàn theo khu vực
    /// </summary>
    [HttpGet("by-area/{areaId:int}")]
    public IActionResult GetTablesByArea(int areaId)
    {
        var tables = Provider.Table.GetTablesByArea(areaId);
        return Ok(tables);
    }

    /// <summary>
    /// GET /api/table
    /// Lấy toàn bộ danh sách bàn và trạng thái hiện tại
    /// </summary>
    [HttpGet]
    public IActionResult GetAllTables()
    {
        var tables = Provider.Table.GetAllEnrichedTables();
        return Ok(tables);
    }

    /// <summary>
    /// GET /api/table/{id}
    /// Lấy thông tin chi tiết của 1 bàn theo ID
    /// </summary>
    [HttpGet("{id:int}")]
    public IActionResult GetById(int id)
    {
        var table = Provider.Table.GetById(id);
        if (table == null)
        {
            return NotFound(new { success = false, message = $"Không tìm thấy bàn có ID = {id}" });
        }
        return Ok(table);
    }

    /// <summary>
    /// PUT /api/table/{id}/status
    /// Cập nhật trạng thái bàn ăn (0: Bàn trống, 1: Có khách, 2: Chờ phục vụ, 3: Đã đặt trước)
    /// Hỗ trợ cả Request Body JSON { "status": 1 } và Query Param ?status=1
    /// </summary>
    [HttpPut("{id:int}/status")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER,WAITER")]
    public IActionResult UpdateStatus(int id, [FromBody] UpdateTableStatusRequest? body = null, [FromQuery] int? status = null)
    {
        int? resolvedStatus = body?.Status ?? status;

        if (!resolvedStatus.HasValue)
        {
            return BadRequest(new { success = false, message = "Vui lòng cung cấp trạng thái bàn mới (status: 0: Trống, 1: Có khách, 2: Chờ phục vụ, 3: Đã đặt trước)" });
        }

        if (resolvedStatus.Value < 0 || resolvedStatus.Value > 3)
        {
            return BadRequest(new { success = false, message = "Trạng thái bàn không hợp lệ. Giá trị hợp lệ: 0 (Trống), 1 (Có khách), 2 (Chờ phục vụ), 3 (Đã đặt trước)" });
        }

        var updatedTable = Provider.Table.UpdateStatus(id, resolvedStatus.Value);
        if (updatedTable == null)
        {
            return NotFound(new { success = false, message = $"Không tìm thấy bàn có ID = {id}" });
        }

        return Ok(new
        {
            success = true,
            message = "Cập nhật trạng thái thành công",
            tableId = updatedTable.TableId,
            status = updatedTable.Status,
            table = updatedTable
        });
    }

    /// <summary>
    /// POST /api/table/transfer
    /// Chuyển bàn từ bàn nguồn sang bàn đích bằng transaction
    /// Body hỗ trợ: { "fromTableId": 1, "toTableId": 2 } hoặc { "sourceTableId": 1, "targetTableId": 2 }
    /// </summary>
    [HttpPost("transfer")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER,WAITER")]
    public IActionResult Transfer([FromBody] TransferTableRequest request)
    {
        if (request == null)
        {
            return BadRequest(new { success = false, message = "Dữ liệu yêu cầu chuyển bàn không hợp lệ" });
        }

        int fromId = request.FromTableId ?? request.SourceTableId ?? 0;
        int toId = request.ToTableId ?? request.TargetTableId ?? 0;

        if (fromId <= 0 || toId <= 0)
        {
            return BadRequest(new { success = false, message = "Vui lòng cung cấp đầy đủ ID bàn nguồn (fromTableId) và bàn đích (toTableId)" });
        }

        var result = Provider.Table.TransferTable(fromId, toId);
        if (!result.Success)
        {
            return BadRequest(new
            {
                success = false,
                message = result.Message,
                fromTableId = result.FromTableId,
                toTableId = result.ToTableId
            });
        }

        return Ok(new
        {
            success = true,
            message = result.Message,
            fromTableId = result.FromTableId,
            toTableId = result.ToTableId
        });
    }

    /// <summary>
    /// POST /api/table/merge
    /// Gộp hóa đơn từ bàn nguồn vào bàn đích
    /// </summary>
    [HttpPost("merge")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER,WAITER")]
    public IActionResult Merge([FromBody] TransferTableRequest request)
    {
        if (request == null) return BadRequest(new { success = false, message = "Dữ liệu yêu cầu gộp bàn không hợp lệ" });
        int fromId = request.FromTableId ?? request.SourceTableId ?? 0;
        int toId = request.ToTableId ?? request.TargetTableId ?? 0;

        if (fromId <= 0 || toId <= 0) return BadRequest(new { success = false, message = "Vui lòng cung cấp ID bàn nguồn và bàn đích" });

        var result = Provider.Table.MergeTables(fromId, toId);
        if (!result.Success) return BadRequest(new { success = false, message = result.Message });

        return Ok(new { success = true, message = result.Message, fromTableId = result.FromTableId, toTableId = result.ToTableId });
    }

    /// <summary>
    /// POST /api/table/split
    /// Tách một số món sang bàn trống mới
    /// </summary>
    [HttpPost("split")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER,WAITER")]
    public IActionResult Split([FromBody] SplitTableRequest request)
    {
        if (request == null) return BadRequest(new { success = false, message = "Dữ liệu yêu cầu tách bàn không hợp lệ" });
        if (request.FromTableId <= 0 || request.ToTableId <= 0) return BadRequest(new { success = false, message = "Vui lòng chọn bàn nguồn và bàn đích" });
        if (request.OrderDetailIds == null || request.OrderDetailIds.Count == 0) return BadRequest(new { success = false, message = "Vui lòng chọn ít nhất 1 món để tách" });

        var result = Provider.Table.SplitTable(request.FromTableId, request.ToTableId, request.OrderDetailIds);
        if (!result.Success) return BadRequest(new { success = false, message = result.Message });

        return Ok(new { success = true, message = result.Message, newOrderId = result.NewOrderId });
    }

    /// <summary>
    /// POST /api/table/reserve
    /// Đặt bàn trước cho khách hàng
    /// </summary>
    [HttpPost("reserve")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER,WAITER,MEMBER")]
    public IActionResult Reserve([FromBody] ReserveTableRequest request)
    {
        if (request == null || request.TableId <= 0) return BadRequest(new { success = false, message = "Vui lòng chọn bàn cần đặt" });
        if (string.IsNullOrWhiteSpace(request.CustomerName) || string.IsNullOrWhiteSpace(request.PhoneNumber))
            return BadRequest(new { success = false, message = "Vui lòng cung cấp họ tên và số điện thoại khách hàng" });

        var arrivalTime = request.ArrivalTime ?? DateTime.Now.AddHours(2);
        var result = Provider.Table.ReserveTable(request.TableId, request.CustomerName, request.PhoneNumber, request.GuestCount, arrivalTime, request.DepositAmount, request.Note);
        if (!result.Success) return BadRequest(new { success = false, message = result.Message });

        return Ok(new { success = true, message = result.Message, data = result.Reservation });
    }

    /// <summary>
    /// GET /api/table/reservations
    /// Lấy danh sách đặt bàn
    /// </summary>
    [HttpGet("reservations")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER,WAITER")]
    public IActionResult GetReservations([FromQuery] DateTime? fromDate)
    {
        var list = Provider.Table.GetReservations(fromDate);
        return Ok(new { success = true, total = list.Count, data = list });
    }

    /// <summary>
    /// PUT /api/table/reservation/{id}/check-in
    /// Khách đến nhận bàn đã đặt
    /// </summary>
    [HttpPut("reservation/{id:int}/check-in")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER,WAITER")]
    public IActionResult CheckInReservation(int id)
    {
        var result = Provider.Table.CheckInReservation(id);
        if (!result.Success) return BadRequest(new { success = false, message = result.Message });
        return Ok(new { success = true, message = result.Message });
    }

    /// <summary>
    /// DELETE /api/table/reservation/{id}
    /// Hủy yêu cầu đặt bàn
    /// </summary>
    [HttpDelete("reservation/{id:int}")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER,WAITER")]
    public IActionResult CancelReservation(int id)
    {
        var result = Provider.Table.CancelReservation(id);
        if (!result.Success) return BadRequest(new { success = false, message = result.Message });
        return Ok(new { success = true, message = result.Message });
    }

    /// <summary>
    /// POST /api/table
    /// Tạo bàn mới
    /// </summary>
    [HttpPost]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public IActionResult CreateTable([FromBody] CreateTableRequest request)
    {
        if (request == null || string.IsNullOrWhiteSpace(request.TableName))
        {
            return BadRequest(new { success = false, message = "Tên bàn không được để trống" });
        }
        var result = Provider.Table.CreateTable(request.AreaId, request.TableName, request.Capacity);
        if (!result.Success) return BadRequest(new { success = false, message = result.Message });
        return Ok(new { success = true, message = result.Message, data = result.Table });
    }

    /// <summary>
    /// PUT /api/table/{id}
    /// Cập nhật bàn
    /// </summary>
    [HttpPut("{id:int}")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public IActionResult UpdateTable(int id, [FromBody] UpdateTableRequest request)
    {
        if (request == null) return BadRequest(new { success = false, message = "Dữ liệu cập nhật không hợp lệ" });
        var result = Provider.Table.UpdateTable(id, request.AreaId, request.TableName, request.Capacity, request.Status);
        if (!result.Success) return BadRequest(new { success = false, message = result.Message });
        return Ok(new { success = true, message = result.Message, data = result.Table });
    }

    /// <summary>
    /// DELETE /api/table/{id}
    /// Xóa bàn
    /// </summary>
    [HttpDelete("{id:int}")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public IActionResult DeleteTable(int id)
    {
        var result = Provider.Table.DeleteTable(id);
        if (!result.Success) return BadRequest(new { success = false, message = result.Message });
        return Ok(new { success = true, message = result.Message });
    }

    /// <summary>
    /// POST /api/table/area
    /// Tạo khu vực mới
    /// </summary>
    [HttpPost("area")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public IActionResult CreateArea([FromBody] CreateAreaRequest request)
    {
        if (request == null || string.IsNullOrWhiteSpace(request.AreaName))
        {
            return BadRequest(new { success = false, message = "Tên khu vực không được để trống" });
        }
        var result = Provider.Table.CreateArea(request.AreaName, request.Description, request.SortOrder);
        if (!result.Success) return BadRequest(new { success = false, message = result.Message });
        return Ok(new { success = true, message = result.Message, data = result.Area });
    }

    /// <summary>
    /// PUT /api/table/area/{id}
    /// Cập nhật khu vực
    /// </summary>
    [HttpPut("area/{id:int}")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public IActionResult UpdateArea(int id, [FromBody] UpdateAreaRequest request)
    {
        if (request == null || string.IsNullOrWhiteSpace(request.AreaName))
        {
            return BadRequest(new { success = false, message = "Tên khu vực không được để trống" });
        }
        var result = Provider.Table.UpdateArea(id, request.AreaName, request.Description, request.SortOrder, request.IsActive);
        if (!result.Success) return BadRequest(new { success = false, message = result.Message });
        return Ok(new { success = true, message = result.Message, data = result.Area });
    }

    /// <summary>
    /// DELETE /api/table/area/{id}
    /// Xóa khu vực
    /// </summary>
    [HttpDelete("area/{id:int}")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public IActionResult DeleteArea(int id)
    {
        var result = Provider.Table.DeleteArea(id);
        if (!result.Success) return BadRequest(new { success = false, message = result.Message });
        return Ok(new { success = true, message = result.Message });
    }
}

public class SplitTableRequest
{
    public int FromTableId { get; set; }
    public int ToTableId { get; set; }
    public List<int> OrderDetailIds { get; set; } = new();
}

public class ReserveTableRequest
{
    public int TableId { get; set; }
    public string CustomerName { get; set; } = string.Empty;
    public string PhoneNumber { get; set; } = string.Empty;
    public int GuestCount { get; set; } = 2;
    public DateTime? ArrivalTime { get; set; }
    public decimal DepositAmount { get; set; } = 0;
    public string? Note { get; set; }
}


public class UpdateTableStatusRequest
{
    public int? Status { get; set; }
}

public class TransferTableRequest
{
    public int? FromTableId { get; set; }
    public int? ToTableId { get; set; }
    public int? SourceTableId { get; set; }
    public int? TargetTableId { get; set; }
}
