using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;

namespace WebApi.Models;

public class PaymentDto
{
    public int PaymentId { get; set; }
    public int OrderId { get; set; }
    public string OrderCode { get; set; } = string.Empty;
    public string PaymentMethod { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public string? TransactionRef { get; set; }
    public int Status { get; set; }
    public string StatusText => Status switch
    {
        1 => "Thành công",
        2 => "Thất bại",
        _ => "Chờ xử lý"
    };
    public string? Note { get; set; }
    public DateTime PaymentTime { get; set; }
}

public class VietQrResultDto
{
    public int OrderId { get; set; }
    public string OrderCode { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public string BankId { get; set; } = "vietinbank";
    public string BankName { get; set; } = "Ngân hàng TMCP Công Thương Việt Nam (VietinBank)";
    public string AccountNo { get; set; } = "102871234567";
    public string AccountName { get; set; } = "NHA HANG POS SYSTEM";
    public string TransferContent { get; set; } = string.Empty;
    public string Description => TransferContent;
    public string QrCodeUrl { get; set; } = string.Empty;
    public string QrImageUrl => QrCodeUrl;
}

public class PaymentRepository : BaseRepository
{
    public PaymentRepository(RestaurantPosContext context) : base(context) { }

    public async Task<(bool Success, string Message, PaymentDto? Payment)> ProcessCashPaymentAsync(int orderId, string? note = null)
    {
        return await ProcessPaymentAsync(orderId, "Cash", null, null, note);
    }

    public async Task<(bool Success, string Message, PaymentDto? Payment)> ProcessPaymentAsync(
        int orderId,
        string paymentMethod,
        decimal? amount = null,
        string? transactionRef = null,
        string? note = null)
    {
        var order = await context.Orders.FindAsync(orderId);
        if (order == null)
        {
            return (false, "Không tìm thấy đơn hàng", null);
        }

        if (order.PaymentStatus == 1)
        {
            return (false, "Đơn hàng này đã được thanh toán trước đó", null);
        }

        string method = string.IsNullOrWhiteSpace(paymentMethod) ? "Cash" : paymentMethod.Trim();
        decimal payAmount = (amount.HasValue && amount.Value > 0) ? amount.Value : order.FinalAmount;
        string txnRef = !string.IsNullOrWhiteSpace(transactionRef)
            ? transactionRef.Trim()
            : $"{method.ToUpper()}-{DateTime.Now:yyyyMMddHHmmss}-{order.OrderId}";

        var payment = new Payment
        {
            OrderId = orderId,
            PaymentMethod = method,
            Amount = payAmount,
            TransactionRef = txnRef,
            Status = 1, // Success
            Note = string.IsNullOrWhiteSpace(note) ? $"Thanh toán đơn hàng {order.OrderCode}" : note.Trim(),
            PaymentTime = DateTime.Now
        };

        context.Payments.Add(payment);

        order.PaymentStatus = 1; // Paid
        order.Status = 3; // Completed
        order.CompletedAt = DateTime.Now;
        context.Orders.Update(order);

        // Release dining table
        if (order.TableId.HasValue)
        {
            var table = await context.DiningTables.FindAsync(order.TableId.Value);
            if (table != null && table.CurrentOrderId == order.OrderId)
            {
                table.Status = 0; // Empty
                table.CurrentOrderId = null;
                table.UpdatedAt = DateTime.Now;
                context.DiningTables.Update(table);
            }
        }

        await context.SaveChangesAsync();

        var dto = new PaymentDto
        {
            PaymentId = payment.PaymentId,
            OrderId = payment.OrderId,
            OrderCode = order.OrderCode,
            PaymentMethod = payment.PaymentMethod,
            Amount = payment.Amount,
            TransactionRef = payment.TransactionRef,
            Status = payment.Status,
            Note = payment.Note,
            PaymentTime = payment.PaymentTime
        };

        return (true, "Xác nhận thanh toán thành công", dto);
    }

    public async Task<(bool Success, string Message, VietQrResultDto? QrResult)> GenerateVietQrAsync(int orderId)
    {
        var order = await context.Orders.FindAsync(orderId);
        if (order == null)
        {
            return (false, "Không tìm thấy đơn hàng", null);
        }

        string bankId = "vietinbank";
        string accountNo = "102871234567";
        string accountName = "NHA HANG POS SYSTEM";
        string transferContent = order.OrderCode;
        long amountInt = (long)order.FinalAmount;

        string qrUrl = $"https://img.vietqr.io/image/{bankId}-{accountNo}-compact2.png?amount={amountInt}&addInfo={Uri.EscapeDataString(transferContent)}&accountName={Uri.EscapeDataString(accountName)}";

        var result = new VietQrResultDto
        {
            OrderId = order.OrderId,
            OrderCode = order.OrderCode,
            Amount = order.FinalAmount,
            BankId = bankId,
            AccountNo = accountNo,
            AccountName = accountName,
            TransferContent = transferContent,
            QrCodeUrl = qrUrl
        };

        return (true, "Tạo thông tin VietQR thành công", result);
    }

    public async Task<(bool Success, string Message, string? PaymentUrl)> GenerateVnPayUrlAsync(
        int orderId,
        string tmnCode,
        string hashSecret,
        string vnpUrl,
        string returnUrl,
        string clientIp,
        string? orderInfo = null)
    {
        var order = await context.Orders.FindAsync(orderId);
        if (order == null)
        {
            return (false, "Không tìm thấy đơn hàng", null);
        }

        if (order.PaymentStatus == 1)
        {
            return (false, "Đơn hàng này đã được thanh toán trước đó", null);
        }

        string vnp_Version = "2.1.0";
        string vnp_Command = "pay";
        string vnp_CreateDate = DateTime.Now.ToString("yyyyMMddHHmmss");
        string vnp_CurrCode = "VND";
        string vnp_Locale = "vn";
        string vnp_OrderType = "other";
        string vnp_TxnRef = $"{order.OrderId}_{DateTime.Now.Ticks}";
        long vnp_Amount = (long)(order.FinalAmount * 100); // VNPay expects amount multiplied by 100
        string vnp_OrderInfo = string.IsNullOrWhiteSpace(orderInfo) ? $"Thanh toan don hang {order.OrderCode}" : orderInfo.Trim();

        var vnp_Params = new SortedDictionary<string, string>
        {
            { "vnp_Version", vnp_Version },
            { "vnp_Command", vnp_Command },
            { "vnp_TmnCode", tmnCode },
            { "vnp_Amount", vnp_Amount.ToString() },
            { "vnp_CreateDate", vnp_CreateDate },
            { "vnp_CurrCode", vnp_CurrCode },
            { "vnp_IpAddr", clientIp },
            { "vnp_Locale", vnp_Locale },
            { "vnp_OrderInfo", vnp_OrderInfo },
            { "vnp_OrderType", vnp_OrderType },
            { "vnp_ReturnUrl", returnUrl },
            { "vnp_TxnRef", vnp_TxnRef }
        };

        var queryBuilder = new StringBuilder();
        var hashDataBuilder = new StringBuilder();

        foreach (var kv in vnp_Params)
        {
            if (!string.IsNullOrEmpty(kv.Value))
            {
                if (hashDataBuilder.Length > 0) hashDataBuilder.Append('&');
                hashDataBuilder.Append(Uri.EscapeDataString(kv.Key)).Append('=').Append(Uri.EscapeDataString(kv.Value));

                if (queryBuilder.Length > 0) queryBuilder.Append('&');
                queryBuilder.Append(Uri.EscapeDataString(kv.Key)).Append('=').Append(Uri.EscapeDataString(kv.Value));
            }
        }

        string rawHashData = hashDataBuilder.ToString();
        string secureHash = HmacSha512(hashSecret, rawHashData);
        string finalUrl = $"{vnpUrl}?{queryBuilder}&vnp_SecureHash={secureHash}";

        return (true, "Tạo liên kết thanh toán VNPay thành công", finalUrl);
    }

    public async Task<(bool Success, string Message, int? OrderId)> ProcessVnPayCallbackAsync(
        IDictionary<string, string> queryParams,
        string hashSecret)
    {
        if (!queryParams.TryGetValue("vnp_SecureHash", out var receivedHash) || string.IsNullOrEmpty(receivedHash))
        {
            return (false, "Thiếu chữ ký bảo mật VNPay", null);
        }

        var sortedParams = new SortedDictionary<string, string>();
        foreach (var kv in queryParams)
        {
            if (!string.IsNullOrEmpty(kv.Key) &&
                !kv.Key.Equals("vnp_SecureHash", StringComparison.OrdinalIgnoreCase) &&
                !kv.Key.Equals("vnp_SecureHashType", StringComparison.OrdinalIgnoreCase))
            {
                sortedParams.Add(kv.Key, kv.Value);
            }
        }

        var hashDataBuilder = new StringBuilder();
        foreach (var kv in sortedParams)
        {
            if (!string.IsNullOrEmpty(kv.Value))
            {
                if (hashDataBuilder.Length > 0) hashDataBuilder.Append('&');
                hashDataBuilder.Append(Uri.EscapeDataString(kv.Key)).Append('=').Append(Uri.EscapeDataString(kv.Value));
            }
        }

        string calculatedHash = HmacSha512(hashSecret, hashDataBuilder.ToString());
        if (!calculatedHash.Equals(receivedHash, StringComparison.OrdinalIgnoreCase))
        {
            return (false, "Chữ ký bảo mật VNPay không khớp (Invalid Signature)", null);
        }

        if (!queryParams.TryGetValue("vnp_ResponseCode", out var responseCode) || responseCode != "00")
        {
            return (false, $"Giao dịch VNPay không thành công (ResponseCode: {responseCode})", null);
        }

        if (!queryParams.TryGetValue("vnp_TxnRef", out var txnRef) || string.IsNullOrEmpty(txnRef))
        {
            return (false, "Mã tham chiếu giao dịch vnp_TxnRef rỗng", null);
        }

        int orderId = int.Parse(txnRef.Split('_')[0]);
        var order = await context.Orders.FindAsync(orderId);
        if (order == null)
        {
            return (false, "Không tìm thấy đơn hàng", null);
        }

        if (order.PaymentStatus == 1)
        {
            // Already settled
            return (true, "Đơn hàng đã được thanh toán trước đó (Idempotent)", orderId);
        }

        decimal paidAmount = 0;
        if (queryParams.TryGetValue("vnp_Amount", out var amtStr) && long.TryParse(amtStr, out var rawAmt))
        {
            paidAmount = rawAmt / 100m;
        }

        var payment = new Payment
        {
            OrderId = orderId,
            PaymentMethod = "VNPay",
            Amount = paidAmount > 0 ? paidAmount : order.FinalAmount,
            TransactionRef = queryParams.TryGetValue("vnp_TransactionNo", out var vnpTxn) ? vnpTxn : txnRef,
            Status = 1,
            Note = "Thanh toán qua cổng VNPay Sandbox",
            PaymentTime = DateTime.Now
        };

        context.Payments.Add(payment);

        order.PaymentStatus = 1;
        order.Status = 3; // Completed
        order.CompletedAt = DateTime.Now;
        context.Orders.Update(order);

        if (order.TableId.HasValue)
        {
            var table = await context.DiningTables.FindAsync(order.TableId.Value);
            if (table != null && table.CurrentOrderId == order.OrderId)
            {
                table.Status = 0;
                table.CurrentOrderId = null;
                table.UpdatedAt = DateTime.Now;
                context.DiningTables.Update(table);
            }
        }

        await context.SaveChangesAsync();
        return (true, "Xác thực và ghi nhận thanh toán VNPay thành công", orderId);
    }

    private static string HmacSha512(string key, string inputData)
    {
        var hash = new StringBuilder();
        byte[] keyBytes = Encoding.UTF8.GetBytes(key);
        byte[] inputBytes = Encoding.UTF8.GetBytes(inputData);
        using (var hmac = new HMACSHA512(keyBytes))
        {
            byte[] hashValue = hmac.ComputeHash(inputBytes);
            foreach (var theByte in hashValue)
            {
                hash.Append(theByte.ToString("x2"));
            }
        }
        return hash.ToString();
    }
}
