using Microsoft.EntityFrameworkCore;

namespace WebApi.Models;

public class ProductDto
{
    public int ProductId { get; set; }
    public short CategoryId { get; set; }
    public string CategoryName { get; set; } = string.Empty;
    public string ProductName { get; set; } = string.Empty;
    public decimal Price { get; set; }
    public string Unit { get; set; } = "Phần";
    public string? Description { get; set; }
    public string ImageUrl { get; set; } = string.Empty;
    public bool IsAvailable { get; set; } = true;
    public bool IsFeatured { get; set; } = false;
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public List<ProductAttributeDto> Attributes { get; set; } = new();
}

public class ProductAttributeDto
{
    public int AttributeId { get; set; }
    public int ProductId { get; set; }
    public string AttributeGroup { get; set; } = string.Empty;
    public string AttributeName { get; set; } = string.Empty;
    public decimal ExtraPrice { get; set; }
    public bool IsRequired { get; set; }
}

public class PagedResult<T>
{
    public List<T> Items { get; set; } = new();
    public int TotalItems { get; set; }
    public int Page { get; set; }
    public int PageSize { get; set; }
    public int TotalPages => (int)Math.Ceiling((double)TotalItems / (PageSize > 0 ? PageSize : 10));
}

public class ProductRepository : BaseRepository
{
    public ProductRepository(RestaurantPosContext context) : base(context) { }

    private IQueryable<ProductDto> BaseQuery()
    {
        return from p in context.Products
               join c in context.Categories on p.CategoryId equals c.Id into catGroup
               from c in catGroup.DefaultIfEmpty()
               select new ProductDto
               {
                   ProductId = p.ProductId,
                   CategoryId = p.CategoryId,
                   CategoryName = c != null ? c.Name : "Khác",
                   ProductName = p.ProductName,
                   Price = p.Price,
                   Unit = p.Unit,
                   Description = p.Description,
                   ImageUrl = p.ImageUrl,
                   IsAvailable = p.IsAvailable,
                   IsFeatured = p.IsFeatured,
                   CreatedAt = p.CreatedAt,
                   UpdatedAt = p.UpdatedAt
               };
    }

    public async Task<PagedResult<ProductDto>> GetPagedProductsAsync(
        int page = 1,
        int pageSize = 10,
        short? categoryId = null,
        string? search = null)
    {
        if (page < 1) page = 1;
        if (pageSize < 1) pageSize = 10;

        var query = BaseQuery();

        if (categoryId.HasValue && categoryId.Value > 0)
        {
            query = query.Where(p => p.CategoryId == categoryId.Value);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            string keyword = search.Trim().ToLower();
            query = query.Where(p => p.ProductName.ToLower().Contains(keyword) ||
                                     (p.Description != null && p.Description.ToLower().Contains(keyword)));
        }

        int totalItems = await query.CountAsync();
        var items = await query.OrderByDescending(p => p.ProductId)
                               .Skip((page - 1) * pageSize)
                               .Take(pageSize)
                               .ToListAsync();

        return new PagedResult<ProductDto>
        {
            Items = items,
            TotalItems = totalItems,
            Page = page,
            PageSize = pageSize
        };
    }

    public async Task<PagedResult<ProductDto>> GetLatestProductsAsync(int page = 1, int pageSize = 10)
    {
        if (page < 1) page = 1;
        if (pageSize < 1) pageSize = 10;

        var query = BaseQuery().OrderByDescending(p => p.CreatedAt).ThenByDescending(p => p.ProductId);
        int totalItems = await query.CountAsync();
        var items = await query.Skip((page - 1) * pageSize).Take(pageSize).ToListAsync();

        return new PagedResult<ProductDto>
        {
            Items = items,
            TotalItems = totalItems,
            Page = page,
            PageSize = pageSize
        };
    }

    public async Task<PagedResult<ProductDto>> GetByCategoryAsync(short categoryId, int page = 1, int pageSize = 10)
    {
        return await GetPagedProductsAsync(page, pageSize, categoryId, null);
    }

    public async Task<PagedResult<ProductDto>> SearchProductsAsync(string keyword, int page = 1, int pageSize = 10)
    {
        return await GetPagedProductsAsync(page, pageSize, null, keyword);
    }

    public async Task<PagedResult<ProductDto>> GetRelatedProductsAsync(int productId, int page = 1, int pageSize = 10)
    {
        if (page < 1) page = 1;
        if (pageSize < 1) pageSize = 10;

        var current = await context.Products.FindAsync(productId);
        if (current == null)
        {
            return new PagedResult<ProductDto> { Page = page, PageSize = pageSize };
        }

        var query = BaseQuery()
            .Where(p => p.CategoryId == current.CategoryId && p.ProductId != productId)
            .OrderByDescending(p => p.ProductId);

        int totalItems = await query.CountAsync();
        var items = await query.Skip((page - 1) * pageSize).Take(pageSize).ToListAsync();

        return new PagedResult<ProductDto>
        {
            Items = items,
            TotalItems = totalItems,
            Page = page,
            PageSize = pageSize
        };
    }

    public async Task<Product?> GetByIdAsync(int id)
    {
        return await context.Products.FindAsync(id);
    }

    public async Task<ProductDto?> GetWithAttributesByIdAsync(int id)
    {
        var dto = await BaseQuery().FirstOrDefaultAsync(p => p.ProductId == id);
        if (dto == null) return null;

        var attrs = await context.ProductAttributes
            .Where(a => a.ProductId == id)
            .Select(a => new ProductAttributeDto
            {
                AttributeId = a.AttributeId,
                ProductId = a.ProductId,
                AttributeGroup = a.AttributeGroup,
                AttributeName = a.AttributeName,
                ExtraPrice = a.ExtraPrice,
                IsRequired = a.IsRequired
            })
            .ToListAsync();

        dto.Attributes = attrs;
        return dto;
    }

    public async Task<bool> HasOrdersAsync(int productId)
    {
        return await context.OrderDetails.AnyAsync(od => od.ProductId == productId);
    }

    public async Task<int> AddAsync(Product product)
    {
        product.CreatedAt = DateTime.Now;
        context.Products.Add(product);
        return await context.SaveChangesAsync();
    }

    public async Task<int> UpdateAsync(Product product)
    {
        product.UpdatedAt = DateTime.Now;
        context.Products.Update(product);
        return await context.SaveChangesAsync();
    }

    public async Task<int> DeleteAsync(int id)
    {
        var product = await context.Products.FindAsync(id);
        if (product == null) return 0;

        context.Products.Remove(product);
        return await context.SaveChangesAsync();
    }
}
