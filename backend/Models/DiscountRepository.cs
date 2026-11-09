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
            .Where(d => d.IsActive && (d.ExpiryDate == null || d.ExpiryDate >= DateTime.Now))
            .OrderByDescending(d => d.DiscountPercent)
            .ThenByDescending(d => d.DiscountAmount)
            .ToListAsync();
    }

    public async Task<DiscountValidationResultDto> ValidateDiscountAsync(string code, decimal orderAmount)
    {
        if (string.IsNullOrWhiteSpace(code))
        {
            return new DiscountValidationResultDto
            {
                IsValid = false,
                Message = "Vui lòng nhập mã giảm giá",
                FinalAmount = orderAmount
            };
        }

        string normalized = code.Trim().ToUpper();
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
            discountAmount = orderAmount * (discount.DiscountPercent / 100m);
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
