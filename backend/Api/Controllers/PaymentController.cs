using Microsoft.AspNetCore.Mvc;
using WebApi.Models;

namespace WebApi.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class PaymentController : BaseController
{
    /// <summary>
    /// POST /api/payment/confirm
    /// Xác nhận thanh toán đơn hàng (Tiền mặt, VietQR, VNPay)
    /// </summary>
    [HttpPost("confirm")]
    public IActionResult ConfirmPayment([FromBody] ConfirmPaymentRequest request)
    {
        if (request == null || request.OrderId <= 0)
        {
            return BadRequest(new { success = false, message = "Vui lòng cung cấp mã đơn hàng cần thanh toán" });
        }

        var result = Provider.Payment.ConfirmPayment(request);
        if (!result.Success)
        {
            return BadRequest(new { success = false, message = result.Message });
        }

        return Ok(new
        {
            success = true,
            message = result.Message,
            paymentId = result.Payment!.PaymentId,
            orderId = result.Payment.OrderId,
            amount = result.Payment.Amount,
            paymentMethod = result.Payment.PaymentMethod,
            transactionRef = result.Payment.TransactionRef,
            paymentTime = result.Payment.PaymentTime
        });
    }

    /// <summary>
    /// GET /api/payment/vietqr/{orderId}
    /// Sinh mã QR chuyển khoản VietQR NAPAS 247 động gắn liền với số tiền và mã đơn hàng
    /// </summary>
    [HttpGet("vietqr/{orderId:int}")]
    public IActionResult GetVietQr(int orderId)
    {
        var qrData = Provider.Payment.GenerateVietQr(orderId);
        if (qrData == null)
        {
            return NotFound(new { success = false, message = $"Không tìm thấy đơn hàng #{orderId} để tạo mã VietQR" });
        }

        return Ok(new
        {
            success = true,
            data = qrData
        });
    }

    /// <summary>
    /// POST /api/payment/create-vnpay-url
    /// Tạo URL cổng thanh toán VNPay Sandbox có chữ ký điện tử HMAC-SHA512
    /// </summary>
    [HttpPost("create-vnpay-url")]
    public IActionResult CreateVnpayUrl([FromBody] CreateVnpayRequest request)
    {
        if (request == null || request.OrderId <= 0 || request.Amount <= 0)
        {
            return BadRequest(new { success = false, message = "Thông tin đơn hàng thanh toán VNPay không hợp lệ" });
        }

        string clientIp = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "127.0.0.1";
        string paymentUrl = Provider.Payment.CreateVnpayUrl(
            request.OrderId,
            request.Amount,
            request.OrderInfo,
            clientIp,
            request.ReturnUrl
        );

        return Ok(new
        {
            success = true,
            orderId = request.OrderId,
            amount = request.Amount,
            paymentUrl = paymentUrl
        });
    }

    /// <summary>
    /// GET /api/payment/vnpay-return
    /// Điểm tiếp nhận kết quả thanh toán từ VNPay Sandbox
    /// </summary>
    [HttpGet("vnpay-return")]
    public IActionResult VnpayReturn([FromQuery] Dictionary<string, string> query)
    {
        string responseCode = query.ContainsKey("vnp_ResponseCode") ? query["vnp_ResponseCode"] : "99";
        string txnRef = query.ContainsKey("vnp_TxnRef") ? query["vnp_TxnRef"] : string.Empty;
        string amountStr = query.ContainsKey("vnp_Amount") ? query["vnp_Amount"] : "0";

        // Tách OrderId từ TxnRef (định dạng orderId_timestamp)
        int orderId = 0;
        if (!string.IsNullOrEmpty(txnRef))
        {
            string[] parts = txnRef.Split('_');
            int.TryParse(parts[0], out orderId);
        }

        decimal amount = 0;
        if (decimal.TryParse(amountStr, out decimal rawAmount))
        {
            amount = rawAmount / 100; // VNPay nhân 100
        }

        if (responseCode == "00" && orderId > 0)
        {
            // Giao dịch thành công
            Provider.Payment.ConfirmPayment(new ConfirmPaymentRequest
            {
                OrderId = orderId,
                PaymentMethod = "VNPay",
                Amount = amount,
                TransactionRef = txnRef,
                Note = "Thanh toán thành công qua cổng VNPay Sandbox"
            });

            return Ok(new
            {
                success = true,
                message = "Thanh toán qua VNPay thành công!",
                orderId = orderId,
                responseCode = responseCode
            });
        }

        return BadRequest(new
        {
            success = false,
            message = "Giao dịch VNPay không thành công hoặc đã bị hủy",
            responseCode = responseCode
        });
    }
}
