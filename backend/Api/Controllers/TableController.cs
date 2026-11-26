using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebApi.Models;
using WebApi.Services;

namespace WebApi.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class TableController : BaseController
{
    private readonly PosRealtimeNotifier _realtime;

    public TableController(PosRealtimeNotifier realtime)
    {
        _realtime = realtime;
    }

    private int? GetCallerAccountId()
    {
        var claim = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("accountId");
        return int.TryParse(claim, out int id) && id > 0 ? id : null;
    }

    private bool IsStaffUser() =>
        User.IsInRole("ADMIN") || User.IsInRole("MANAGER") || User.IsInRole("CASHIER") || User.IsInRole("WAITER") || User.IsInRole("KITCHEN");

    [HttpGet("areas")]
    [AllowAnonymous]
    public IActionResult GetAreas()
    {
        var areas = Provider.Table.GetAreas();
        return Ok(areas);
    }

    [HttpGet("by-area/{areaId:int}")]
    [AllowAnonymous]
    public IActionResult GetTablesByArea(int areaId)
    {
        var tables = Provider.Table.GetTablesByArea(areaId);
        return Ok(tables);
    }

    [HttpGet]
    [AllowAnonymous]
    public IActionResult GetAllTables()
    {
        var tables = Provider.Table.GetAllEnrichedTables();
        return Ok(tables);
    }

    [HttpGet("{id:int}")]
    [AllowAnonymous]
    public IActionResult GetById(int id)
    {
        var table = Provider.Table.GetEnrichedById(id);
        if (table == null)
        {
            return NotFound(new { success = false, message = $"Không tìm thấy bàn có ID = {id}" });
        }
        return Ok(table);
    }

    [HttpPut("{id:int}/status")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER,WAITER")]
    public async Task<IActionResult> UpdateStatus(int id, [FromBody] UpdateTableStatusRequest? body = null, [FromQuery] int? status = null)
    {
        int? resolvedStatus = body?.Status ?? status;
        if (!resolvedStatus.HasValue)
        {
            return BadRequest(new { success = false, message = "Vui lòng cung cấp trạng thái bàn mới (status: 0: Trống, 1: Có khách, 2: Chờ phục vụ, 3: Đặt trước)" });
        }

        if (resolvedStatus.Value < 0 || resolvedStatus.Value > 3)
        {
            return BadRequest(new { success = false, message = "Trạng thái bàn không hợp lệ. Giá trị hợp lệ: 0..3" });
        }

        var result = Provider.Table.UpdateStatusSafe(id, resolvedStatus.Value);
        if (!result.Success || result.Table == null)
        {
            if (result.Message.Contains("Không tìm thấy"))
                return NotFound(new { success = false, message = result.Message });
            return BadRequest(new { success = false, message = result.Message });
        }

        await _realtime.NotifyTableChangedAsync(new { action = "StatusUpdated", tableId = id, status = resolvedStatus.Value });

        return Ok(new
        {
            success = true,
            message = result.Message,
            tableId = result.Table.TableId,
            status = result.Table.Status,
            table = result.Table
        });
    }

    [HttpPost("transfer")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER,WAITER")]
    public async Task<IActionResult> Transfer([FromBody] TransferTableRequest request)
    {
        if (request == null)
            return BadRequest(new { success = false, message = "Dữ liệu yêu cầu chuyển bàn không hợp lệ" });

        int fromId = request.FromTableId ?? request.SourceTableId ?? 0;
        int toId = request.ToTableId ?? request.TargetTableId ?? 0;

        if (fromId <= 0 || toId <= 0)
            return BadRequest(new { success = false, message = "Vui lòng cung cấp đầy đủ ID bàn nguồn và bàn đích" });

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

        await _realtime.NotifyTableChangedAsync(new { action = "Transfer", fromTableId = result.FromTableId, toTableId = result.ToTableId });

        return Ok(new
        {
            success = true,
            message = result.Message,
            fromTableId = result.FromTableId,
            toTableId = result.ToTableId
        });
    }

    [HttpPost("merge")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER,WAITER")]
    public async Task<IActionResult> Merge([FromBody] TransferTableRequest request)
    {
        if (request == null) return BadRequest(new { success = false, message = "Dữ liệu yêu cầu gộp bàn không hợp lệ" });
        int fromId = request.FromTableId ?? request.SourceTableId ?? 0;
        int toId = request.ToTableId ?? request.TargetTableId ?? 0;

        if (fromId <= 0 || toId <= 0) return BadRequest(new { success = false, message = "Vui lòng cung cấp ID bàn nguồn và bàn đích" });

        var result = Provider.Table.MergeTables(fromId, toId);
        if (!result.Success) return BadRequest(new { success = false, message = result.Message });

        await _realtime.NotifyTableChangedAsync(new { action = "Merge", fromTableId = result.FromTableId, toTableId = result.ToTableId });
        return Ok(new { success = true, message = result.Message, fromTableId = result.FromTableId, toTableId = result.ToTableId });
    }

    [HttpPost("split")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER,WAITER")]
    public async Task<IActionResult> Split([FromBody] SplitTableRequest request)
    {
        if (request == null) return BadRequest(new { success = false, message = "Dữ liệu yêu cầu tách bàn không hợp lệ" });
        if (request.FromTableId <= 0 || request.ToTableId <= 0) return BadRequest(new { success = false, message = "Vui lòng chọn bàn nguồn và bàn đích" });
        if (request.OrderDetailIds == null || request.OrderDetailIds.Count == 0) return BadRequest(new { success = false, message = "Vui lòng chọn ít nhất 1 món để tách" });

        var result = Provider.Table.SplitTable(request.FromTableId, request.ToTableId, request.OrderDetailIds);
        if (!result.Success) return BadRequest(new { success = false, message = result.Message });

        await _realtime.NotifyTableChangedAsync(new { action = "Split", fromTableId = request.FromTableId, toTableId = request.ToTableId, newOrderId = result.NewOrderId });
        return Ok(new { success = true, message = result.Message, newOrderId = result.NewOrderId });
    }

    [HttpPost("reserve")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER,WAITER,MEMBER,VIP_MEMBER")]
    public async Task<IActionResult> Reserve([FromBody] ReserveTableRequest request)
    {
        if (request == null || request.TableId <= 0) return BadRequest(new { success = false, message = "Vui lòng chọn bàn cần đặt" });
        if (string.IsNullOrWhiteSpace(request.CustomerName) || string.IsNullOrWhiteSpace(request.PhoneNumber))
            return BadRequest(new { success = false, message = "Vui lòng cung cấp họ tên và số điện thoại khách hàng" });

        var arrivalTime = request.ArrivalTime ?? DateTime.Now.AddHours(2);
        var result = Provider.Table.ReserveTable(
            request.TableId,
            request.CustomerName,
            request.PhoneNumber,
            request.GuestCount,
            arrivalTime,
            request.DepositAmount,
            request.Note,
            request.DurationMinutes,
            request.HoldGraceMinutes,
            GetCallerAccountId());

        if (!result.Success) return BadRequest(new { success = false, message = result.Message });

        await _realtime.NotifyTableChangedAsync(new { action = "Reserved", tableId = request.TableId, reservationId = result.Reservation?.ReservationId });
        return Ok(new { success = true, message = result.Message, data = result.Reservation });
    }

    [HttpGet("reservations")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER,WAITER,MEMBER,VIP_MEMBER")]
    public IActionResult GetReservations([FromQuery] DateTime? fromDate = null, [FromQuery] bool includeInactive = false)
    {
        bool isStaff = IsStaffUser();
        int? callerId = GetCallerAccountId();
        string? callerPhone = null;
        if (!isStaff && callerId.HasValue)
        {
            callerPhone = Provider.Account.GetById(callerId.Value)?.PhoneNumber;
        }

        var list = Provider.Table.GetReservations(
            fromDate,
            onlyAccountId: isStaff ? null : (callerId ?? -1),
            onlyPhone: callerPhone,
            includeInactive: includeInactive || !isStaff);
        return Ok(new { success = true, total = list.Count, data = list });
    }

    [HttpPut("reservation/{id:int}/check-in")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER,WAITER")]
    public async Task<IActionResult> CheckInReservation(int id)
    {
        var result = Provider.Table.CheckInReservation(id);
        if (!result.Success) return BadRequest(new { success = false, message = result.Message });

        await _realtime.NotifyTableChangedAsync(new { action = "CheckedIn", tableId = result.TableId, reservationId = id });
        return Ok(new { success = true, message = result.Message, tableId = result.TableId, depositAmount = result.DepositAmount });
    }

    [HttpDelete("reservation/{id:int}")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER,WAITER,MEMBER,VIP_MEMBER")]
    public async Task<IActionResult> CancelReservation(int id)
    {
        var result = Provider.Table.CancelReservation(id, GetCallerAccountId(), IsStaffUser());
        if (result.Forbidden) return Forbid();
        if (!result.Success) return BadRequest(new { success = false, message = result.Message });

        await _realtime.NotifyTableChangedAsync(new { action = "ReservationCancelled", tableId = result.TableId, reservationId = id });
        return Ok(new { success = true, message = result.Message });
    }

    [HttpPost]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public IActionResult CreateTable([FromBody] CreateTableRequest request)
    {
        if (request == null || string.IsNullOrWhiteSpace(request.TableName))
            return BadRequest(new { success = false, message = "Tên bàn không được để trống" });

        var result = Provider.Table.CreateTable(request.AreaId, request.TableName, request.Capacity);
        if (!result.Success) return BadRequest(new { success = false, message = result.Message });
        return Ok(new { success = true, message = result.Message, data = result.Table });
    }

    [HttpPut("{id:int}")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public IActionResult UpdateTable(int id, [FromBody] UpdateTableRequest request)
    {
        if (request == null) return BadRequest(new { success = false, message = "Dữ liệu cập nhật không hợp lệ" });
        var result = Provider.Table.UpdateTable(id, request.AreaId, request.TableName, request.Capacity, request.Status);
        if (!result.Success) return BadRequest(new { success = false, message = result.Message });
        return Ok(new { success = true, message = result.Message, data = result.Table });
    }

    [HttpDelete("{id:int}")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public IActionResult DeleteTable(int id)
    {
        var result = Provider.Table.DeleteTable(id);
        if (!result.Success) return BadRequest(new { success = false, message = result.Message });
        return Ok(new { success = true, message = result.Message });
    }

    [HttpPost("area")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public IActionResult CreateArea([FromBody] CreateAreaRequest request)
    {
        if (request == null || string.IsNullOrWhiteSpace(request.AreaName))
            return BadRequest(new { success = false, message = "Tên khu vực không được để trống" });

        var result = Provider.Table.CreateArea(request.AreaName, request.Description, request.SortOrder);
        if (!result.Success) return BadRequest(new { success = false, message = result.Message });
        return Ok(new { success = true, message = result.Message, data = result.Area });
    }

    [HttpPut("area/{id:int}")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public IActionResult UpdateArea(int id, [FromBody] UpdateAreaRequest request)
    {
        if (request == null || string.IsNullOrWhiteSpace(request.AreaName))
            return BadRequest(new { success = false, message = "Tên khu vực không được để trống" });

        var result = Provider.Table.UpdateArea(id, request.AreaName, request.Description, request.SortOrder, request.IsActive);
        if (!result.Success) return BadRequest(new { success = false, message = result.Message });
        return Ok(new { success = true, message = result.Message, data = result.Area });
    }

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
    public int DurationMinutes { get; set; } = TableRepository.DefaultDurationMinutes;
    public int HoldGraceMinutes { get; set; } = TableRepository.DefaultHoldGraceMinutes;
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
