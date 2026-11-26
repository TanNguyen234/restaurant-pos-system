using Microsoft.EntityFrameworkCore;

namespace WebApi.Models;

public class DiscountValidationResultDto
{
    public bool IsValid { get; set; }
    public string Message { get; set; } = string.Empty;
    public string Code { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public decimal DiscountPercent { get; set; }
    public decimal DiscountAmount { get; set; }
    public decimal FinalAmount { get; set; }
}

public class DiscountRepository : BaseRepository
{
    public DiscountRepository(RestaurantPosContext context) : base(context) { }

    public async Task<List<Discount>> GetActiveDiscountsAsync()
    {
        return await context.Discounts
            .Where(d => d.IsActive &&
                        (d.ExpiryDate == null || d.ExpiryDate >= DateTime.Now) &&
                        (d.MaxUsageCount == null || d.UsedCount < d.MaxUsageCount))
            .OrderBy(d => d.PointsCost)
            .ThenByDescending(d => d.DiscountPercent)
            .ToListAsync();
    }

    public async Task<Dictionary<string, int>> GetOwnedVoucherCountsAsync(int accountId)
    {
        var list = await context.AccountVouchers
            .Where(av => av.AccountId == accountId && av.Status == 0)
            .Select(av => av.VoucherCode)
            .ToListAsync();

        return list
            .GroupBy(c => c.ToUpperInvariant())
            .ToDictionary(g => g.Key, g => g.Count(), StringComparer.OrdinalIgnoreCase);
    }

    public async Task<DiscountValidationResultDto> ValidateDiscountAsync(string code, decimal orderAmount, int? accountId = null)
    {
        if (orderAmount < 0)
        {
            return new DiscountValidationResultDto
            {
                IsValid = false,
                Message = "Giá trị đơn hàng không hợp lệ",
                FinalAmount = 0
            };
        }

        if (string.IsNullOrWhiteSpace(code))
        {
            return new DiscountValidationResultDto
            {
                IsValid = false,
                Message = "Vui lòng nhập mã giảm giá",
                FinalAmount = orderAmount
            };
        }

        string normalized = code.Trim().ToUpperInvariant();
        var discount = await context.Discounts
            .FirstOrDefaultAsync(d => d.Code.ToUpper() == normalized);

        if (discount == null)
        {
            return new DiscountValidationResultDto
            {
                IsValid = false,
                Message = $"Mã giảm giá '{code}' không tồn tại trong hệ thống",
                FinalAmount = orderAmount
            };
        }

        if (!discount.IsActive)
        {
            return new DiscountValidationResultDto
            {
                IsValid = false,
                Message = $"Mã giảm giá '{code}' đã bị tạm ngưng kích hoạt",
                FinalAmount = orderAmount
            };
        }

        if (discount.ExpiryDate.HasValue && discount.ExpiryDate.Value < DateTime.Now)
        {
            return new DiscountValidationResultDto
            {
                IsValid = false,
                Message = $"Mã giảm giá '{code}' đã hết hạn sử dụng",
                FinalAmount = orderAmount
            };
        }

        if (discount.MaxUsageCount.HasValue && discount.UsedCount >= discount.MaxUsageCount.Value)
        {
            return new DiscountValidationResultDto
            {
                IsValid = false,
                Message = $"Mã giảm giá '{code}' đã đạt giới hạn lượt sử dụng",
                FinalAmount = orderAmount
            };
        }

        if (discount.PointsCost > 0)
        {
            if (!accountId.HasValue || accountId.Value <= 0)
            {
                return new DiscountValidationResultDto
                {
                    IsValid = false,
                    Message = $"Mã '{discount.Code}' dành cho hội viên (cần đổi {discount.PointsCost} PTS). Vui lòng đăng nhập và đổi điểm trước.",
                    FinalAmount = orderAmount
                };
            }

            bool hasUnusedVoucher = await context.AccountVouchers
                .AnyAsync(av => av.AccountId == accountId.Value && av.DiscountId == discount.DiscountId && av.Status == 0);
            if (!hasUnusedVoucher)
            {
                return new DiscountValidationResultDto
                {
                    IsValid = false,
                    Message = $"Bạn chưa có lượt voucher '{discount.Code}' khả dụng. Vui lòng vào mục Hội viên để đổi {discount.PointsCost} PTS.",
                    FinalAmount = orderAmount
                };
            }
        }

        if (orderAmount < discount.MinOrderAmount)
        {
            return new DiscountValidationResultDto
            {
                IsValid = false,
                Message = $"Mã '{code}' chỉ áp dụng cho đơn hàng tối thiểu từ {discount.MinOrderAmount:N0}đ",
                FinalAmount = orderAmount
            };
        }

        decimal discountAmount = 0;
        if (discount.DiscountAmount > 0)
        {
            discountAmount = discount.DiscountAmount;
        }
        else if (discount.DiscountPercent > 0)
        {
            discountAmount = Math.Round(orderAmount * (discount.DiscountPercent / 100m), 0);
            if (discount.MaxDiscountAmount > 0 && discountAmount > discount.MaxDiscountAmount)
            {
                discountAmount = discount.MaxDiscountAmount;
            }
        }

        discountAmount = Math.Min(discountAmount, orderAmount);
        decimal finalAmount = Math.Max(0, orderAmount - discountAmount);

        return new DiscountValidationResultDto
        {
            IsValid = true,
            Message = $"Áp dụng mã '{discount.Code}' thành công: {discount.Title}",
            Code = discount.Code,
            Title = discount.Title,
            DiscountPercent = discount.DiscountPercent,
            DiscountAmount = discountAmount,
            FinalAmount = finalAmount
        };
    }
}
