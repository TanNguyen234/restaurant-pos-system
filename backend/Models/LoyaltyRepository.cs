using Microsoft.EntityFrameworkCore;

namespace WebApi.Models;

public class LoyaltyProfileDto
{
    public int AccountId { get; set; }
    public string FullName { get; set; } = string.Empty;
    public int LoyaltyPoints { get; set; }
    public string Tier { get; set; } = "MEMBER";
    public List<Discount> AvailableVouchers { get; set; } = new();
    public List<string> RedeemedVoucherCodes { get; set; } = new();
    public Dictionary<string, int> VoucherBalances { get; set; } = new(StringComparer.OrdinalIgnoreCase);
    public List<LoyaltyTransaction> History { get; set; } = new();
}

public class LoyaltyRepository : BaseRepository
{
    public LoyaltyRepository(RestaurantPosContext context) : base(context) { }

    public static string ResolveTier(int points, string? roleCode)
    {
        if (string.Equals(roleCode, "VIP_MEMBER", StringComparison.OrdinalIgnoreCase) || points >= 2500)
            return "VIP KIM CƯƠNG";
        if (points >= 1000) return "VIP VÀNG";
        if (points >= 300) return "THÀNH VIÊN BẠC";
        return "THÀNH VIÊN MỚI";
    }

    public async Task<LoyaltyProfileDto?> GetProfileAsync(int accountId)
    {
        var account = await context.Accounts.FindAsync(accountId);
        if (account == null) return null;

        var role = await context.Roles.FindAsync(account.RoleId);
        var vouchers = await context.Discounts
            .Where(d => d.IsActive &&
                        (d.ExpiryDate == null || d.ExpiryDate >= DateTime.Now) &&
                        (d.MaxUsageCount == null || d.UsedCount < d.MaxUsageCount))
            .OrderBy(d => d.PointsCost)
            .ToListAsync();

        var history = await context.LoyaltyTransactions
            .Where(t => t.AccountId == accountId)
            .OrderByDescending(t => t.CreatedAt)
            .Take(20)
            .ToListAsync();

        var unusedVouchers = await context.AccountVouchers
            .Where(av => av.AccountId == accountId && av.Status == 0)
            .ToListAsync();

        var balances = unusedVouchers
            .GroupBy(av => av.VoucherCode.ToUpperInvariant())
            .ToDictionary(g => g.Key, g => g.Count(), StringComparer.OrdinalIgnoreCase);

        var redeemedCodes = balances.Keys.ToList();

        // Mã khuyến mãi công khai (PointsCost == 0) khả dụng cho mọi tài khoản
        foreach (var freeCode in vouchers.Where(v => v.PointsCost == 0).Select(v => v.Code))
        {
            if (!redeemedCodes.Contains(freeCode, StringComparer.OrdinalIgnoreCase))
            {
                redeemedCodes.Add(freeCode);
            }
        }

        return new LoyaltyProfileDto
        {
            AccountId = account.AccountId,
            FullName = account.FullName,
            LoyaltyPoints = account.LoyaltyPoints,
            Tier = ResolveTier(account.LoyaltyPoints, role?.RoleCode),
            AvailableVouchers = vouchers,
            RedeemedVoucherCodes = redeemedCodes,
            VoucherBalances = balances,
            History = history
        };
    }

    public async Task<(bool Success, string Message, int RemainingPoints, string? VoucherCode)> RedeemVoucherAsync(int accountId, string code)
    {
        if (string.IsNullOrWhiteSpace(code))
            return (false, "Vui lòng chọn mã voucher cần đổi", 0, null);

        using var tx = await context.Database.BeginTransactionAsync();
        try
        {
            var account = await context.Accounts.FindAsync(accountId);
            if (account == null) return (false, "Không tìm thấy tài khoản hội viên", 0, null);

            string norm = code.Trim().ToUpperInvariant();
            var voucher = await context.Discounts
                .FirstOrDefaultAsync(d => d.Code.ToUpper() == norm && d.IsActive && (d.ExpiryDate == null || d.ExpiryDate >= DateTime.Now));
            if (voucher == null) return (false, "Mã ưu đãi không tồn tại hoặc đã hết hạn", account.LoyaltyPoints, null);

            if (voucher.MaxUsageCount.HasValue && voucher.UsedCount >= voucher.MaxUsageCount.Value)
                return (false, $"Mã ưu đãi '{voucher.Code}' đã hết lượt phát hành", account.LoyaltyPoints, null);

            if (voucher.PointsCost <= 0)
            {
                return (true, $"Mã '{voucher.Code}' miễn phí điểm — bạn có thể dùng trực tiếp khi thanh toán!", account.LoyaltyPoints, voucher.Code);
            }

            if (account.LoyaltyPoints < voucher.PointsCost)
            {
                return (false, $"Bạn cần thêm {voucher.PointsCost - account.LoyaltyPoints} PTS để đổi mã '{voucher.Code}'", account.LoyaltyPoints, null);
            }

            account.LoyaltyPoints -= voucher.PointsCost;
            account.UpdatedAt = DateTime.Now;
            context.LoyaltyTransactions.Add(new LoyaltyTransaction
            {
                AccountId = accountId,
                PointsDelta = -voucher.PointsCost,
                Type = "REDEEM",
                VoucherCode = voucher.Code,
                Description = $"Đổi {voucher.PointsCost} PTS lấy 1 lượt voucher {voucher.Code}",
                CreatedAt = DateTime.Now
            });

            context.AccountVouchers.Add(new AccountVoucher
            {
                AccountId = accountId,
                DiscountId = voucher.DiscountId,
                VoucherCode = voucher.Code,
                Status = 0,
                RedeemedAt = DateTime.Now
            });

            await context.SaveChangesAsync();
            await tx.CommitAsync();

            return (true, $"Đổi thành công 1 lượt voucher '{voucher.Code}' (-{voucher.PointsCost} PTS)!", account.LoyaltyPoints, voucher.Code);
        }
        catch (Exception)
        {
            await tx.RollbackAsync();
            return (false, "Lỗi khi đổi điểm thưởng", 0, null);
        }
    }
}
