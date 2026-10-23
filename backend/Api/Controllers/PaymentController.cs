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

    /// <summary>
    /// POST /api/payment/cash
    /// Processes cash payment confirmation at cashier desk. Marks order paid and releases table.
    /// </summary>
    [HttpPost("cash")]
    public async Task<IActionResult> ProcessCashPayment([FromBody] CashPaymentRequestDto dto)
    {
        if (dto == null || dto.OrderId <= 0)
        {
            return BadRequest(new { statusCode = 400, message = "Mã đơn hàng không hợp lệ" });
        }

        var result = await Provider.Payment.ProcessCashPaymentAsync(dto.OrderId, dto.Note);
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

    /// <summary>
    /// POST /api/payment/confirm
    /// Confirms payment across all methods (Cash, VietQR, VNPay) for Flutter mobile client.
    /// </summary>
    [HttpPost("confirm")]
    public async Task<IActionResult> ConfirmPayment([FromBody] ConfirmPaymentRequestDto dto)
    {
        if (dto == null || dto.OrderId <= 0)
        {
            return BadRequest(new { statusCode = 400, success = false, message = "Thông tin đơn hàng thanh toán không hợp lệ" });
        }

        var result = await Provider.Payment.ProcessPaymentAsync(dto.OrderId, dto.PaymentMethod, dto.Amount, dto.TransactionRef, dto.Note);
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

    /// <summary>
    /// GET /api/payment/vietqr/{orderId}
    /// Generates dynamic VietQR image link and payment transfer details for customer scanning.
    /// </summary>
    [HttpGet("vietqr/{orderId:int}")]
    public async Task<IActionResult> GenerateVietQr(int orderId)
    {
        var result = await Provider.Payment.GenerateVietQrAsync(orderId);
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

    /// <summary>
    /// POST /api/payment/vnpay/create-url
    /// Creates signed VNPay Sandbox payment redirect URL with HMAC-SHA512 checksum.
    /// </summary>
    [HttpPost("vnpay/create-url")]
    public async Task<IActionResult> CreateVnPayUrl([FromBody] VnPayUrlRequestDto dto)
    {
        string tmnCode = _configuration["VNPay:TmnCode"] ?? "SANDBOX_TMNCODE";
        string hashSecret = _configuration["VNPay:HashSecret"] ?? "SANDBOX_HASH_SECRET_KEY_FOR_TESTING_PURPOSES";
        string vnpUrl = _configuration["VNPay:Url"] ?? "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html";
        string returnUrl = _configuration["VNPay:ReturnUrl"] ?? dto.ReturnUrl ?? "http://localhost:5138/api/payment/vnpay/callback";

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

    /// <summary>
    /// POST /api/payment/create-vnpay-url
    /// Alternative endpoint matching mobile client.
    /// </summary>
    [HttpPost("create-vnpay-url")]
    public async Task<IActionResult> CreateVnPayUrlAlt([FromBody] VnPayUrlRequestDto dto)
    {
        return await CreateVnPayUrl(dto);
    }

    /// <summary>
    /// GET /api/payment/vnpay/callback
    /// Handles VNPay callback and verifies HMAC-SHA512 signature before recording settlement.
    /// </summary>
    [HttpGet("vnpay/callback")]
    public async Task<IActionResult> VnPayCallback()
    {
        string hashSecret = _configuration["VNPay:HashSecret"] ?? "SANDBOX_HASH_SECRET_KEY_FOR_TESTING_PURPOSES";
        var queryParams = Request.Query.ToDictionary(q => q.Key, q => q.Value.ToString());

        var result = await Provider.Payment.ProcessVnPayCallbackAsync(queryParams, hashSecret);
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

    /// <summary>
    /// GET /api/payment/vnpay-return
    /// Alternative callback route for VNPay.
    /// </summary>
    [HttpGet("vnpay-return")]
    public async Task<IActionResult> VnPayReturn()
    {
        return await VnPayCallback();
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
