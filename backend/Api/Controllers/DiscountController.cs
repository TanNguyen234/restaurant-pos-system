using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebApi.Models;

namespace WebApi.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class DiscountController : BaseController
{
    /// <summary>
    /// GET /api/discount/active
    /// Retrieves list of currently active discount programs and vouchers.
    /// </summary>
    [HttpGet("active")]
    [AllowAnonymous]
    public async Task<IActionResult> GetActiveDiscounts()
    {
        var discounts = await Provider.Discount.GetActiveDiscountsAsync();
        return Ok(new
        {
            statusCode = 200,
            success = true,
            total = discounts.Count,
            data = discounts
        });
    }

    /// <summary>
    /// POST /api/discount/validate
    /// Validates voucher code and calculates discount amount for an order.
    /// </summary>
    [HttpPost("validate")]
    [AllowAnonymous]
    public async Task<IActionResult> ValidateDiscount([FromBody] ValidateDiscountRequest request)
    {
        if (request == null || string.IsNullOrWhiteSpace(request.Code))
        {
            return BadRequest(new { statusCode = 400, success = false, message = "Vui lòng nhập mã giảm giá" });
        }

        var result = await Provider.Discount.ValidateDiscountAsync(request.Code, request.OrderAmount);
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
