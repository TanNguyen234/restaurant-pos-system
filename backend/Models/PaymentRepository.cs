using System.Net;
using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;

namespace WebApi.Models;

public class PaymentRepository : BaseRepository
{
    // Cấu hình ngân hàng mặc định cho mã VietQR NAPAS 247
    public const string DefaultBankId = "MB"; // MBBank (Ngân hàng Quân Đội)
    public const string DefaultBankName = "MB Bank (Ngân hàng TMCP Quân Đội)";
    public const string DefaultAccountNo = "0901234567";
    public const string DefaultAccountName = "NHA HANG RESTAURANT POS";

    // Cấu hình Cổng thanh toán VNPay Sandbox
    public const string VnpayUrl = "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html";
    public const string VnpayTmnCode = "RESTAUR1";
    public const string VnpayHashSecret = "VNPAYSECRETKEY20261020RESTAURANT";

    public PaymentRepository(RestaurantPosContext context) : base(context) { }

    /// <summary>
    /// Xác nhận thanh toán hóa đơn bằng Tiền mặt, VietQR hoặc VNPay.
    /// Tự động cập nhật trạng thái đơn (PaymentStatus = 1, Status = 3: Hoàn thành)
    /// và giải phóng bàn ăn về trạng thái 0 (Bàn trống).
    /// </summary>
    public (bool Success, string Message, Payment? Payment) ConfirmPayment(ConfirmPaymentRequest request)
    {
        if (request == null || request.OrderId <= 0)
        {
            return (false, "Thông tin đơn hàng thanh toán không hợp lệ", null);
        }

        var order = context.Orders.Find(request.OrderId);
        if (order == null)
        {
            return (false, $"Không tìm thấy đơn hàng #{request.OrderId}", null);
        }

        using var transaction = context.Database.BeginTransaction();
        try
        {
            decimal payAmount = request.Amount > 0 ? request.Amount : (order.FinalAmount > 0 ? order.FinalAmount : order.TotalAmount);
            string method = string.IsNullOrWhiteSpace(request.PaymentMethod) ? "Cash" : request.PaymentMethod.Trim();
            string txnRef = !string.IsNullOrWhiteSpace(request.TransactionRef)
                ? request.TransactionRef.Trim()
                : $"{method.ToUpper()}-{DateTime.Now:yyyyMMddHHmmss}-{order.OrderId}";

            var payment = new Payment
            {
                OrderId = order.OrderId,
                PaymentMethod = method,
                Amount = payAmount,
                TransactionRef = txnRef,
                Status = 1, // 1: Thành công
                Note = request.Note?.Trim() ?? $"Thanh toán thành công đơn {order.OrderCode}",
                PaymentTime = DateTime.Now
            };

            context.Payments.Add(payment);

            // Cập nhật đơn hàng: Đã thanh toán (1) và Hoàn thành (3)
            order.PaymentStatus = 1;
            order.Status = 3;
            order.CompletedAt = DateTime.Now;

            // Nếu đơn gắn với bàn ăn, giải phóng bàn về trạng thái Trống (0)
            if (order.TableId.HasValue)
            {
                var table = context.DiningTables.Find(order.TableId.Value);
                if (table != null)
                {
                    table.Status = 0; // Trống
                    table.CurrentOrderId = null;
                    table.UpdatedAt = DateTime.Now;
                }
            }

            context.SaveChanges();
            transaction.Commit();

            return (true, $"Xác nhận thanh toán đơn {order.OrderCode} thành công bằng {method}!", payment);
        }
        catch (Exception ex)
        {
            transaction.Rollback();
            return (false, $"Lỗi xử lý xác nhận thanh toán: {ex.Message}", null);
        }
    }

    /// <summary>
    /// Sinh thông tin mã VietQR NAPAS 247 động theo đơn hàng
    /// </summary>
    public VietQrResponse? GenerateVietQr(int orderId)
    {
        var order = context.Orders.Find(orderId);
        if (order == null) return null;

        decimal amount = order.FinalAmount > 0 ? order.FinalAmount : order.TotalAmount;
        string description = $"THANH TOAN {order.OrderCode}";

        // URL chuẩn hóa của cổng VietQR QuickLink (NAPAS 247)
        // Cú pháp: https://img.vietqr.io/image/<BANK_ID>-<ACCOUNT_NO>-compact2.png?amount=<AMOUNT>&addInfo=<DESCRIPTION>&accountName=<ACCOUNT_NAME>
        string encodedDesc = Uri.EscapeDataString(description);
        string encodedName = Uri.EscapeDataString(DefaultAccountName);
        string qrImageUrl = $"https://img.vietqr.io/image/{DefaultBankId}-{DefaultAccountNo}-compact2.png?amount={(long)amount}&addInfo={encodedDesc}&accountName={encodedName}";

        return new VietQrResponse
        {
            OrderId = order.OrderId,
            OrderCode = order.OrderCode,
            BankId = DefaultBankId,
            BankName = DefaultBankName,
            AccountNo = DefaultAccountNo,
            AccountName = DefaultAccountName,
            Amount = amount,
            Description = description,
            QrImageUrl = qrImageUrl
        };
    }

    /// <summary>
    /// Tạo URL chuyển hướng sang cổng thanh toán VNPay Sandbox có chữ ký HMAC-SHA512
    /// </summary>
    public string CreateVnpayUrl(int orderId, decimal amount, string? orderInfo, string? clientIp, string? returnUrl)
    {
        var order = context.Orders.Find(orderId);
        string orderCode = order != null ? order.OrderCode : $"ORD-{orderId}";
        string desc = string.IsNullOrWhiteSpace(orderInfo) ? $"Thanh toan don hang {orderCode}" : orderInfo;

        var vnpayParams = new SortedDictionary<string, string>
        {
            { "vnp_Version", "2.1.0" },
            { "vnp_Command", "pay" },
            { "vnp_TmnCode", VnpayTmnCode },
            { "vnp_Amount", ((long)(amount * 100)).ToString() }, // VNPay quy định nhân 100
            { "vnp_CreateDate", DateTime.Now.ToString("yyyyMMddHHmmss") },
            { "vnp_CurrCode", "VND" },
            { "vnp_IpAddr", string.IsNullOrWhiteSpace(clientIp) ? "127.0.0.1" : clientIp },
            { "vnp_Locale", "vn" },
            { "vnp_OrderInfo", desc },
            { "vnp_OrderType", "other" },
            { "vnp_ReturnUrl", returnUrl ?? "http://localhost:5138/api/payment/vnpay-return" },
            { "vnp_TxnRef", $"{orderId}_{DateTime.Now.Ticks}" }
        };

        // Ghép chuỗi query để ký
        var queryBuilder = new StringBuilder();
        var dataSignBuilder = new StringBuilder();

        foreach (var kv in vnpayParams)
        {
            if (!string.IsNullOrEmpty(kv.Value))
            {
                if (dataSignBuilder.Length > 0)
                {
                    dataSignBuilder.Append('&');
                    queryBuilder.Append('&');
                }
                dataSignBuilder.Append(WebUtility.UrlEncode(kv.Key) + "=" + WebUtility.UrlEncode(kv.Value));
                queryBuilder.Append(WebUtility.UrlEncode(kv.Key) + "=" + WebUtility.UrlEncode(kv.Value));
            }
        }

        string secureHash = HmacSha512(VnpayHashSecret, dataSignBuilder.ToString());
        queryBuilder.Append("&vnp_SecureHash=" + secureHash);

        return $"{VnpayUrl}?{queryBuilder}";
    }

    /// <summary>
    /// Lấy lịch sử giao dịch thanh toán của đơn hàng
    /// </summary>
    public List<Payment> GetPaymentsByOrderId(int orderId)
    {
        return context.Payments
            .Where(p => p.OrderId == orderId)
            .OrderByDescending(p => p.PaymentId)
            .ToList();
    }

    private static string HmacSha512(string key, string inputData)
    {
        byte[] keyBytes = Encoding.UTF8.GetBytes(key);
        byte[] inputBytes = Encoding.UTF8.GetBytes(inputData);
        using var hmac = new HMACSHA512(keyBytes);
        byte[] hashValue = hmac.ComputeHash(inputBytes);
        return Convert.ToHexString(hashValue).ToLowerInvariant();
    }
}

public class ConfirmPaymentRequest
{
    public int OrderId { get; set; }
    public string PaymentMethod { get; set; } = "Cash"; // 'Cash', 'VietQR', 'VNPay'
    public decimal Amount { get; set; }
    public string? TransactionRef { get; set; }
    public string? Note { get; set; }
}

public class VietQrResponse
{
    public int OrderId { get; set; }
    public string OrderCode { get; set; } = string.Empty;
    public string BankId { get; set; } = string.Empty;
    public string BankName { get; set; } = string.Empty;
    public string AccountNo { get; set; } = string.Empty;
    public string AccountName { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public string Description { get; set; } = string.Empty;
    public string QrImageUrl { get; set; } = string.Empty;
}

public class CreateVnpayRequest
{
    public int OrderId { get; set; }
    public decimal Amount { get; set; }
    public string? OrderInfo { get; set; }
    public string? ReturnUrl { get; set; }
}
