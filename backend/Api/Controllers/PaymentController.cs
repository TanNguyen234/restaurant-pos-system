using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebApi.Models;

namespace WebApi.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class PaymentController : BaseController
{
    private readonly IConfiguration _configuration;

    public PaymentController(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    private int? GetCallerAccountId()
    {
        var claim = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("accountId");
        return int.TryParse(claim, out int id) && id > 0 ? id : null;
    }

    [HttpPost("cash")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER")]
    public async Task<IActionResult> ProcessCashPayment([FromBody] CashPaymentRequestDto dto)
    {
        if (dto == null || dto.OrderId <= 0)
        {
            return BadRequest(new { statusCode = 400, success = false, message = "Mã đơn hàng không hợp lệ" });
        }

        var result = await Provider.Payment.ProcessCashPaymentAsync(dto.OrderId, dto.Note, GetCallerAccountId());
        if (!result.Success)
        {
            return BadRequest(new { statusCode = 400, success = false, message = result.Message });
        }

        return Ok(new
        {
            statusCode = 200,
            success = true,
            message = result.Message,
            data = result.Payment,
            paymentId = result.Payment?.PaymentId
        });
    }

    [HttpPost("confirm")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER")]
    public async Task<IActionResult> ConfirmPayment([FromBody] ConfirmPaymentRequestDto dto)
    {
        if (dto == null || dto.OrderId <= 0)
        {
            return BadRequest(new { statusCode = 400, success = false, message = "Thông tin đơn hàng thanh toán không hợp lệ" });
        }

        var result = await Provider.Payment.ProcessPaymentAsync(
            dto.OrderId,
            dto.PaymentMethod,
            dto.Amount,
            dto.TransactionRef,
            dto.Note,
            GetCallerAccountId());

        if (!result.Success)
        {
            return BadRequest(new { statusCode = 400, success = false, message = result.Message });
        }

        return Ok(new
        {
            statusCode = 200,
            success = true,
            message = result.Message,
            paymentId = result.Payment?.PaymentId,
            data = result.Payment
        });
    }

    [HttpGet("vietqr/{orderId:int}")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER,WAITER,MEMBER")]
    public async Task<IActionResult> GenerateVietQr(int orderId, [FromQuery] decimal? amount = null)
    {
        var order = await Provider.Order.GetOrderByIdAsync(orderId);
        if (order == null)
        {
            return NotFound(new { statusCode = 404, success = false, message = "Không tìm thấy đơn hàng" });
        }

        bool isStaff = User.IsInRole("ADMIN") || User.IsInRole("MANAGER") || User.IsInRole("CASHIER") || User.IsInRole("WAITER");
        if (!isStaff && order.AccountId.HasValue && GetCallerAccountId() != order.AccountId.Value)
        {
            return Forbid();
        }

        var result = await Provider.Payment.GenerateVietQrAsync(orderId, _configuration, amount);
        if (!result.Success)
        {
            return BadRequest(new { statusCode = 400, success = false, message = result.Message });
        }

        return Ok(new
        {
            statusCode = 200,
            success = true,
            message = result.Message,
            data = result.QrResult
        });
    }

    [HttpPost("vnpay/create-url")]
    [HttpPost("create-vnpay-url")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER,WAITER,MEMBER")]
    public async Task<IActionResult> CreateVnPayUrl([FromBody] VnPayUrlRequestDto dto)
    {
        if (dto == null || dto.OrderId <= 0)
        {
            return BadRequest(new { statusCode = 400, success = false, message = "Mã đơn hàng không hợp lệ" });
        }

        var order = await Provider.Order.GetOrderByIdAsync(dto.OrderId);
        if (order == null)
        {
            return NotFound(new { statusCode = 404, success = false, message = "Không tìm thấy đơn hàng" });
        }

        bool isStaff = User.IsInRole("ADMIN") || User.IsInRole("MANAGER") || User.IsInRole("CASHIER") || User.IsInRole("WAITER");
        if (!isStaff && order.AccountId.HasValue && GetCallerAccountId() != order.AccountId.Value)
        {
            return Forbid();
        }

        string? tmnCode = _configuration["VNPay:TmnCode"] ?? _configuration["VNP_TMN_CODE"];
        string? hashSecret = _configuration["VNPay:HashSecret"] ?? _configuration["VNP_HASH_SECRET"];
        string vnpUrl = _configuration["VNPay:Url"] ?? _configuration["VNP_URL"] ?? "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html";
        string returnUrl = _configuration["VNPay:ReturnUrl"] ?? _configuration["VNP_RETURN_URL"] ?? dto.ReturnUrl ?? "http://localhost:5138/api/payment/vnpay/callback";

        if (string.IsNullOrWhiteSpace(tmnCode) || string.IsNullOrWhiteSpace(hashSecret))
        {
            return StatusCode(500, new { statusCode = 500, success = false, message = "Chưa cấu hình VNPay TmnCode/HashSecret trong .env" });
        }

        string clientIp = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "127.0.0.1";
        var result = await Provider.Payment.GenerateVnPayUrlAsync(dto.OrderId, tmnCode, hashSecret, vnpUrl, returnUrl, clientIp, dto.OrderInfo);
        if (!result.Success)
        {
            return BadRequest(new { statusCode = 400, success = false, message = result.Message });
        }

        return Ok(new
        {
            statusCode = 200,
            success = true,
            message = "Tạo liên kết VNPay Sandbox thành công",
            paymentUrl = result.PaymentUrl,
            status = "SANDBOX VERIFIED"
        });
    }

    [HttpGet("vnpay/callback")]
    [HttpGet("vnpay-return")]
    [AllowAnonymous]
    public async Task<IActionResult> VnPayCallback()
    {
        string? hashSecret = _configuration["VNPay:HashSecret"] ?? _configuration["VNP_HASH_SECRET"];
        string? tmnCode = _configuration["VNPay:TmnCode"] ?? _configuration["VNP_TMN_CODE"];
        if (string.IsNullOrWhiteSpace(hashSecret))
        {
            return StatusCode(500, new { statusCode = 500, success = false, message = "Chưa cấu hình VNPay HashSecret" });
        }

        var queryParams = Request.Query.ToDictionary(q => q.Key, q => q.Value.ToString());
        var result = await Provider.Payment.ProcessVnPayCallbackAsync(queryParams, hashSecret, tmnCode);
        if (!result.Success)
        {
            return BadRequest(new
            {
                statusCode = 400,
                success = false,
                message = result.Message
            });
        }

        return Ok(new
        {
            statusCode = 200,
            success = true,
            message = result.Message,
            orderId = result.OrderId,
            status = "SANDBOX VERIFIED"
        });
    }
}

public class CashPaymentRequestDto
{
    public int OrderId { get; set; }
    public string? Note { get; set; }
}

public class ConfirmPaymentRequestDto
{
    public int OrderId { get; set; }
    public string PaymentMethod { get; set; } = "Cash";
    public decimal? Amount { get; set; }
    public string? TransactionRef { get; set; }
    public string? Note { get; set; }
}

public class VnPayUrlRequestDto
{
    public int OrderId { get; set; }
    public decimal? Amount { get; set; }
    public string? OrderInfo { get; set; }
    public string? ReturnUrl { get; set; }
}
