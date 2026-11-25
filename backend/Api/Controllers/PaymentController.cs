using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebApi.Models;
using WebApi.Services;

namespace WebApi.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class PaymentController : BaseController
{
    private readonly IConfiguration _configuration;
    private readonly PosRealtimeNotifier _realtime;

    public PaymentController(IConfiguration configuration, PosRealtimeNotifier realtime)
    {
        _configuration = configuration;
        _realtime = realtime;
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

        await _realtime.NotifyOrderChangedAsync("OrderPaid", result.Payment);
        await _realtime.NotifyTableChangedAsync(new { orderId = dto.OrderId });

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

        await _realtime.NotifyOrderChangedAsync("OrderPaid", result.Payment);
        await _realtime.NotifyTableChangedAsync(new { orderId = dto.OrderId });

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

        if (result.Success)
        {
            await _realtime.NotifyOrderChangedAsync("OrderPaid", new { orderId = result.OrderId, method = "VNPay" });
            await _realtime.NotifyTableChangedAsync(new { orderId = result.OrderId });
        }

        bool wantsHtml = Request.Headers.Accept.ToString()
            .Contains("text/html", StringComparison.OrdinalIgnoreCase);

        if (!wantsHtml)
        {
            if (!result.Success)
            {
                return BadRequest(new
                {
                    statusCode = 400,
                    success = false,
                    message = result.Message,
                    orderId = result.OrderId
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

        string? configFrontend = _configuration["Frontend:BaseUrl"];
        string? envAllowed = Environment.GetEnvironmentVariable("ALLOWED_ORIGINS") ?? _configuration["ALLOWED_ORIGINS"];
        string frontendBase = "http://localhost:8088";
        if (!string.IsNullOrWhiteSpace(configFrontend))
        {
            frontendBase = configFrontend.Trim().TrimEnd('/');
        }
        else if (!string.IsNullOrWhiteSpace(envAllowed))
        {
            var candidate = envAllowed
                .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .FirstOrDefault(u => u.StartsWith("http://localhost:", StringComparison.OrdinalIgnoreCase) && !u.Contains(":5138"))
                ?? envAllowed.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).FirstOrDefault();
            if (!string.IsNullOrWhiteSpace(candidate))
            {
                frontendBase = candidate.TrimEnd('/');
            }
        }

        string responseCode = queryParams.TryGetValue("vnp_ResponseCode", out var rc) ? rc : "";
        string statusKey = result.Success ? "success" : (responseCode == "24" ? "cancelled" : "failed");
        int oid = result.OrderId ?? 0;

        string safeMsg = System.Net.WebUtility.HtmlEncode(result.Message);
        string safeCode = System.Net.WebUtility.HtmlEncode(responseCode);
        string backOrderUrl = oid > 0
            ? $"{frontendBase}/?vnpayStatus={statusKey}&orderId={oid}&code={Uri.EscapeDataString(responseCode)}"
            : $"{frontendBase}/";
        string restoreCartUrl = oid > 0
            ? $"{frontendBase}/?vnpayStatus=restore&orderId={oid}&code={Uri.EscapeDataString(responseCode)}"
            : $"{frontendBase}/";

        string badgeColor = result.Success ? "#059669" : (statusKey == "cancelled" ? "#D97706" : "#DC2626");
        string titleText = result.Success
            ? "Thanh toán VNPay thành công!"
            : (statusKey == "cancelled" ? "Bạn đã hủy thanh toán VNPay" : "Thanh toán VNPay chưa hoàn tất");

        string restoreBtn = !result.Success && oid > 0
            ? $"<a class=\"btn btn-outline\" href=\"{System.Net.WebUtility.HtmlEncode(restoreCartUrl)}\">Hủy đơn &amp; Khôi phục về giỏ hàng</a>"
            : "";

        string html = $@"<!DOCTYPE html>
<html lang=""vi"">
<head>
  <meta charset=""utf-8"" />
  <meta name=""viewport"" content=""width=device-width, initial-scale=1"" />
  <title>{System.Net.WebUtility.HtmlEncode(titleText)}</title>
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background:#F8FAFC; color:#0F172A; margin:0; padding:24px; display:flex; align-items:center; justify-content:center; min-height:100vh; }}
    .card {{ background:#fff; border:1px solid #E2E8F0; border-radius:18px; max-width:460px; width:100%; padding:28px 24px; box-shadow:0 10px 30px rgba(15,23,42,.08); text-align:center; }}
    .badge {{ display:inline-block; padding:6px 14px; border-radius:999px; font-weight:700; font-size:13px; color:#fff; background:{badgeColor}; margin-bottom:14px; }}
    h1 {{ font-size:20px; margin:0 0 10px; }}
    p {{ font-size:14px; color:#475569; line-height:1.5; margin:0 0 22px; }}
    .btn {{ display:block; width:100%; box-sizing:border-box; padding:13px 16px; border-radius:12px; font-weight:700; font-size:14px; text-decoration:none; margin-bottom:10px; }}
    .btn-primary {{ background:#0F172A; color:#fff; }}
    .btn-outline {{ background:#FEF2F2; color:#DC2626; border:1px solid #FECACA; }}
  </style>
</head>
<body>
  <div class=""card"">
    <span class=""badge"">{(string.IsNullOrEmpty(safeCode) ? statusKey.ToUpperInvariant() : $"VNPay Mã {safeCode}")}</span>
    <h1>{System.Net.WebUtility.HtmlEncode(titleText)}</h1>
    <p>{safeMsg}</p>
    <a class=""btn btn-primary"" href=""{System.Net.WebUtility.HtmlEncode(backOrderUrl)}"">{(result.Success ? "Xem hóa đơn vừa thanh toán" : "Quay lại đơn hàng / Đổi phương thức thanh toán")}</a>
    {restoreBtn}
  </div>
</body>
</html>";

        Response.StatusCode = result.Success ? 200 : 400;
        return Content(html, "text/html; charset=utf-8");
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
