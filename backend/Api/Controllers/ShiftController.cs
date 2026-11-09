using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebApi.Models;

namespace WebApi.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "ADMIN,MANAGER,CASHIER")]
public class ShiftController : BaseController
{
    /// <summary>
    /// GET /api/shift/current
    /// Retrieves current active shift for cashier or branch.
    /// </summary>
    [HttpGet("current")]
    public async Task<IActionResult> GetCurrentShift([FromQuery] int? accountId)
    {
        var shift = await Provider.Shift.GetCurrentShiftAsync(accountId);
        if (shift == null)
        {
            return Ok(new
            {
                statusCode = 200,
                hasActiveShift = false,
                message = "Hiện chưa có ca làm việc nào đang mở"
            });
        }

        return Ok(new
        {
            statusCode = 200,
            hasActiveShift = true,
            data = shift
        });
    }

    /// <summary>
    /// POST /api/shift/open
    /// Opens a new cash register shift with float money.
    /// </summary>
    [HttpPost("open")]
    public async Task<IActionResult> OpenShift([FromBody] OpenShiftDto dto)
    {
        if (dto == null || dto.AccountId <= 0)
        {
            return BadRequest(new { statusCode = 400, success = false, message = "Thông tin mở ca không hợp lệ" });
        }

        if (dto.InitialCash < 0)
        {
            return BadRequest(new { statusCode = 400, success = false, message = "Số tiền lẻ đầu ca không được âm" });
        }

        var result = await Provider.Shift.OpenShiftAsync(dto);
        if (!result.Success)
        {
            return BadRequest(new { statusCode = 400, success = false, message = result.Message });
        }

        return Ok(new
        {
            statusCode = 200,
            success = true,
            message = result.Message,
            data = result.Shift
        });
    }

    /// <summary>
    /// POST /api/shift/close
    /// Closes active shift, audits cash drawer, and generates Z-Report.
    /// </summary>
    [HttpPost("close")]
    public async Task<IActionResult> CloseShift([FromBody] CloseShiftDto dto)
    {
        if (dto == null || dto.ShiftId <= 0)
        {
            return BadRequest(new { statusCode = 400, success = false, message = "Mã ca làm việc không hợp lệ" });
        }

        if (dto.ActualCash < 0)
        {
            return BadRequest(new { statusCode = 400, success = false, message = "Số tiền mặt thực tế không được âm" });
        }

        var result = await Provider.Shift.CloseShiftAsync(dto);
        if (!result.Success)
        {
            return BadRequest(new { statusCode = 400, success = false, message = result.Message });
        }

        return Ok(new
        {
            statusCode = 200,
            success = true,
            message = result.Message,
            data = result.Report
        });
    }

    /// <summary>
    /// GET /api/shift/{id}/z-report
    /// Retrieves Z-Report of a closed shift.
    /// </summary>
    [HttpGet("{id:int}/z-report")]
    public async Task<IActionResult> GetZReport(int id)
    {
        var report = await Provider.Shift.GetZReportAsync(id);
        if (report == null)
        {
            return NotFound(new { statusCode = 404, success = false, message = $"Không tìm thấy báo cáo Z-Report cho ca #{id}" });
        }

        return Ok(new
        {
            statusCode = 200,
            success = true,
            data = report
        });
    }
}
