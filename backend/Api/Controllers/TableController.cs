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
        var tables = Provider.Table.GetAllTables();
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
