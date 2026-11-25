using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebApi.Models;

namespace WebApi.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "ADMIN,MANAGER,CASHIER")]
public class ShiftController : BaseController
{
    private int GetCallerAccountId()
    {
        var claim = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("accountId");
        return int.TryParse(claim, out int id) ? id : 0;
    }

    [HttpGet("current")]
    public async Task<IActionResult> GetCurrentShift([FromQuery] int? accountId = null)
    {
        int callerId = GetCallerAccountId();
        bool isPrivileged = User.IsInRole("ADMIN") || User.IsInRole("MANAGER");
        int? targetId = isPrivileged ? accountId : callerId;

        var shift = await Provider.Shift.GetCurrentShiftAsync(targetId);
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

    [HttpPost("open")]
    public async Task<IActionResult> OpenShift([FromBody] OpenShiftDto dto)
    {
        if (dto == null)
        {
            return BadRequest(new { statusCode = 400, success = false, message = "Thông tin mở ca không hợp lệ" });
        }

        int callerId = GetCallerAccountId();
        if (callerId <= 0)
        {
            return Unauthorized(new { statusCode = 401, success = false, message = "Không xác định được tài khoản mở ca" });
        }

        if (dto.InitialCash < 0)
        {
            return BadRequest(new { statusCode = 400, success = false, message = "Số tiền lẻ đầu ca không được âm" });
        }

        dto.AccountId = callerId; // Authoritative from JWT
        var result = await Provider.Shift.OpenShiftAsync(dto);
        if (!result.Success)
        {
            return BadRequest(new { statusCode = 400, success = false, message = result.Message });
        }

        var currentDto = await Provider.Shift.GetCurrentShiftAsync(callerId);
        return Ok(new
        {
            statusCode = 200,
            success = true,
            message = result.Message,
            data = currentDto
        });
    }

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

        bool isPrivileged = User.IsInRole("ADMIN") || User.IsInRole("MANAGER");
        var result = await Provider.Shift.CloseShiftAsync(dto, GetCallerAccountId(), isPrivileged);
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
