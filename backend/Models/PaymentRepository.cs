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

    private async Task ReleaseTableOrPreserveReservationAsync(DiningTable table, int excludedOrderId)
    {
        bool hasOtherActive = await context.Orders.AnyAsync(o =>
            o.TableId == table.TableId &&
            o.OrderId != excludedOrderId &&
            o.Status < 3 &&
            o.PaymentStatus == 0);
        if (hasOtherActive) return;

        var now = DateTime.Now;
        var lockLimit = now.AddMinutes(TableRepository.PreArrivalLockMinutes);
        bool hasLockedReservation = await context.Reservations.AnyAsync(r =>
            r.TableId == table.TableId &&
            (r.Status == 0 || r.Status == 1) &&
            r.ArrivalTime <= lockLimit &&
            (r.ExpiresAt ?? r.ArrivalTime.AddMinutes(TableRepository.DefaultHoldGraceMinutes)) > now);

        table.Status = hasLockedReservation ? 3 : 0;
        table.CurrentOrderId = null;
        table.UpdatedAt = now;
        context.DiningTables.Update(table);
    }

    /// <summary>Tiền tố thông báo lỗi để controller nhận ra lỗi "còn món chưa giao" và trả mã lỗi UNSERVED_ITEMS.</summary>
    public const string UnservedMessagePrefix = "[CHUA_GIAO] ";

    /// <summary>
    /// Đếm số phần món còn hiệu lực của đơn mà phục vụ chưa xác nhận giao ra bàn
    /// (Waiting = chờ nấu / đang nấu, Ready = bếp đã xong chờ bưng). Món đã hủy không tính.
    /// </summary>
    public async Task<(int Waiting, int Ready)> CountUnservedAsync(int orderId)
    {
        var rows = await context.OrderDetails
            .Where(d => d.OrderId == orderId && d.CookingStatus != 3 && d.CookingStatus != 4)
            .Select(d => new { d.CookingStatus, d.Quantity })
            .ToListAsync();
        int waiting = rows.Where(r => r.CookingStatus < 2).Sum(r => r.Quantity);
        int ready = rows.Where(r => r.CookingStatus == 2).Sum(r => r.Quantity);
        return (waiting, ready);
    }

    public static string BuildUnservedMessage(int waiting, int ready)
    {
        var parts = new List<string>();
        if (waiting > 0) parts.Add($"{waiting} phần chờ nấu/đang nấu");
        if (ready > 0) parts.Add($"{ready} phần bếp đã xong chờ bưng");
        return $"{UnservedMessagePrefix}Còn {string.Join(" và ", parts)}. Phục vụ cần xác nhận đã giao món ra bàn trước khi thu tiền.";
    }

    public async Task<(bool Success, string Message, PaymentDto? Payment)> ProcessCashPaymentAsync(
        int orderId,
        string? note = null,
        int? cashierAccountId = null,
        bool allowUnserved = false)
    {
        return await ProcessPaymentAsync(orderId, "Cash", null, null, note, cashierAccountId, allowUnserved);
    }

    public async Task<(bool Success, string Message, PaymentDto? Payment)> ProcessPaymentAsync(
        int orderId,
        string paymentMethod,
        decimal? amount = null,
        string? transactionRef = null,
        string? note = null,
        int? processedByAccountId = null,
        bool allowUnserved = false)
    {
        using var tx = await context.Database.BeginTransactionAsync();
        try
        {
            var order = await context.Orders.FindAsync(orderId);
            if (order == null) return (false, "Không tìm thấy đơn hàng", null);
            if (order.Status == 4) return (false, "Không thể thanh toán đơn hàng đã bị hủy", null);
            if (order.PaymentStatus == 1) return (false, "Đơn hàng này đã được thanh toán trước đó", null);

            // Đơn tại bàn chỉ được thu tiền khi mọi món đã giao ra bàn (quản lý / admin có thể cho phép ngoại lệ)
            if (order.OrderType == 1 && !allowUnserved)
            {
                var unserved = await CountUnservedAsync(orderId);
                if (unserved.Waiting + unserved.Ready > 0)
                {
                    await tx.RollbackAsync();
                    return (false, BuildUnservedMessage(unserved.Waiting, unserved.Ready), null);
                }
            }

            decimal alreadyPaid = await context.Payments
                .Where(p => p.OrderId == orderId && p.Status == 1)
                .SumAsync(p => (decimal?)p.Amount) ?? 0;

            decimal remaining = Math.Max(0, order.FinalAmount - alreadyPaid);
            decimal payAmount = amount.HasValue ? amount.Value : remaining;

            if (remaining == 0)
            {
                // Đã đủ tiền (ví dụ: tiền cọc hoặc giảm 100%) -> chốt hoàn tất đơn không cần thu thêm
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

            Payment? createdPayment = null;
            if (payAmount > 0 || (order.FinalAmount == 0 && alreadyPaid == 0))
            {
                createdPayment = new Payment
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
                context.Payments.Add(createdPayment);
            }

            decimal newTotalPaid = alreadyPaid + payAmount;
            decimal newRemaining = Math.Max(0, order.FinalAmount - newTotalPaid);
            bool isFullyPaid = newTotalPaid >= order.FinalAmount;

            if (isFullyPaid)
            {
                order.PaymentStatus = 1;
                // Đơn mang về trả trước: giữ đơn mở (vẫn hiện trạng thái món) cho tới khi phục vụ giao hết món
                bool keepOpen = order.OrderType == 2 && !await OrderRepository.AllActiveItemsServedAsync(context, order.OrderId);
                if (!keepOpen)
                {
                    order.Status = 3; // Completed
                    order.CompletedAt = DateTime.Now;
                }
                context.Orders.Update(order);

                if (order.TableId.HasValue)
                {
                    var table = await context.DiningTables.FindAsync(order.TableId.Value);
                    if (table != null)
                    {
                        await ReleaseTableOrPreserveReservationAsync(table, order.OrderId);
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
                    PaymentId = createdPayment?.PaymentId ?? 0,
                    OrderId = orderId,
                    OrderCode = order.OrderCode,
                    PaymentMethod = createdPayment?.PaymentMethod ?? method,
                    Amount = payAmount,
                    TotalPaid = newTotalPaid,
                    RemainingAmount = newRemaining,
                    IsFullyPaid = isFullyPaid,
                    TransactionRef = createdPayment?.TransactionRef ?? txnRef,
                    Status = 1,
                    Note = createdPayment?.Note ?? note,
                    PaymentTime = createdPayment?.PaymentTime ?? DateTime.Now
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
        if (order.FinalAmount < 1000) return;

        // Tránh cộng điểm trùng nếu đã tích điểm cho đơn hàng này
        bool alreadyAwarded = await context.LoyaltyTransactions
            .AnyAsync(t => t.OrderId == order.OrderId && t.Type == "EARN");
        if (alreadyAwarded) return;

        Account? targetMember = null;
        if (order.AccountId.HasValue)
        {
            var acc = await context.Accounts.FindAsync(order.AccountId.Value);
            if (acc != null && acc.IsActive)
            {
                var role = await context.Roles.FindAsync(acc.RoleId);
                if (role != null && (role.RoleCode == "MEMBER" || role.RoleCode == "VIP_MEMBER"))
                {
                    targetMember = acc;
                }
            }
        }

        // Nếu đơn do Nhân viên/Thu ngân tạo tại quầy nhưng có SĐT của Hội viên -> tìm hội viên để cộng điểm
        if (targetMember == null && !string.IsNullOrWhiteSpace(order.PhoneNumber))
        {
            string phone = order.PhoneNumber.Trim();
            targetMember = await (
                from a in context.Accounts
                join r in context.Roles on a.RoleId equals r.RoleId
                where a.IsActive && a.PhoneNumber == phone && (r.RoleCode == "MEMBER" || r.RoleCode == "VIP_MEMBER")
                select a
            ).FirstOrDefaultAsync();
        }

        if (targetMember == null) return;

        int earnedPoints = (int)Math.Floor(order.FinalAmount / 1000m);
        if (earnedPoints <= 0) return;

        targetMember.LoyaltyPoints += earnedPoints;
        targetMember.UpdatedAt = DateTime.Now;
        context.LoyaltyTransactions.Add(new LoyaltyTransaction
        {
            AccountId = targetMember.AccountId,
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
        string? orderInfo = null,
        decimal? customAmount = null)
    {
        var order = await context.Orders.FindAsync(orderId);
        if (order == null) return (false, "Không tìm thấy đơn hàng", null);
        if (order.Status == 4) return (false, "Đơn hàng đã bị hủy", null);
        if (order.PaymentStatus == 1) return (false, "Đơn hàng này đã được thanh toán trước đó", null);

        decimal alreadyPaid = await context.Payments
            .Where(p => p.OrderId == orderId && p.Status == 1)
            .SumAsync(p => (decimal?)p.Amount) ?? 0;

        decimal remaining = Math.Max(0, order.FinalAmount - alreadyPaid);
        decimal payAmount = customAmount.HasValue ? customAmount.Value : remaining;
        if (payAmount <= 0 || payAmount > remaining)
        {
            return (false, $"Số tiền thanh toán VNPay không hợp lệ (còn phải thu: {remaining:N0}đ)", null);
        }

        string normalizedIp = string.IsNullOrWhiteSpace(clientIp) || clientIp == "::1" ? "127.0.0.1" : clientIp;

        string vnp_TxnRef = $"{order.OrderId}_{DateTime.Now.Ticks}";
        long vnp_Amount = (long)Math.Round(payAmount * 100m, 0);
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

        string resolvedTxnRef = queryParams.TryGetValue("vnp_TransactionNo", out var vnpTxn) && !string.IsNullOrWhiteSpace(vnpTxn)
            ? vnpTxn.Trim()
            : txnRef!;

        bool duplicateCallback = await context.Payments.AnyAsync(p =>
            p.OrderId == orderId && p.Status == 1 && p.TransactionRef == resolvedTxnRef);
        if (duplicateCallback || order.PaymentStatus == 1)
            return (true, "Đơn hàng đã được thanh toán trước đó (Idempotent)", orderId);

        if (!queryParams.TryGetValue("vnp_Amount", out var amtStr) || !long.TryParse(amtStr, out var rawAmt))
        {
            return (false, "Thiếu thông tin số tiền vnp_Amount", orderId);
        }

        decimal paidAmount = rawAmt / 100m;
        decimal alreadyPaid = await context.Payments
            .Where(p => p.OrderId == orderId && p.Status == 1)
            .SumAsync(p => (decimal?)p.Amount) ?? 0;
        decimal remaining = Math.Max(0, order.FinalAmount - alreadyPaid);

        if (paidAmount <= 0 || paidAmount > remaining)
        {
            return (false, $"Số tiền VNPay ({paidAmount:N0}đ) không khớp với số tiền còn phải thu ({remaining:N0}đ)", orderId);
        }

        using var tx = await context.Database.BeginTransactionAsync();
        try
        {
            // Gắn thanh toán VNPay cho tối đa 1 ca duy nhất đang mở để Z-Report không đếm trùng
            int? targetShiftId = null;
            int? targetShiftAccountId = null;
            if (order.AccountId.HasValue)
            {
                var orderShift = await context.Shifts
                    .Where(s => s.AccountId == order.AccountId.Value && s.Status == 1)
                    .OrderByDescending(s => s.StartTime)
                    .FirstOrDefaultAsync();
                if (orderShift != null)
                {
                    targetShiftId = orderShift.ShiftId;
                    targetShiftAccountId = orderShift.AccountId;
                }
            }
            if (!targetShiftId.HasValue)
            {
                var singleOpenShift = await context.Shifts
                    .Where(s => s.Status == 1)
                    .OrderBy(s => s.StartTime)
                    .FirstOrDefaultAsync();
                if (singleOpenShift != null)
                {
                    targetShiftId = singleOpenShift.ShiftId;
                    targetShiftAccountId = singleOpenShift.AccountId;
                }
            }

            var payment = new Payment
            {
                OrderId = orderId,
                ShiftId = targetShiftId,
                ProcessedByAccountId = targetShiftAccountId,
                PaymentMethod = "VNPay",
                Amount = paidAmount,
                TransactionRef = resolvedTxnRef,
                Status = 1,
                Note = "Thanh toán qua cổng VNPay Sandbox",
                PaymentTime = DateTime.Now
            };

            context.Payments.Add(payment);

            decimal totalPaid = alreadyPaid + paidAmount;
            if (totalPaid >= order.FinalAmount)
            {
                order.PaymentStatus = 1;
                bool keepOpen = order.OrderType == 2 && !await OrderRepository.AllActiveItemsServedAsync(context, order.OrderId);
                if (!keepOpen)
                {
                    order.Status = 3;
                    order.CompletedAt = DateTime.Now;
                }
                context.Orders.Update(order);

                if (order.TableId.HasValue)
                {
                    var table = await context.DiningTables.FindAsync(order.TableId.Value);
                    if (table != null)
                    {
                        await ReleaseTableOrPreserveReservationAsync(table, order.OrderId);
                    }
                }

                await AwardLoyaltyPointsIfMemberAsync(order);
            }

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
