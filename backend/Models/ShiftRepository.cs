using System.Text.Json;
using Microsoft.EntityFrameworkCore;

namespace WebApi.Models;

public class OpenShiftDto
{
    public int AccountId { get; set; }
    public decimal InitialCash { get; set; }
    public string? Note { get; set; }
}

public class CloseShiftDto
{
    public int ShiftId { get; set; }
    public decimal ActualCash { get; set; }
    public string? Note { get; set; }
}

public class CurrentShiftDto
{
    public int ShiftId { get; set; }
    public string ShiftCode => $"SHIFT-{ShiftId:D4}";
    public int AccountId { get; set; }
    public string StaffName { get; set; } = string.Empty;
    public DateTime StartTime { get; set; }
    public decimal InitialCash { get; set; }
    public decimal TotalCashSales { get; set; }
    public decimal TotalTransferSales { get; set; }
    public decimal TotalVnPaySales { get; set; }
    public decimal TotalRevenue => TotalCashSales + TotalTransferSales + TotalVnPaySales;
    public decimal ExpectedCash => InitialCash + TotalCashSales;
    public int TotalOrders { get; set; }
    public decimal TotalDiscount { get; set; }
    public int Status { get; set; }
    public string? Note { get; set; }
}

public class ZReportDto
{
    public int ShiftId { get; set; }
    public string ShiftCode => $"SHIFT-{ShiftId:D4}";
    public int AccountId { get; set; }
    public string CashierName { get; set; } = string.Empty;
    public DateTime StartTime { get; set; }
    public DateTime EndTime { get; set; }
    public decimal InitialCash { get; set; }
    public decimal TotalSalesCash { get; set; }
    public decimal TotalSalesVietQr { get; set; }
    public decimal TotalSalesVnPay { get; set; }
    public decimal TotalRevenue { get; set; }
    public decimal ExpectedCashInDrawer { get; set; }
    public decimal ActualCashInDrawer { get; set; }
    public decimal Discrepancy { get; set; }
    public int TotalCompletedOrders { get; set; }
    public string DiscrepancyNote => Discrepancy == 0 ? "Khớp két 100%" : (Discrepancy > 0 ? $"Dư tiền: +{Discrepancy:N0}đ" : $"Thiếu tiền: {Discrepancy:N0}đ");
}

public class ShiftRepository : BaseRepository
{
    public ShiftRepository(RestaurantPosContext context) : base(context) { }

    private async Task<List<Payment>> GetShiftPaymentsAsync(Shift shift, DateTime endTime)
    {
        return await context.Payments
            .Where(p => p.Status == 1 &&
                        (p.ShiftId == shift.ShiftId ||
                         (p.ShiftId == null && p.ProcessedByAccountId == shift.AccountId && p.PaymentTime >= shift.StartTime && p.PaymentTime <= endTime)))
            .ToListAsync();
    }

    private static (decimal Cash, decimal Transfer, decimal Card) SumByMethod(List<Payment> payments)
    {
        decimal cash = 0, transfer = 0, card = 0;
        foreach (var p in payments)
        {
            string m = p.PaymentMethod.Trim();
            if (m.Equals("Cash", StringComparison.OrdinalIgnoreCase)) cash += p.Amount;
            else if (m.Equals("VietQR", StringComparison.OrdinalIgnoreCase) ||
                     m.Equals("Transfer", StringComparison.OrdinalIgnoreCase) ||
                     m.Equals("Deposit", StringComparison.OrdinalIgnoreCase)) transfer += p.Amount;
            else card += p.Amount; // VNPay / Card / E-Wallet
        }
        return (cash, transfer, card);
    }

    public async Task<CurrentShiftDto?> GetCurrentShiftAsync(int? accountId = null)
    {
        var query = context.Shifts.Where(s => s.Status == 1);
        if (accountId.HasValue && accountId.Value > 0)
        {
            query = query.Where(s => s.AccountId == accountId.Value);
        }

        var shift = await query.OrderByDescending(s => s.StartTime).FirstOrDefaultAsync();
        if (shift == null) return null;

        var now = DateTime.Now;
        var payments = await GetShiftPaymentsAsync(shift, now);
        var (cash, transfer, vnpay) = SumByMethod(payments);
        var orderIds = payments.Select(p => p.OrderId).Distinct().ToList();
        decimal totalDiscount = orderIds.Count > 0
            ? await context.Orders.Where(o => orderIds.Contains(o.OrderId)).SumAsync(o => (decimal?)o.DiscountAmount) ?? 0
            : 0;
        var staff = await context.Accounts.FindAsync(shift.AccountId);

        return new CurrentShiftDto
        {
            ShiftId = shift.ShiftId,
            AccountId = shift.AccountId,
            StaffName = staff?.FullName ?? $"Nhân viên #{shift.AccountId}",
            StartTime = shift.StartTime,
            InitialCash = shift.InitialCash,
            TotalCashSales = cash,
            TotalTransferSales = transfer,
            TotalVnPaySales = vnpay,
            TotalOrders = orderIds.Count,
            TotalDiscount = totalDiscount,
            Status = shift.Status,
            Note = shift.Note
        };
    }

    public async Task<(bool Success, string Message, Shift? Shift)> OpenShiftAsync(OpenShiftDto dto)
    {
        var account = await context.Accounts.FindAsync(dto.AccountId);
        if (account == null || !account.IsActive)
        {
            return (false, "Tài khoản nhân viên không hợp lệ hoặc đã bị khóa", null);
        }

        var existing = await context.Shifts
            .FirstOrDefaultAsync(s => s.AccountId == dto.AccountId && s.Status == 1);

        if (existing != null)
        {
            return (false, "Nhân viên hiện đang có một ca làm việc đang mở. Vui lòng đóng ca trước khi mở ca mới.", existing);
        }

        var shift = new Shift
        {
            AccountId = dto.AccountId,
            StartTime = DateTime.Now,
            InitialCash = dto.InitialCash,
            Status = 1,
            Note = dto.Note?.Trim()
        };

        context.Shifts.Add(shift);
        await context.SaveChangesAsync();

        return (true, $"Mở ca làm việc thành công với số tiền lẻ đầu ca: {dto.InitialCash:N0}đ", shift);
    }

    public async Task<(bool Success, string Message, ZReportDto? Report)> CloseShiftAsync(
        CloseShiftDto dto,
        int callerAccountId,
        bool isAdminOrManager)
    {
        var shift = await context.Shifts.FindAsync(dto.ShiftId);
        if (shift == null) return (false, "Không tìm thấy thông tin ca làm việc cần đóng", null);
        if (!isAdminOrManager && shift.AccountId != callerAccountId)
            return (false, "Bạn chỉ có quyền đóng ca làm việc của chính mình", null);
        if (shift.Status == 2) return (false, "Ca làm việc này đã được đóng trước đó", null);

        var endTime = DateTime.Now;
        shift.EndTime = endTime;

        var payments = await GetShiftPaymentsAsync(shift, endTime);
        var (cashSales, vietQrSales, vnPaySales) = SumByMethod(payments);
        decimal totalRevenue = cashSales + vietQrSales + vnPaySales;

        decimal expectedCash = shift.InitialCash + cashSales;
        decimal discrepancy = dto.ActualCash - expectedCash;

        shift.TotalCash = cashSales;
        shift.TotalTransfer = vietQrSales;
        shift.TotalCard = vnPaySales;
        shift.Discrepancy = discrepancy;
        shift.Status = 2;
        if (!string.IsNullOrWhiteSpace(dto.Note))
        {
            shift.Note = string.IsNullOrWhiteSpace(shift.Note) ? dto.Note.Trim() : $"{shift.Note} | Đóng ca: {dto.Note.Trim()}";
        }

        var cashier = await context.Accounts.FindAsync(shift.AccountId);

        var report = new ZReportDto
        {
            ShiftId = shift.ShiftId,
            AccountId = shift.AccountId,
            CashierName = cashier?.FullName ?? $"Tài khoản #{shift.AccountId}",
            StartTime = shift.StartTime,
            EndTime = endTime,
            InitialCash = shift.InitialCash,
            TotalSalesCash = cashSales,
            TotalSalesVietQr = vietQrSales,
            TotalSalesVnPay = vnPaySales,
            TotalRevenue = totalRevenue,
            ExpectedCashInDrawer = expectedCash,
            ActualCashInDrawer = dto.ActualCash,
            Discrepancy = discrepancy,
            TotalCompletedOrders = payments.Select(p => p.OrderId).Distinct().Count()
        };

        shift.ZReportJson = JsonSerializer.Serialize(report);
        context.Shifts.Update(shift);
        await context.SaveChangesAsync();

        return (true, "Đóng ca làm việc và kết xuất báo cáo Z-Report thành công", report);
    }

    public async Task<ZReportDto?> GetZReportAsync(int shiftId)
    {
        var shift = await context.Shifts.FindAsync(shiftId);
        if (shift == null || string.IsNullOrEmpty(shift.ZReportJson)) return null;

        try
        {
            return JsonSerializer.Deserialize<ZReportDto>(shift.ZReportJson);
        }
        catch
        {
            return null;
        }
    }
}
