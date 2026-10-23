using Microsoft.AspNetCore.Mvc;
using WebApi.Models;
using WebApi.Services;

namespace WebApi.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ProductController : BaseController
{
    /// <summary>
    /// GET /api/product
    /// Retrieves paginated list of products, optionally filtered by category and search term.
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> Get(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 10,
        [FromQuery] short? categoryId = null,
        [FromQuery] string? search = null)
    {
        var result = await Provider.Product.GetPagedProductsAsync(page, pageSize, categoryId, search);
        return Ok(result);
    }

    /// <summary>
    /// GET /api/product/latest
    /// Retrieves latest products with pagination.
    /// </summary>
    [HttpGet("latest")]
    public async Task<IActionResult> GetLatest([FromQuery] int page = 1, [FromQuery] int pageSize = 10)
    {
        var result = await Provider.Product.GetLatestProductsAsync(page, pageSize);
        return Ok(result);
    }

    /// <summary>
    /// GET /api/product/by-category/{categoryId}
    /// Retrieves products belonging to a specific category with pagination.
    /// </summary>
    [HttpGet("by-category/{categoryId}")]
    public async Task<IActionResult> GetByCategory(short categoryId, [FromQuery] int page = 1, [FromQuery] int pageSize = 10)
    {
        var result = await Provider.Product.GetByCategoryAsync(categoryId, page, pageSize);
        return Ok(result);
    }

    /// <summary>
    /// GET /api/product/search
    /// Searches products by keyword with pagination.
    /// </summary>
    [HttpGet("search")]
    public async Task<IActionResult> Search([FromQuery] string keyword, [FromQuery] int page = 1, [FromQuery] int pageSize = 10)
    {
        var result = await Provider.Product.SearchProductsAsync(keyword, page, pageSize);
        return Ok(result);
    }

    /// <summary>
    /// GET /api/product/{id}
    /// Retrieves single product detail including custom attributes (Size, Sugar, Ice, Toppings).
    /// </summary>
    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(int id)
    {
        var product = await Provider.Product.GetWithAttributesByIdAsync(id);
        if (product == null)
        {
            return NotFound(new { statusCode = 404, message = "Không tìm thấy món ăn" });
        }
        return Ok(product);
    }

    /// <summary>
    /// GET /api/product/{id}/related
    /// Retrieves related products in the same category with pagination.
    /// </summary>
    [HttpGet("{id}/related")]
    public async Task<IActionResult> GetRelated(int id, [FromQuery] int page = 1, [FromQuery] int pageSize = 10)
    {
        var result = await Provider.Product.GetRelatedProductsAsync(id, page, pageSize);
        return Ok(result);
    }

    /// <summary>
    /// POST /api/product
    /// Creates a new product with image upload and validations.
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> Post([FromForm] Product obj, IFormFile? file)
    {
        if (string.IsNullOrWhiteSpace(obj.ProductName))
        {
            return BadRequest(new { statusCode = 400, message = "Tên món ăn không được để trống" });
        }

        if (obj.Price < 0)
        {
            return BadRequest(new { statusCode = 400, message = "Đơn giá món ăn không được âm" });
        }

        var category = Provider.Category.GetById(obj.CategoryId);
        if (category == null)
        {
            return BadRequest(new { statusCode = 400, message = "Danh mục được chọn không tồn tại" });
        }

        if (file != null)
        {
            if (!Helper.ValidateImage(file, out string? imageError))
            {
                return BadRequest(new { statusCode = 400, message = imageError });
            }
            obj.ImageUrl = await Helper.SaveImageAsync(file, "images/products");
        }
        else if (string.IsNullOrEmpty(obj.ImageUrl))
        {
            obj.ImageUrl = "default_product.png";
        }

        int result = await Provider.Product.AddAsync(obj);
        if (result > 0)
        {
            return Ok(new { statusCode = 200, success = true, message = "Thêm món ăn thành công", data = obj });
        }

        return BadRequest(new { statusCode = 400, message = "Thêm món ăn thất bại" });
    }

    /// <summary>
    /// PUT /api/product/{id}
    /// Updates product and cleans up old image file upon image replacement.
    /// </summary>
    [HttpPut("{id}")]
    public async Task<IActionResult> Put(int id, [FromForm] Product obj, IFormFile? file)
    {
        var existing = await Provider.Product.GetByIdAsync(id);
        if (existing == null)
        {
            return NotFound(new { statusCode = 404, message = "Không tìm thấy món ăn" });
        }

        if (string.IsNullOrWhiteSpace(obj.ProductName))
        {
            return BadRequest(new { statusCode = 400, message = "Tên món ăn không được để trống" });
        }

        if (obj.Price < 0)
        {
            return BadRequest(new { statusCode = 400, message = "Đơn giá món ăn không được âm" });
        }

        var category = Provider.Category.GetById(obj.CategoryId);
        if (category == null)
        {
            return BadRequest(new { statusCode = 400, message = "Danh mục được chọn không tồn tại" });
        }

        existing.CategoryId = obj.CategoryId;
        existing.ProductName = obj.ProductName;
        existing.Price = obj.Price;
        existing.Unit = obj.Unit;
        existing.Description = obj.Description;
        existing.IsAvailable = obj.IsAvailable;
        existing.IsFeatured = obj.IsFeatured;

        if (file != null)
        {
            if (!Helper.ValidateImage(file, out string? imageError))
            {
                return BadRequest(new { statusCode = 400, message = imageError });
            }

            // Cleanup old image if not default
            if (!string.IsNullOrEmpty(existing.ImageUrl) && existing.ImageUrl != "default_product.png")
            {
                Helper.DeleteImage(existing.ImageUrl, "images/products");
            }

            existing.ImageUrl = await Helper.SaveImageAsync(file, "images/products");
        }

        await Provider.Product.UpdateAsync(existing);
        return Ok(new { statusCode = 200, success = true, message = "Cập nhật món ăn thành công", data = existing });
    }

    /// <summary>
    /// DELETE /api/product/{id}
    /// Deletes product only if not referenced in any historical order. Cleans up image from wwwroot.
    /// </summary>
    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(int id)
    {
        bool hasOrders = await Provider.Product.HasOrdersAsync(id);
        if (hasOrders)
        {
            return BadRequest(new
            {
                statusCode = 400,
                success = false,
                message = "Không thể xóa món ăn này vì đã có dữ liệu trong các đơn hàng lịch sử!"
            });
        }

        var existing = await Provider.Product.GetByIdAsync(id);
        if (existing == null)
        {
            return NotFound(new { statusCode = 404, message = "Không tìm thấy món ăn để xóa" });
        }

        if (!string.IsNullOrEmpty(existing.ImageUrl) && existing.ImageUrl != "default_product.png")
        {
            Helper.DeleteImage(existing.ImageUrl, "images/products");
        }

        await Provider.Product.DeleteAsync(id);
        return Ok(new { statusCode = 200, success = true, message = "Đã xóa món ăn thành công" });
    }
}
