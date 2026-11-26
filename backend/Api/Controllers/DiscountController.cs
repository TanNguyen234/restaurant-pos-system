using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebApi.Models;

namespace WebApi.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class DiscountController : BaseController
{
    private int? GetCallerAccountId()
    {
        var claim = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("accountId");
        return int.TryParse(claim, out int id) && id > 0 ? id : null;
    }

    [HttpGet("active")]
    [AllowAnonymous]
    public async Task<IActionResult> GetActiveDiscounts()
    {
        var discounts = await Provider.Discount.GetActiveDiscountsAsync();
        int? accountId = GetCallerAccountId();
        var ownedCounts = accountId.HasValue
            ? await Provider.Discount.GetOwnedVoucherCountsAsync(accountId.Value)
            : new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);

        return Ok(new
        {
            statusCode = 200,
            success = true,
            total = discounts.Count,
            ownedCounts,
            data = discounts
        });
    }

    [HttpPost("validate")]
    [AllowAnonymous]
    public async Task<IActionResult> ValidateDiscount([FromBody] ValidateDiscountRequest request)
    {
        if (request == null || string.IsNullOrWhiteSpace(request.Code))
        {
            return BadRequest(new { statusCode = 400, success = false, message = "Vui lòng nhập mã giảm giá" });
        }

        var result = await Provider.Discount.ValidateDiscountAsync(request.Code, request.OrderAmount, GetCallerAccountId());
        if (!result.IsValid)
        {
            return BadRequest(new
            {
                statusCode = 400,
                success = false,
                message = result.Message,
                code = request.Code,
                finalAmount = request.OrderAmount
            });
        }

        return Ok(new
        {
            statusCode = 200,
            success = true,
            message = result.Message,
            code = result.Code,
            title = result.Title,
            discountPercent = result.DiscountPercent,
            discountAmount = result.DiscountAmount,
            finalAmount = result.FinalAmount
        });
    }
}

public class ValidateDiscountRequest
{
    public string Code { get; set; } = string.Empty;
    public decimal OrderAmount { get; set; }
}
