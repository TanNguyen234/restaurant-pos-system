namespace WebApi.Models;

public class PagedResult<T>
{
    public int TotalItems { get; set; }
    public int Page { get; set; }
    public int PageSize { get; set; }
    public int TotalPages { get; set; }
    public IEnumerable<T> Data { get; set; } = Enumerable.Empty<T>();
}

public class ProductDetailDto
{
    public int ProductId { get; set; }
    public short CategoryId { get; set; }
    public string? CategoryName { get; set; }
    public string ProductName { get; set; } = null!;
    public decimal Price { get; set; }
    public string Unit { get; set; } = "Phần";
    public string? Description { get; set; }
    public string ImageUrl { get; set; } = null!;
    public bool IsAvailable { get; set; } = true;
    public bool IsFeatured { get; set; } = false;
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public List<ProductAttribute> Attributes { get; set; } = new();
}

public class ProductRepository : BaseRepository
{
    public ProductRepository(RestaurantPosContext context) : base(context) { }

    public PagedResult<Product> GetPaged(short? categoryId, string? search, int page = 1, int pageSize = 10, string? sortBy = null)
    {
        if (page < 1) page = 1;
        if (pageSize < 1) pageSize = 10;
        if (pageSize > 100) pageSize = 100;

        var query = context.Products.AsQueryable();

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

        query = sortBy?.ToLower() switch
        {
            "price_asc" => query.OrderBy(p => p.Price),
            "price_desc" => query.OrderByDescending(p => p.Price),
            "name_asc" => query.OrderBy(p => p.ProductName),
            "name_desc" => query.OrderByDescending(p => p.ProductName),
            "newest" => query.OrderByDescending(p => p.ProductId),
            _ => query.OrderByDescending(p => p.IsFeatured).ThenBy(p => p.ProductId)
        };

        int totalItems = query.Count();
        int totalPages = (int)Math.Ceiling((double)totalItems / pageSize);

        var data = query.Skip((page - 1) * pageSize)
                        .Take(pageSize)
                        .ToList();

        return new PagedResult<Product>
        {
            TotalItems = totalItems,
            Page = page,
            PageSize = pageSize,
            TotalPages = totalPages,
            Data = data
        };
    }

    public Product? GetById(int id)
    {
        return context.Products.Find(id);
    }

    public ProductDetailDto? GetDetailById(int id)
    {
        var product = context.Products.Find(id);
        if (product == null) return null;

        var category = context.Categories.Find(product.CategoryId);
        var attributes = context.ProductAttributes.Where(a => a.ProductId == id).ToList();

        return new ProductDetailDto
        {
            ProductId = product.ProductId,
            CategoryId = product.CategoryId,
            CategoryName = category?.Name,
            ProductName = product.ProductName,
            Price = product.Price,
            Unit = product.Unit,
            Description = product.Description,
            ImageUrl = product.ImageUrl,
            IsAvailable = product.IsAvailable,
            IsFeatured = product.IsFeatured,
            CreatedAt = product.CreatedAt,
            UpdatedAt = product.UpdatedAt,
            Attributes = attributes
        };
    }

    public IEnumerable<Product> GetFeatured(int limit = 10)
    {
        return context.Products
            .Where(p => p.IsFeatured && p.IsAvailable)
            .OrderByDescending(p => p.ProductId)
            .Take(limit)
            .ToList();
    }

    public PagedResult<Product> GetRelatedProducts(int productId, short categoryId, int page = 1, int pageSize = 6)
    {
        if (page < 1) page = 1;
        if (pageSize < 1) pageSize = 6;

        var query = context.Products
            .Where(p => p.CategoryId == categoryId && p.ProductId != productId && p.IsAvailable)
            .OrderBy(p => p.ProductId);

        int totalItems = query.Count();
        int totalPages = (int)Math.Ceiling((double)totalItems / pageSize);

        var data = query.Skip((page - 1) * pageSize)
                        .Take(pageSize)
                        .ToList();

        return new PagedResult<Product>
        {
            TotalItems = totalItems,
            Page = page,
            PageSize = pageSize,
            TotalPages = totalPages,
            Data = data
        };
    }

    public int Add(Product obj)
    {
        obj.CreatedAt = DateTime.Now;
        context.Products.Add(obj);
        return context.SaveChanges();
    }

    public int Update(Product obj)
    {
        obj.UpdatedAt = DateTime.Now;
        context.Products.Update(obj);
        return context.SaveChanges();
    }

    public int Delete(int id)
    {
        var item = context.Products.Find(id);
        if (item != null)
        {
            context.Products.Remove(item);
            return context.SaveChanges();
        }
        return 0;
    }

    public bool HasOrders(int productId)
    {
        return context.OrderDetails.Any(od => od.ProductId == productId);
    }

    public List<ProductAttribute> GetAttributes(int productId)
    {
        return context.ProductAttributes.Where(a => a.ProductId == productId).ToList();
    }
}
