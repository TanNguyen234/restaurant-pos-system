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
    public decimal CostPerUnit { get; set; }
    public decimal LineCost => QuantityRequired * CostPerUnit;
}

public class AttributeRecipeItemDto
{
    public int AttributeRecipeId { get; set; }
    public int AttributeId { get; set; }
    public string AttributeGroup { get; set; } = string.Empty;
    public string AttributeName { get; set; } = string.Empty;
    public int IngredientId { get; set; }
    public string IngredientName { get; set; } = string.Empty;
    public string Unit { get; set; } = string.Empty;
    public decimal QuantityRequired { get; set; }
    public decimal CurrentStock { get; set; }
    public decimal MinThreshold { get; set; }
    public decimal CostPerUnit { get; set; }
    public decimal LineCost => QuantityRequired * CostPerUnit;
}

public class ProductAvailabilityChangeDto
{
    public int ProductId { get; set; }
    public string ProductName { get; set; } = string.Empty;
    public bool IsAvailable { get; set; }
    public bool AutoDisabledByStock { get; set; }
}

public class InventoryMutationResult
{
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
    public Ingredient? Data { get; set; }
    public List<Ingredient> LowStockAlerts { get; set; } = new();
    public List<ProductAvailabilityChangeDto> AvailabilityChanges { get; set; } = new();
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
            var term = search.Trim().ToLower();
            query = query.Where(i => i.IngredientName.ToLower().Contains(term) || i.Unit.ToLower().Contains(term));
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

        string cleanName = dto.IngredientName.Trim();
        bool exists = await context.Ingredients
            .AnyAsync(i => i.IsActive && i.IngredientName.ToLower() == cleanName.ToLower());
        if (exists)
            return (false, $"Nguyên liệu '{cleanName}' đã tồn tại trong kho", null);

        var entity = new Ingredient
        {
            IngredientName = cleanName,
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

    public async Task<(bool Success, string Message, Ingredient? Data, List<ProductAvailabilityChangeDto> AvailabilityChanges)> UpdateIngredientAsync(int id, IngredientInputDto dto)
    {
        var entity = await context.Ingredients.FindAsync(id);
        if (entity == null) return (false, "Không tìm thấy nguyên liệu", null, new());
        if (string.IsNullOrWhiteSpace(dto.IngredientName))
            return (false, "Tên nguyên liệu không được để trống", null, new());
        if (dto.MinThreshold < 0 || dto.CostPerUnit < 0)
            return (false, "Ngưỡng cảnh báo và giá vốn không được âm", null, new());

        string cleanName = dto.IngredientName.Trim();
        bool dup = await context.Ingredients
            .AnyAsync(i => i.IngredientId != id && i.IsActive && i.IngredientName.ToLower() == cleanName.ToLower());
        if (dup)
            return (false, $"Tên nguyên liệu '{cleanName}' đã bị trùng", null, new());

        entity.IngredientName = cleanName;
        entity.Unit = string.IsNullOrWhiteSpace(dto.Unit) ? entity.Unit : dto.Unit.Trim();
        entity.MinThreshold = dto.MinThreshold;
        entity.CostPerUnit = dto.CostPerUnit;
        entity.IsActive = dto.IsActive;
        entity.UpdatedAt = DateTime.Now;
        await context.SaveChangesAsync();

        var changes = await SyncProductsAvailabilityForIngredientsAsync(new[] { entity.IngredientId });
        return (true, "Cập nhật nguyên liệu thành công", entity, changes);
    }

    public async Task<(bool Success, string Message)> DeleteIngredientAsync(int id)
    {
        var entity = await context.Ingredients.FindAsync(id);
        if (entity == null) return (false, "Không tìm thấy nguyên liệu");

        var usedProductNames = await (
            from r in context.ProductRecipes
            join p in context.Products on r.ProductId equals p.ProductId
            where r.IngredientId == id
            select p.ProductName
        ).Distinct().Take(3).ToListAsync();

        if (usedProductNames.Count > 0)
        {
            return (false, $"Nguyên liệu '{entity.IngredientName}' đang gắn với công thức của {string.Join(", ", usedProductNames)}. Vui lòng gỡ khỏi BOM trước khi xóa.");
        }

        bool usedInAttributes = await context.ProductAttributeRecipes.AnyAsync(r => r.IngredientId == id);
        if (usedInAttributes)
        {
            return (false, $"Nguyên liệu '{entity.IngredientName}' đang gắn với công thức Size/Topping. Vui lòng gỡ trước khi xóa.");
        }

        bool hasHistory = await context.StockTransactions.AnyAsync(t => t.IngredientId == id);
        if (hasHistory)
        {
            entity.IsActive = false;
            entity.UpdatedAt = DateTime.Now;
            await context.SaveChangesAsync();
            return (true, $"Đã ngừng kích hoạt nguyên liệu '{entity.IngredientName}' (giữ lại lịch sử sổ kho)");
        }

        context.Ingredients.Remove(entity);
        await context.SaveChangesAsync();
        return (true, $"Đã xóa nguyên liệu '{entity.IngredientName}' khỏi kho");
    }

    public async Task<InventoryMutationResult> AdjustStockAsync(int id, AdjustStockDto dto, int? accountId)
    {
        var entity = await context.Ingredients.FindAsync(id);
        if (entity == null) return new InventoryMutationResult { Success = false, Message = "Không tìm thấy nguyên liệu" };
        if (dto.ChangeAmount == 0) return new InventoryMutationResult { Success = false, Message = "Số lượng điều chỉnh phải khác 0" };

        string txType = string.IsNullOrWhiteSpace(dto.Type) ? "ADJUST" : dto.Type.Trim().ToUpperInvariant();
        decimal nextStock = entity.CurrentStock + dto.ChangeAmount;
        if (nextStock < 0)
            return new InventoryMutationResult
            {
                Success = false,
                Message = $"Tồn kho '{entity.IngredientName}' hiện chỉ còn {entity.CurrentStock:0.##} {entity.Unit}, không thể xuất vượt quá tồn"
            };

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
        var availabilityChanges = await SyncProductsAvailabilityForIngredientsAsync(new[] { entity.IngredientId });
        var alerts = entity.CurrentStock <= entity.MinThreshold ? new List<Ingredient> { entity } : new List<Ingredient>();

        return new InventoryMutationResult
        {
            Success = true,
            Message = $"Đã cập nhật tồn kho '{entity.IngredientName}' thành {entity.CurrentStock:0.##} {entity.Unit}",
            Data = entity,
            LowStockAlerts = alerts,
            AvailabilityChanges = availabilityChanges
        };
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
                MinThreshold = ing.MinThreshold,
                CostPerUnit = ing.CostPerUnit
            }
        ).ToListAsync();
    }

    public async Task<(bool Success, string Message, List<RecipeItemDto> Data, List<ProductAvailabilityChangeDto> AvailabilityChanges)>
        SaveRecipesForProductAsync(int productId, List<RecipeItemInputDto> items)
    {
        var product = await context.Products.FindAsync(productId);
        if (product == null) return (false, "Không tìm thấy sản phẩm", new(), new());

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
            var reqIngIds = cleanItems.Select(c => c.IngredientId).Distinct().ToList();
            var validIngIds = await context.Ingredients
                .Where(i => reqIngIds.Contains(i.IngredientId) && i.IsActive)
                .Select(i => i.IngredientId)
                .ToListAsync();
            var missing = reqIngIds.Except(validIngIds).ToList();
            if (missing.Count > 0)
            {
                return (false, $"Nguyên liệu #{string.Join(", #", missing)} không tồn tại hoặc đã ngưng hoạt động", new(), new());
            }
        }

        var existing = await context.ProductRecipes.Where(r => r.ProductId == productId).ToListAsync();
        context.ProductRecipes.RemoveRange(existing);
        await context.SaveChangesAsync();

        if (cleanItems.Count > 0)
        {
            context.ProductRecipes.AddRange(cleanItems);
            await context.SaveChangesAsync();
        }

        var availabilityChanges = await SyncProductsAvailabilityAsync(new[] { productId });
        var updated = await GetRecipesByProductAsync(productId);
        return (true, $"Đã lưu định lượng BOM ({updated.Count} nguyên liệu) cho '{product.ProductName}'", updated, availabilityChanges);
    }

    public async Task<List<AttributeRecipeItemDto>> GetAttributeRecipesByProductAsync(int productId)
    {
        return await (
            from ar in context.ProductAttributeRecipes
            join attr in context.ProductAttributes on ar.AttributeId equals attr.AttributeId
            join ing in context.Ingredients on ar.IngredientId equals ing.IngredientId
            where attr.ProductId == productId
            orderby attr.AttributeGroup, attr.AttributeName, ing.IngredientName
            select new AttributeRecipeItemDto
            {
                AttributeRecipeId = ar.AttributeRecipeId,
                AttributeId = attr.AttributeId,
                AttributeGroup = attr.AttributeGroup,
                AttributeName = attr.AttributeName,
                IngredientId = ing.IngredientId,
                IngredientName = ing.IngredientName,
                Unit = ing.Unit,
                QuantityRequired = ar.QuantityRequired,
                CurrentStock = ing.CurrentStock,
                MinThreshold = ing.MinThreshold,
                CostPerUnit = ing.CostPerUnit
            }
        ).ToListAsync();
    }

    public async Task<List<AttributeRecipeItemDto>> GetAttributeRecipesAsync(int attributeId)
    {
        return await (
            from ar in context.ProductAttributeRecipes
            join attr in context.ProductAttributes on ar.AttributeId equals attr.AttributeId
            join ing in context.Ingredients on ar.IngredientId equals ing.IngredientId
            where ar.AttributeId == attributeId
            orderby ing.IngredientName
            select new AttributeRecipeItemDto
            {
                AttributeRecipeId = ar.AttributeRecipeId,
                AttributeId = attr.AttributeId,
                AttributeGroup = attr.AttributeGroup,
                AttributeName = attr.AttributeName,
                IngredientId = ing.IngredientId,
                IngredientName = ing.IngredientName,
                Unit = ing.Unit,
                QuantityRequired = ar.QuantityRequired,
                CurrentStock = ing.CurrentStock,
                MinThreshold = ing.MinThreshold,
                CostPerUnit = ing.CostPerUnit
            }
        ).ToListAsync();
    }

    public async Task<(bool Success, string Message, List<AttributeRecipeItemDto> Data)>
        SaveRecipesForAttributeAsync(int attributeId, List<RecipeItemInputDto> items)
    {
        var attr = await context.ProductAttributes.FindAsync(attributeId);
        if (attr == null) return (false, "Không tìm thấy tùy chọn Size/Topping", new());

        var cleanItems = items
            .Where(i => i.IngredientId > 0 && i.QuantityRequired > 0)
            .GroupBy(i => i.IngredientId)
            .Select(g => new ProductAttributeRecipe
            {
                AttributeId = attributeId,
                IngredientId = g.Key,
                QuantityRequired = g.Sum(x => x.QuantityRequired)
            })
            .ToList();

        if (cleanItems.Count > 0)
        {
            var reqIngIds = cleanItems.Select(c => c.IngredientId).Distinct().ToList();
            var validIngIds = await context.Ingredients
                .Where(i => reqIngIds.Contains(i.IngredientId) && i.IsActive)
                .Select(i => i.IngredientId)
                .ToListAsync();
            var missing = reqIngIds.Except(validIngIds).ToList();
            if (missing.Count > 0)
            {
                return (false, $"Nguyên liệu #{string.Join(", #", missing)} không tồn tại hoặc đã ngưng hoạt động", new());
            }
        }

        var existing = await context.ProductAttributeRecipes.Where(r => r.AttributeId == attributeId).ToListAsync();
        context.ProductAttributeRecipes.RemoveRange(existing);
        await context.SaveChangesAsync();

        if (cleanItems.Count > 0)
        {
            context.ProductAttributeRecipes.AddRange(cleanItems);
            await context.SaveChangesAsync();
        }

        var updated = await GetAttributeRecipesAsync(attributeId);
        return (true, $"Đã lưu định lượng BOM cho '{attr.AttributeName}'", updated);
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
    /// Tự động đồng bộ trạng thái Hết món / Mở bán lại dựa trên nguyên liệu vừa thay đổi.
    /// Chỉ mở lại các món trước đó bị khóa tự động bởi kho (AutoDisabledByStock == true).
    /// </summary>
    public async Task<List<ProductAvailabilityChangeDto>> SyncProductsAvailabilityForIngredientsAsync(IEnumerable<int> ingredientIds)
    {
        var ingList = ingredientIds.Distinct().ToList();
        if (ingList.Count == 0) return new();

        var affectedProductIds = await context.ProductRecipes
            .Where(r => ingList.Contains(r.IngredientId))
            .Select(r => r.ProductId)
            .Distinct()
            .ToListAsync();

        return await SyncProductsAvailabilityAsync(affectedProductIds);
    }

    public async Task<List<ProductAvailabilityChangeDto>> SyncProductsAvailabilityAsync(IEnumerable<int> productIds)
    {
        var pidList = productIds.Distinct().ToList();
        if (pidList.Count == 0) return new();

        var products = await context.Products.Where(p => pidList.Contains(p.ProductId)).ToListAsync();
        var recipes = await context.ProductRecipes.Where(r => pidList.Contains(r.ProductId)).ToListAsync();
        if (products.Count == 0 || recipes.Count == 0) return new();

        var ingIds = recipes.Select(r => r.IngredientId).Distinct().ToList();
        var ingMap = await context.Ingredients
            .Where(i => ingIds.Contains(i.IngredientId))
            .ToDictionaryAsync(i => i.IngredientId);

        var changes = new List<ProductAvailabilityChangeDto>();
        foreach (var prod in products)
        {
            var prodRecipes = recipes.Where(r => r.ProductId == prod.ProductId).ToList();
            if (prodRecipes.Count == 0) continue;

            bool canMakeOne = prodRecipes.All(r =>
                ingMap.TryGetValue(r.IngredientId, out var ing) &&
                ing.IsActive &&
                ing.CurrentStock >= r.QuantityRequired);

            if (!canMakeOne && prod.IsAvailable)
            {
                prod.IsAvailable = false;
                prod.AutoDisabledByStock = true;
                prod.UpdatedAt = DateTime.Now;
                changes.Add(new ProductAvailabilityChangeDto
                {
                    ProductId = prod.ProductId,
                    ProductName = prod.ProductName,
                    IsAvailable = false,
                    AutoDisabledByStock = true
                });
            }
            else if (canMakeOne && !prod.IsAvailable && prod.AutoDisabledByStock)
            {
                prod.IsAvailable = true;
                prod.AutoDisabledByStock = false;
                prod.UpdatedAt = DateTime.Now;
                changes.Add(new ProductAvailabilityChangeDto
                {
                    ProductId = prod.ProductId,
                    ProductName = prod.ProductName,
                    IsAvailable = true,
                    AutoDisabledByStock = false
                });
            }
        }

        if (changes.Count > 0)
        {
            await context.SaveChangesAsync();
        }
        return changes;
    }

    /// <summary>
    /// Kiểm tra đủ tồn kho và trừ kho tự động theo công thức BOM của món + tùy chọn Size/Topping.
    /// Chặn đơn hàng nếu bất kỳ nguyên liệu nào không đủ tồn kho.
    /// </summary>
    public async Task<InventoryMutationResult> DeductForOrderItemsAsync(
        int orderId,
        IEnumerable<(int ProductId, int Quantity, IEnumerable<int>? AttributeIds)> items,
        int? accountId)
    {
        var itemList = items.Where(i => i.Quantity > 0).ToList();
        if (itemList.Count == 0) return new InventoryMutationResult { Success = true, Message = "OK" };

        var productIds = itemList.Select(i => i.ProductId).Distinct().ToList();
        var attrIds = itemList
            .Where(i => i.AttributeIds != null)
            .SelectMany(i => i.AttributeIds!)
            .Where(id => id > 0)
            .Distinct()
            .ToList();

        var recipes = await context.ProductRecipes
            .Where(r => productIds.Contains(r.ProductId))
            .ToListAsync();

        var attrRecipes = attrIds.Count > 0
            ? await context.ProductAttributeRecipes.Where(ar => attrIds.Contains(ar.AttributeId)).ToListAsync()
            : new List<ProductAttributeRecipe>();

        var deductions = new Dictionary<int, decimal>();
        foreach (var (productId, qty, itemAttrIds) in itemList)
        {
            foreach (var r in recipes.Where(x => x.ProductId == productId))
            {
                decimal needed = r.QuantityRequired * qty;
                if (needed > 0)
                    deductions[r.IngredientId] = deductions.GetValueOrDefault(r.IngredientId, 0) + needed;
            }

            if (itemAttrIds != null)
            {
                foreach (var aid in itemAttrIds.Where(id => id > 0))
                {
                    foreach (var ar in attrRecipes.Where(x => x.AttributeId == aid))
                    {
                        decimal needed = ar.QuantityRequired * qty;
                        if (needed > 0)
                            deductions[ar.IngredientId] = deductions.GetValueOrDefault(ar.IngredientId, 0) + needed;
                    }
                }
            }
        }

        if (deductions.Count == 0) return new InventoryMutationResult { Success = true, Message = "OK" };

        var ingIds = deductions.Keys.ToList();
        var ingredients = await context.Ingredients
            .Where(i => ingIds.Contains(i.IngredientId))
            .ToDictionaryAsync(i => i.IngredientId);

        // Kiểm tra đủ tồn kho trước khi trừ bất kỳ nguyên liệu nào
        foreach (var kv in deductions)
        {
            if (!ingredients.TryGetValue(kv.Key, out var ing) || !ing.IsActive)
            {
                return new InventoryMutationResult
                {
                    Success = false,
                    Message = $"Nguyên liệu #{kv.Key} trong công thức không tồn tại hoặc đã ngưng sử dụng"
                };
            }

            if (ing.CurrentStock < kv.Value)
            {
                return new InventoryMutationResult
                {
                    Success = false,
                    Message = $"Không đủ nguyên liệu '{ing.IngredientName}' (cần {kv.Value:0.##} {ing.Unit}, trong kho chỉ còn {ing.CurrentStock:0.##} {ing.Unit})"
                };
            }
        }

        var lowStockAlerts = new List<Ingredient>();
        foreach (var kv in deductions)
        {
            var ing = ingredients[kv.Key];
            ing.CurrentStock -= kv.Value;
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
        var availabilityChanges = await SyncProductsAvailabilityForIngredientsAsync(ingIds);

        return new InventoryMutationResult
        {
            Success = true,
            Message = "Đã trừ tồn kho BOM thành công",
            LowStockAlerts = lowStockAlerts,
            AvailabilityChanges = availabilityChanges
        };
    }

    public Task<InventoryMutationResult> DeductForOrderItemsAsync(
        int orderId,
        IEnumerable<(int ProductId, int Quantity)> items,
        int? accountId)
    {
        return DeductForOrderItemsAsync(
            orderId,
            items.Select(x => (x.ProductId, x.Quantity, (IEnumerable<int>?)null)),
            accountId);
    }

    /// <summary>
    /// Hoàn trả tồn kho nguyên liệu khi hủy món (Void) hoặc hủy đơn — chống hoàn vượt quá lượng đã thực trừ trên đơn hàng.
    /// </summary>
    public async Task<List<ProductAvailabilityChangeDto>> RestoreForVoidAsync(
        int orderId,
        int productId,
        int voidQty,
        IEnumerable<int>? attributeIds,
        int? accountId)
    {
        if (voidQty <= 0) return new();

        var recipes = await context.ProductRecipes.Where(r => r.ProductId == productId).ToListAsync();
        var attrIdList = attributeIds?.Where(id => id > 0).Distinct().ToList() ?? new List<int>();
        var attrRecipes = attrIdList.Count > 0
            ? await context.ProductAttributeRecipes.Where(ar => attrIdList.Contains(ar.AttributeId)).ToListAsync()
            : new List<ProductAttributeRecipe>();

        var expectedRefunds = new Dictionary<int, decimal>();
        foreach (var r in recipes)
        {
            decimal refund = r.QuantityRequired * voidQty;
            if (refund > 0)
                expectedRefunds[r.IngredientId] = expectedRefunds.GetValueOrDefault(r.IngredientId, 0) + refund;
        }
        if (attributeIds != null)
        {
            foreach (var aid in attributeIds.Where(id => id > 0))
            {
                foreach (var ar in attrRecipes.Where(x => x.AttributeId == aid))
                {
                    decimal refund = ar.QuantityRequired * voidQty;
                    if (refund > 0)
                        expectedRefunds[ar.IngredientId] = expectedRefunds.GetValueOrDefault(ar.IngredientId, 0) + refund;
                }
            }
        }

        if (expectedRefunds.Count == 0) return new();

        var ingIds = expectedRefunds.Keys.ToList();
        var ingredients = await context.Ingredients
            .Where(i => ingIds.Contains(i.IngredientId))
            .ToDictionaryAsync(i => i.IngredientId);

        // Chống "đẻ kho ảo": chỉ hoàn tối đa bằng (Tổng DEDUCT - Tổng REFUND) của OrderId này
        var orderStockTxs = await context.StockTransactions
            .Where(t => t.OrderId == orderId && ingIds.Contains(t.IngredientId))
            .ToListAsync();

        var touchedIngIds = new List<int>();
        foreach (var kv in expectedRefunds)
        {
            if (!ingredients.TryGetValue(kv.Key, out var ing)) continue;

            decimal totalDeducted = orderStockTxs
                .Where(t => t.IngredientId == kv.Key && t.Type == "DEDUCT")
                .Sum(t => Math.Abs(t.ChangeAmount));
            decimal totalAlreadyRefunded = orderStockTxs
                .Where(t => t.IngredientId == kv.Key && t.Type == "REFUND")
                .Sum(t => Math.Max(0, t.ChangeAmount));

            decimal maxRefundable = Math.Max(0, totalDeducted - totalAlreadyRefunded);
            decimal actualRefund = totalDeducted > 0 ? Math.Min(kv.Value, maxRefundable) : 0;
            if (actualRefund <= 0) continue;

            ing.CurrentStock += actualRefund;
            ing.UpdatedAt = DateTime.Now;
            touchedIngIds.Add(ing.IngredientId);
            context.StockTransactions.Add(new StockTransaction
            {
                IngredientId = ing.IngredientId,
                OrderId = orderId,
                AccountId = accountId,
                ChangeAmount = actualRefund,
                Type = "REFUND",
                Note = $"Hoàn kho hủy {voidQty}x món #{productId} (Đơn #{orderId})",
                CreatedAt = DateTime.Now
            });
        }

        if (touchedIngIds.Count == 0) return new();

        await context.SaveChangesAsync();
        return await SyncProductsAvailabilityForIngredientsAsync(touchedIngIds);
    }

    public Task<List<ProductAvailabilityChangeDto>> RestoreForVoidAsync(int orderId, int productId, int voidQty, int? accountId)
    {
        return RestoreForVoidAsync(orderId, productId, voidQty, null, accountId);
    }
}
