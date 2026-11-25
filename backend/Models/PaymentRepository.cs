using System.Net;
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
    public decimal TotalPaid { get; set; }
    public decimal RemainingAmount { get; set; }
    public bool IsFullyPaid { get; set; }
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

    public async Task<(bool Success, string Message, PaymentDto? Payment)> ProcessCashPaymentAsync(
        int orderId,
        string? note = null,
        int? cashierAccountId = null)
    {
        return await ProcessPaymentAsync(orderId, "Cash", null, null, note, cashierAccountId);
    }

    public async Task<(bool Success, string Message, PaymentDto? Payment)> ProcessPaymentAsync(
        int orderId,
        string paymentMethod,
        decimal? amount = null,
        string? transactionRef = null,
        string? note = null,
        int? processedByAccountId = null)
    {
        using var tx = await context.Database.BeginTransactionAsync();
        try
        {
            var order = await context.Orders.FindAsync(orderId);
            if (order == null) return (false, "Không tìm thấy đơn hàng", null);
            if (order.Status == 4) return (false, "Không thể thanh toán đơn hàng đã bị hủy", null);
            if (order.PaymentStatus == 1) return (false, "Đơn hàng này đã được thanh toán trước đó", null);

            decimal alreadyPaid = await context.Payments
                .Where(p => p.OrderId == orderId && p.Status == 1)
                .SumAsync(p => (decimal?)p.Amount) ?? 0;

            decimal remaining = Math.Max(0, order.FinalAmount - alreadyPaid);
            decimal payAmount = amount.HasValue ? amount.Value : remaining;

            if (order.FinalAmount == 0 && remaining == 0)
            {
                payAmount = 0;
            }
            else
            {
                if (payAmount <= 0) return (false, "Số tiền thanh toán phải lớn hơn 0", null);
                if (payAmount > remaining)
                {
                    return (false, $"Số tiền thanh toán ({payAmount:N0}đ) vượt quá số tiền còn lại ({remaining:N0}đ)", null);
                }
            }

            string method = string.IsNullOrWhiteSpace(paymentMethod) ? "Cash" : paymentMethod.Trim();
            string txnRef = !string.IsNullOrWhiteSpace(transactionRef)
                ? transactionRef.Trim()
                : $"{method.ToUpper()}-{DateTime.Now:yyyyMMddHHmmss}-{order.OrderId}";

            int? activeShiftId = null;
            if (processedByAccountId.HasValue)
            {
                var openShift = await context.Shifts
                    .Where(s => s.AccountId == processedByAccountId.Value && s.Status == 1)
                    .OrderByDescending(s => s.StartTime)
                    .FirstOrDefaultAsync();
                activeShiftId = openShift?.ShiftId;
            }

            var payment = new Payment
            {
                OrderId = orderId,
                ShiftId = activeShiftId,
                ProcessedByAccountId = processedByAccountId,
                PaymentMethod = method,
                Amount = payAmount,
                TransactionRef = txnRef,
                Status = 1,
                Note = string.IsNullOrWhiteSpace(note) ? $"Thanh toán đơn hàng {order.OrderCode}" : note.Trim(),
                PaymentTime = DateTime.Now
            };

            context.Payments.Add(payment);
            decimal newTotalPaid = alreadyPaid + payAmount;
            decimal newRemaining = Math.Max(0, order.FinalAmount - newTotalPaid);
            bool isFullyPaid = newTotalPaid >= order.FinalAmount;

            if (isFullyPaid)
            {
                order.PaymentStatus = 1;
                order.Status = 3; // Completed
                order.CompletedAt = DateTime.Now;
                context.Orders.Update(order);

                if (order.TableId.HasValue)
                {
                    var table = await context.DiningTables.FindAsync(order.TableId.Value);
                    if (table != null && (table.CurrentOrderId == order.OrderId ||
                        !await context.Orders.AnyAsync(o => o.TableId == table.TableId && o.OrderId != order.OrderId && o.Status < 3 && o.PaymentStatus == 0)))
                    {
                        table.Status = 0;
                        table.CurrentOrderId = null;
                        table.UpdatedAt = DateTime.Now;
                        context.DiningTables.Update(table);
                    }
                }

                await AwardLoyaltyPointsIfMemberAsync(order);
            }

            await context.SaveChangesAsync();
            await tx.CommitAsync();

            return (true,
                isFullyPaid
                    ? "Xác nhận thanh toán hoàn tất đơn hàng thành công"
                    : $"Đã ghi nhận thanh toán phần {payAmount:N0}đ. Còn lại: {newRemaining:N0}đ",
                new PaymentDto
                {
                    PaymentId = payment.PaymentId,
                    OrderId = payment.OrderId,
                    OrderCode = order.OrderCode,
                    PaymentMethod = payment.PaymentMethod,
                    Amount = payment.Amount,
                    TotalPaid = newTotalPaid,
                    RemainingAmount = newRemaining,
                    IsFullyPaid = isFullyPaid,
                    TransactionRef = payment.TransactionRef,
                    Status = payment.Status,
                    Note = payment.Note,
                    PaymentTime = payment.PaymentTime
                });
        }
        catch (Exception)
        {
            await tx.RollbackAsync();
            return (false, "Lỗi ghi nhận giao dịch thanh toán", null);
        }
    }

    private async Task AwardLoyaltyPointsIfMemberAsync(Order order)
    {
        if (!order.AccountId.HasValue || order.FinalAmount < 1000) return;

        var account = await context.Accounts.FindAsync(order.AccountId.Value);
        if (account == null) return;

        var role = await context.Roles.FindAsync(account.RoleId);
        if (role == null || (role.RoleCode != "MEMBER" && role.RoleCode != "VIP_MEMBER")) return;

        int earnedPoints = (int)Math.Floor(order.FinalAmount / 1000m);
        if (earnedPoints <= 0) return;

        account.LoyaltyPoints += earnedPoints;
        account.UpdatedAt = DateTime.Now;
        context.LoyaltyTransactions.Add(new LoyaltyTransaction
        {
            AccountId = account.AccountId,
            OrderId = order.OrderId,
            PointsDelta = earnedPoints,
            Type = "EARN",
            Description = $"Tích điểm từ đơn hàng #{order.OrderCode} ({order.FinalAmount:N0}đ)",
            CreatedAt = DateTime.Now
        });
    }

    public async Task<(bool Success, string Message, VietQrResultDto? QrResult)> GenerateVietQrAsync(
        int orderId,
        IConfiguration? config = null,
        decimal? customAmount = null)
    {
        var order = await context.Orders.FindAsync(orderId);
        if (order == null) return (false, "Không tìm thấy đơn hàng", null);
        if (order.Status == 4) return (false, "Đơn hàng đã bị hủy, không thể tạo mã VietQR", null);
        if (order.PaymentStatus == 1) return (false, "Đơn hàng này đã thanh toán hoàn tất", null);

        decimal alreadyPaid = await context.Payments
            .Where(p => p.OrderId == orderId && p.Status == 1)
            .SumAsync(p => (decimal?)p.Amount) ?? 0;

        decimal remaining = Math.Max(0, order.FinalAmount - alreadyPaid);
        decimal qrAmount = customAmount.HasValue ? customAmount.Value : remaining;
        if (qrAmount <= 0 || qrAmount > remaining)
        {
            return (false, $"Số tiền tạo mã QR không hợp lệ (còn phải thu: {remaining:N0}đ)", null);
        }

        string bankId = config?["VietQR:BankId"] ?? config?["VIETQR_BANK_ID"] ?? Environment.GetEnvironmentVariable("VIETQR_BANK_ID") ?? "vietinbank";
        string accountNo = config?["VietQR:AccountNo"] ?? config?["VIETQR_ACCOUNT_NO"] ?? Environment.GetEnvironmentVariable("VIETQR_ACCOUNT_NO") ?? "102871234567";
        string accountName = config?["VietQR:AccountName"] ?? config?["VIETQR_ACCOUNT_NAME"] ?? Environment.GetEnvironmentVariable("VIETQR_ACCOUNT_NAME") ?? "NHA HANG BISTRO POS";
        string transferContent = order.OrderCode;
        long amountInt = (long)Math.Round(qrAmount, 0);

        string qrUrl = $"https://img.vietqr.io/image/{bankId}-{accountNo}-compact2.png?amount={amountInt}&addInfo={Uri.EscapeDataString(transferContent)}&accountName={Uri.EscapeDataString(accountName)}";

        var result = new VietQrResultDto
        {
            OrderId = order.OrderId,
            OrderCode = order.OrderCode,
            Amount = qrAmount,
            BankId = bankId,
            BankName = bankId.Equals("vietinbank", StringComparison.OrdinalIgnoreCase)
                ? "Ngân hàng TMCP Công Thương Việt Nam (VietinBank)"
                : bankId.ToUpperInvariant(),
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
        if (order == null) return (false, "Không tìm thấy đơn hàng", null);
        if (order.Status == 4) return (false, "Đơn hàng đã bị hủy", null);
        if (order.PaymentStatus == 1) return (false, "Đơn hàng này đã được thanh toán trước đó", null);
        if (order.FinalAmount <= 0) return (false, "Giá trị đơn hàng phải lớn hơn 0đ để thanh toán qua VNPay", null);

        string normalizedIp = string.IsNullOrWhiteSpace(clientIp) || clientIp == "::1" ? "127.0.0.1" : clientIp;

        string vnp_TxnRef = $"{order.OrderId}_{DateTime.Now.Ticks}";
        long vnp_Amount = (long)(order.FinalAmount * 100);
        string vnp_OrderInfo = string.IsNullOrWhiteSpace(orderInfo)
            ? $"Thanh toan don hang {order.OrderCode}"
            : orderInfo.Trim();

        var vnp_Params = new SortedDictionary<string, string>(StringComparer.Ordinal)
        {
            { "vnp_Version", "2.1.0" },
            { "vnp_Command", "pay" },
            { "vnp_TmnCode", tmnCode },
            { "vnp_Amount", vnp_Amount.ToString() },
            { "vnp_CreateDate", DateTime.Now.ToString("yyyyMMddHHmmss") },
            { "vnp_CurrCode", "VND" },
            { "vnp_IpAddr", normalizedIp },
            { "vnp_Locale", "vn" },
            { "vnp_OrderInfo", vnp_OrderInfo },
            { "vnp_OrderType", "other" },
            { "vnp_ReturnUrl", returnUrl },
            { "vnp_TxnRef", vnp_TxnRef }
        };

        var dataBuilder = new StringBuilder();
        foreach (var kv in vnp_Params)
        {
            if (!string.IsNullOrEmpty(kv.Value))
            {
                if (dataBuilder.Length > 0) dataBuilder.Append('&');
                dataBuilder.Append(WebUtility.UrlEncode(kv.Key)).Append('=').Append(WebUtility.UrlEncode(kv.Value));
            }
        }

        string rawQuery = dataBuilder.ToString();
        string secureHash = HmacSha512(hashSecret, rawQuery);
        string finalUrl = $"{vnpUrl}?{rawQuery}&vnp_SecureHash={secureHash}";

        return (true, "Tạo liên kết thanh toán VNPay Sandbox thành công", finalUrl);
    }

    public async Task<(bool Success, string Message, int? OrderId)> ProcessVnPayCallbackAsync(
        IDictionary<string, string> queryParams,
        string hashSecret,
        string? expectedTmnCode = null)
    {
        if (!queryParams.TryGetValue("vnp_SecureHash", out var receivedHash) || string.IsNullOrWhiteSpace(receivedHash))
            return (false, "Thiếu chữ ký bảo mật VNPay", null);

        var sortedParams = new SortedDictionary<string, string>(StringComparer.Ordinal);
        foreach (var kv in queryParams)
        {
            if (!string.IsNullOrEmpty(kv.Key) &&
                kv.Key.StartsWith("vnp_", StringComparison.OrdinalIgnoreCase) &&
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
                hashDataBuilder.Append(WebUtility.UrlEncode(kv.Key)).Append('=').Append(WebUtility.UrlEncode(kv.Value));
            }
        }

        string calculatedHash = HmacSha512(hashSecret, hashDataBuilder.ToString());
        byte[] expectedBytes = Encoding.ASCII.GetBytes(calculatedHash.ToLowerInvariant());
        byte[] receivedBytes = Encoding.ASCII.GetBytes(receivedHash.Trim().ToLowerInvariant());
        if (expectedBytes.Length != receivedBytes.Length || !CryptographicOperations.FixedTimeEquals(expectedBytes, receivedBytes))
        {
            return (false, "Chữ ký bảo mật VNPay không khớp (Invalid Signature)", null);
        }

        if (!string.IsNullOrWhiteSpace(expectedTmnCode) &&
            queryParams.TryGetValue("vnp_TmnCode", out var callbackTmn) &&
            !string.Equals(callbackTmn, expectedTmnCode, StringComparison.OrdinalIgnoreCase))
        {
            return (false, "Mã website vnp_TmnCode không khớp", null);
        }

        int? parsedOrderId = null;
        if (queryParams.TryGetValue("vnp_TxnRef", out var txnRef) && !string.IsNullOrEmpty(txnRef) &&
            int.TryParse(txnRef.Split('_')[0], out int oid) && oid > 0)
        {
            parsedOrderId = oid;
        }

        if (!queryParams.TryGetValue("vnp_ResponseCode", out var responseCode) || responseCode != "00")
        {
            string msg = responseCode == "24"
                ? "Khách hàng đã hủy giao dịch thanh toán VNPay (Mã 24). Đơn hàng của bạn vẫn được giữ nguyên."
                : $"Giao dịch VNPay không thành công (ResponseCode: {responseCode})";
            return (false, msg, parsedOrderId);
        }

        if (queryParams.TryGetValue("vnp_TransactionStatus", out var txnStatus) && txnStatus != "00")
        {
            return (false, $"Trạng thái giao dịch VNPay chưa hoàn tất (TransactionStatus: {txnStatus})", parsedOrderId);
        }

        if (!parsedOrderId.HasValue)
        {
            return (false, "Mã tham chiếu giao dịch vnp_TxnRef rỗng hoặc không hợp lệ", null);
        }

        int orderId = parsedOrderId.Value;

        var order = await context.Orders.FindAsync(orderId);
        if (order == null) return (false, "Không tìm thấy đơn hàng", null);
        if (order.Status == 4) return (false, "Đơn hàng đã bị hủy, không thể ghi nhận thanh toán", orderId);
        if (order.PaymentStatus == 1) return (true, "Đơn hàng đã được thanh toán trước đó (Idempotent)", orderId);

        if (!queryParams.TryGetValue("vnp_Amount", out var amtStr) || !long.TryParse(amtStr, out var rawAmt))
        {
            return (false, "Thiếu thông tin số tiền vnp_Amount", orderId);
        }

        decimal paidAmount = rawAmt / 100m;
        if (paidAmount != order.FinalAmount)
        {
            return (false, $"Số tiền VNPay ({paidAmount:N0}đ) không khớp với giá trị đơn hàng ({order.FinalAmount:N0}đ)", orderId);
        }

        using var tx = await context.Database.BeginTransactionAsync();
        try
        {
            var payment = new Payment
            {
                OrderId = orderId,
                PaymentMethod = "VNPay",
                Amount = paidAmount,
                TransactionRef = queryParams.TryGetValue("vnp_TransactionNo", out var vnpTxn) && !string.IsNullOrWhiteSpace(vnpTxn) ? vnpTxn : txnRef,
                Status = 1,
                Note = "Thanh toán qua cổng VNPay Sandbox",
                PaymentTime = DateTime.Now
            };

            context.Payments.Add(payment);

            order.PaymentStatus = 1;
            order.Status = 3;
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

            await AwardLoyaltyPointsIfMemberAsync(order);
            await context.SaveChangesAsync();
            await tx.CommitAsync();

            return (true, "Xác thực và ghi nhận thanh toán VNPay thành công", orderId);
        }
        catch (Exception)
        {
            await tx.RollbackAsync();
            return (false, "Lỗi ghi nhận giao dịch VNPay", orderId);
        }
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
