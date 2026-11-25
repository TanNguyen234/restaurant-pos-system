using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebApi.Models;

namespace WebApi.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class LoyaltyController : BaseController
{
    private int GetCallerAccountId()
    {
        var claim = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("accountId");
        return int.TryParse(claim, out int id) ? id : 0;
    }

    [HttpGet("me")]
    public async Task<IActionResult> GetMyLoyalty()
    {
        int accountId = GetCallerAccountId();
        if (accountId <= 0) return Unauthorized(new { success = false, message = "Phiên đăng nhập không hợp lệ" });

        var profile = await Provider.Loyalty.GetProfileAsync(accountId);
        if (profile == null) return NotFound(new { success = false, message = "Không tìm thấy tài khoản" });

        return Ok(new { statusCode = 200, success = true, data = profile });
    }

    [HttpPost("redeem")]
    public async Task<IActionResult> Redeem([FromBody] RedeemVoucherDto dto)
    {
        int accountId = GetCallerAccountId();
        if (accountId <= 0) return Unauthorized(new { success = false, message = "Phiên đăng nhập không hợp lệ" });

        if (dto == null || string.IsNullOrWhiteSpace(dto.Code))
            return BadRequest(new { success = false, message = "Vui lòng chọn mã voucher" });

        var res = await Provider.Loyalty.RedeemVoucherAsync(accountId, dto.Code);
        if (!res.Success)
        {
            return BadRequest(new { statusCode = 400, success = false, message = res.Message, loyaltyPoints = res.RemainingPoints });
        }

        return Ok(new
        {
            statusCode = 200,
            success = true,
            message = res.Message,
            loyaltyPoints = res.RemainingPoints,
            voucherCode = res.VoucherCode
        });
    }
}

public class RedeemVoucherDto
{
    public string Code { get; set; } = string.Empty;
}
