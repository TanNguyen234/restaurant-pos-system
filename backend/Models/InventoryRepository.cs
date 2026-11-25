using Microsoft.EntityFrameworkCore;

namespace WebApi.Models;

public class IngredientInputDto
{
    public string IngredientName { get; set; } = string.Empty;
    public string Unit { get; set; } = "gram";
    public decimal CurrentStock { get; set; } = 0;
    public decimal MinThreshold { get; set; } = 10;
    public decimal CostPerUnit { get; set; } = 0;
    public bool IsActive { get; set; } = true;
}

public class AdjustStockDto
{
    public decimal ChangeAmount { get; set; }
    public string Type { get; set; } = "IMPORT"; // IMPORT | ADJUST | WASTE
    public string? Note { get; set; }
}

public class RecipeItemInputDto
{
    public int IngredientId { get; set; }
    public decimal QuantityRequired { get; set; }
}

public class RecipeItemDto
{
    public int RecipeId { get; set; }
    public int ProductId { get; set; }
    public int IngredientId { get; set; }
    public string IngredientName { get; set; } = string.Empty;
    public string Unit { get; set; } = string.Empty;
    public decimal QuantityRequired { get; set; }
    public decimal CurrentStock { get; set; }
    public decimal MinThreshold { get; set; }
}

public class StockTransactionDto
{
    public int StockTxId { get; set; }
    public int IngredientId { get; set; }
    public string IngredientName { get; set; } = string.Empty;
    public string Unit { get; set; } = string.Empty;
    public int? OrderId { get; set; }
    public decimal ChangeAmount { get; set; }
    public string Type { get; set; } = string.Empty;
    public string? Note { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class InventoryRepository : BaseRepository
{
    public InventoryRepository(RestaurantPosContext context) : base(context) { }

    public async Task<List<Ingredient>> GetIngredientsAsync(string? search = null, bool lowStockOnly = false)
    {
        var query = context.Ingredients.Where(i => i.IsActive);
        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim();
            query = query.Where(i => i.IngredientName.Contains(term) || i.Unit.Contains(term));
        }
        if (lowStockOnly)
        {
            query = query.Where(i => i.CurrentStock <= i.MinThreshold);
        }
        return await query
            .OrderBy(i => i.CurrentStock <= i.MinThreshold ? 0 : 1)
            .ThenBy(i => i.IngredientName)
            .ToListAsync();
    }

    public async Task<(bool Success, string Message, Ingredient? Data)> CreateIngredientAsync(IngredientInputDto dto, int? accountId)
    {
        if (string.IsNullOrWhiteSpace(dto.IngredientName))
            return (false, "Tên nguyên liệu không được để trống", null);
        if (dto.CurrentStock < 0 || dto.MinThreshold < 0 || dto.CostPerUnit < 0)
            return (false, "Số lượng tồn, ngưỡng cảnh báo và giá vốn không được âm", null);

        var entity = new Ingredient
        {
            IngredientName = dto.IngredientName.Trim(),
            Unit = string.IsNullOrWhiteSpace(dto.Unit) ? "gram" : dto.Unit.Trim(),
            CurrentStock = dto.CurrentStock,
            MinThreshold = dto.MinThreshold,
            CostPerUnit = dto.CostPerUnit,
            IsActive = dto.IsActive,
            UpdatedAt = DateTime.Now
        };
        context.Ingredients.Add(entity);
        await context.SaveChangesAsync();

        if (entity.CurrentStock > 0)
        {
            context.StockTransactions.Add(new StockTransaction
            {
                IngredientId = entity.IngredientId,
                AccountId = accountId,
                ChangeAmount = entity.CurrentStock,
                Type = "IMPORT",
                Note = $"Khởi tạo tồn kho '{entity.IngredientName}'",
                CreatedAt = DateTime.Now
            });
            await context.SaveChangesAsync();
        }

        return (true, "Đã thêm nguyên liệu mới", entity);
    }

    public async Task<(bool Success, string Message, Ingredient? Data)> UpdateIngredientAsync(int id, IngredientInputDto dto)
    {
        var entity = await context.Ingredients.FindAsync(id);
        if (entity == null) return (false, "Không tìm thấy nguyên liệu", null);
        if (string.IsNullOrWhiteSpace(dto.IngredientName))
            return (false, "Tên nguyên liệu không được để trống", null);
        if (dto.MinThreshold < 0 || dto.CostPerUnit < 0)
            return (false, "Ngưỡng cảnh báo và giá vốn không được âm", null);

        entity.IngredientName = dto.IngredientName.Trim();
        entity.Unit = string.IsNullOrWhiteSpace(dto.Unit) ? entity.Unit : dto.Unit.Trim();
        entity.MinThreshold = dto.MinThreshold;
        entity.CostPerUnit = dto.CostPerUnit;
        entity.IsActive = dto.IsActive;
        entity.UpdatedAt = DateTime.Now;
        await context.SaveChangesAsync();
        return (true, "Cập nhật nguyên liệu thành công", entity);
    }

    public async Task<(bool Success, string Message, Ingredient? Data)> AdjustStockAsync(int id, AdjustStockDto dto, int? accountId)
    {
        var entity = await context.Ingredients.FindAsync(id);
        if (entity == null) return (false, "Không tìm thấy nguyên liệu", null);
        if (dto.ChangeAmount == 0) return (false, "Số lượng điều chỉnh phải khác 0", null);

        string txType = string.IsNullOrWhiteSpace(dto.Type) ? "ADJUST" : dto.Type.Trim().ToUpperInvariant();
        decimal nextStock = entity.CurrentStock + dto.ChangeAmount;
        if (nextStock < 0)
            return (false, $"Tồn kho '{entity.IngredientName}' hiện chỉ còn {entity.CurrentStock} {entity.Unit}, không thể xuất vượt quá tồn", null);

        entity.CurrentStock = nextStock;
        entity.UpdatedAt = DateTime.Now;

        context.StockTransactions.Add(new StockTransaction
        {
            IngredientId = entity.IngredientId,
            AccountId = accountId,
            ChangeAmount = dto.ChangeAmount,
            Type = txType,
            Note = string.IsNullOrWhiteSpace(dto.Note) ? $"Điều chỉnh kho ({txType})" : dto.Note.Trim(),
            CreatedAt = DateTime.Now
        });

        await context.SaveChangesAsync();
        return (true, $"Đã cập nhật tồn kho '{entity.IngredientName}' thành {entity.CurrentStock:0.##} {entity.Unit}", entity);
    }

    public async Task<List<RecipeItemDto>> GetRecipesByProductAsync(int productId)
    {
        return await (
            from r in context.ProductRecipes
            join ing in context.Ingredients on r.IngredientId equals ing.IngredientId
            where r.ProductId == productId
            orderby ing.IngredientName
            select new RecipeItemDto
            {
                RecipeId = r.RecipeId,
                ProductId = r.ProductId,
                IngredientId = ing.IngredientId,
                IngredientName = ing.IngredientName,
                Unit = ing.Unit,
                QuantityRequired = r.QuantityRequired,
                CurrentStock = ing.CurrentStock,
                MinThreshold = ing.MinThreshold
            }
        ).ToListAsync();
    }

    public async Task<(bool Success, string Message, List<RecipeItemDto> Data)> SaveRecipesForProductAsync(int productId, List<RecipeItemInputDto> items)
    {
        var product = await context.Products.FindAsync(productId);
        if (product == null) return (false, "Không tìm thấy sản phẩm", new());

        var existing = await context.ProductRecipes.Where(r => r.ProductId == productId).ToListAsync();
        context.ProductRecipes.RemoveRange(existing);

        var cleanItems = items
            .Where(i => i.IngredientId > 0 && i.QuantityRequired > 0)
            .GroupBy(i => i.IngredientId)
            .Select(g => new ProductRecipe
            {
                ProductId = productId,
                IngredientId = g.Key,
                QuantityRequired = g.Sum(x => x.QuantityRequired)
            })
            .ToList();

        if (cleanItems.Count > 0)
        {
            context.ProductRecipes.AddRange(cleanItems);
        }
        await context.SaveChangesAsync();
        var updated = await GetRecipesByProductAsync(productId);
        return (true, $"Đã lưu định lượng BOM ({updated.Count} nguyên liệu) cho '{product.ProductName}'", updated);
    }

    public async Task<List<StockTransactionDto>> GetTransactionsAsync(int? ingredientId = null, int limit = 100)
    {
        var q = from tx in context.StockTransactions
                join ing in context.Ingredients on tx.IngredientId equals ing.IngredientId
                where !ingredientId.HasValue || tx.IngredientId == ingredientId.Value
                orderby tx.CreatedAt descending, tx.StockTxId descending
                select new StockTransactionDto
                {
                    StockTxId = tx.StockTxId,
                    IngredientId = tx.IngredientId,
                    IngredientName = ing.IngredientName,
                    Unit = ing.Unit,
                    OrderId = tx.OrderId,
                    ChangeAmount = tx.ChangeAmount,
                    Type = tx.Type,
                    Note = tx.Note,
                    CreatedAt = tx.CreatedAt
                };
        return await q.Take(Math.Clamp(limit, 1, 300)).ToListAsync();
    }

    /// <summary>
    /// Trừ tồn kho tự động theo công thức BOM (gọi bên trong transaction đang mở của OrderRepository).
    /// </summary>
    public async Task<List<Ingredient>> DeductForOrderItemsAsync(
        int orderId,
        IEnumerable<(int ProductId, int Quantity)> items,
        int? accountId)
    {
        var itemList = items.Where(i => i.Quantity > 0).ToList();
        if (itemList.Count == 0) return new List<Ingredient>();

        var productIds = itemList.Select(i => i.ProductId).Distinct().ToList();
        var recipes = await context.ProductRecipes
            .Where(r => productIds.Contains(r.ProductId))
            .ToListAsync();
        if (recipes.Count == 0) return new List<Ingredient>();

        var deductions = new Dictionary<int, decimal>();
        foreach (var (productId, qty) in itemList)
        {
            foreach (var r in recipes.Where(x => x.ProductId == productId))
            {
                decimal needed = r.QuantityRequired * qty;
                if (needed <= 0) continue;
                deductions[r.IngredientId] = deductions.GetValueOrDefault(r.IngredientId, 0) + needed;
            }
        }
        if (deductions.Count == 0) return new List<Ingredient>();

        var ingIds = deductions.Keys.ToList();
        var ingredients = await context.Ingredients
            .Where(i => ingIds.Contains(i.IngredientId))
            .ToDictionaryAsync(i => i.IngredientId);

        var lowStockAlerts = new List<Ingredient>();
        foreach (var kv in deductions)
        {
            if (!ingredients.TryGetValue(kv.Key, out var ing)) continue;
            ing.CurrentStock = Math.Max(0, ing.CurrentStock - kv.Value);
            ing.UpdatedAt = DateTime.Now;
            context.StockTransactions.Add(new StockTransaction
            {
                IngredientId = ing.IngredientId,
                OrderId = orderId,
                AccountId = accountId,
                ChangeAmount = -kv.Value,
                Type = "DEDUCT",
                Note = $"Xuất kho theo định lượng đơn #{orderId}",
                CreatedAt = DateTime.Now
            });
            if (ing.CurrentStock <= ing.MinThreshold)
            {
                lowStockAlerts.Add(ing);
            }
        }

        await context.SaveChangesAsync();
        return lowStockAlerts;
    }

    /// <summary>
    /// Hoàn trả tồn kho nguyên liệu khi hủy món (Void) trong transaction của OrderRepository.
    /// </summary>
    public async Task RestoreForVoidAsync(int orderId, int productId, int voidQty, int? accountId)
    {
        if (voidQty <= 0) return;
        var recipes = await context.ProductRecipes.Where(r => r.ProductId == productId).ToListAsync();
        if (recipes.Count == 0) return;

        var ingIds = recipes.Select(r => r.IngredientId).Distinct().ToList();
        var ingredients = await context.Ingredients
            .Where(i => ingIds.Contains(i.IngredientId))
            .ToDictionaryAsync(i => i.IngredientId);

        foreach (var r in recipes)
        {
            if (!ingredients.TryGetValue(r.IngredientId, out var ing)) continue;
            decimal refund = r.QuantityRequired * voidQty;
            if (refund <= 0) continue;
            ing.CurrentStock += refund;
            ing.UpdatedAt = DateTime.Now;
            context.StockTransactions.Add(new StockTransaction
            {
                IngredientId = ing.IngredientId,
                OrderId = orderId,
                AccountId = accountId,
                ChangeAmount = refund,
                Type = "REFUND",
                Note = $"Hoàn kho hủy {voidQty}x món #{productId} (Đơn #{orderId})",
                CreatedAt = DateTime.Now
            });
        }

        await context.SaveChangesAsync();
    }
}
