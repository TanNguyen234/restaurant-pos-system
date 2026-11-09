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

public class ZReportDto
{
    public int ShiftId { get; set; }
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
    public decimal Discrepancy { get; set; } // Actual - Expected
    public int TotalCompletedOrders { get; set; }
    public string DiscrepancyNote => Discrepancy == 0 ? "Khớp két 100%" : (Discrepancy > 0 ? $"Dư tiền: +{Discrepancy:N0}đ" : $"Thiếu tiền: {Discrepancy:N0}đ");
}

public class ShiftRepository : BaseRepository
{
    public ShiftRepository(RestaurantPosContext context) : base(context) { }

    public async Task<Shift?> GetCurrentShiftAsync(int? accountId = null)
    {
        var query = context.Shifts.Where(s => s.Status == 1);
        if (accountId.HasValue)
        {
            query = query.Where(s => s.AccountId == accountId.Value);
        }
        return await query.OrderByDescending(s => s.StartTime).FirstOrDefaultAsync();
    }

    public async Task<(bool Success, string Message, Shift? Shift)> OpenShiftAsync(OpenShiftDto dto)
    {
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
            Note = dto.Note
        };

        context.Shifts.Add(shift);
        await context.SaveChangesAsync();

        return (true, $"Mở ca làm việc thành công với số tiền lẻ đầu ca: {dto.InitialCash:N0}đ", shift);
    }

    public async Task<(bool Success, string Message, ZReportDto? Report)> CloseShiftAsync(CloseShiftDto dto)
    {
        var shift = await context.Shifts.FindAsync(dto.ShiftId);
        if (shift == null)
        {
            return (false, "Không tìm thấy thông tin ca làm việc cần đóng", null);
        }

        if (shift.Status == 2)
        {
            return (false, "Ca làm việc này đã được đóng trước đó", null);
        }

        var endTime = DateTime.Now;
        shift.EndTime = endTime;

        // Calculate sales during shift
        var payments = await context.Payments
            .Where(p => p.PaymentTime >= shift.StartTime && p.PaymentTime <= endTime && p.Status == 1)
            .ToListAsync();

        decimal cashSales = payments.Where(p => p.PaymentMethod == "Cash").Sum(p => p.Amount);
        decimal vietQrSales = payments.Where(p => p.PaymentMethod == "VietQR").Sum(p => p.Amount);
        decimal vnPaySales = payments.Where(p => p.PaymentMethod == "VNPay").Sum(p => p.Amount);
        decimal totalRevenue = cashSales + vietQrSales + vnPaySales;

        decimal expectedCash = shift.InitialCash + cashSales;
        decimal discrepancy = dto.ActualCash - expectedCash;

        shift.TotalCash = cashSales;
        shift.TotalTransfer = vietQrSales;
        shift.TotalCard = vnPaySales;
        shift.Discrepancy = discrepancy;
        shift.Status = 2; // Closed
        if (!string.IsNullOrWhiteSpace(dto.Note))
        {
            shift.Note = string.IsNullOrWhiteSpace(shift.Note) ? dto.Note : $"{shift.Note} | Đóng ca: {dto.Note}";
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
        if (shift == null || string.IsNullOrEmpty(shift.ZReportJson))
        {
            return null;
        }

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
