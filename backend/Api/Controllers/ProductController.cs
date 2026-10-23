using Microsoft.AspNetCore.Mvc;
using WebApi.Models;
using WebApi.Services;

namespace WebApi.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ProductController : BaseController
{
    public ProductController() { }

    /// <summary>
    /// GET /api/product
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> Get(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 10,
        [FromQuery] short? categoryId = null,
        [FromQuery] string? search = null,
        [FromQuery] string? sortBy = null)
    {
        var result = await Provider.Product.GetPagedProductsAsync(page, pageSize, categoryId, search, sortBy);
        return Ok(result);
    }

    /// <summary>
    /// GET /api/product/{id}
    /// </summary>
    [HttpGet("{id:int}")]
    public async Task<IActionResult> Get(int id)
    {
        var item = await Provider.Product.GetWithAttributesByIdAsync(id);
        if (item == null)
        {
            return NotFound(new { statusCode = 404, message = "Không tìm thấy món ăn" });
        }
        return Ok(item);
    }

    /// <summary>
    /// GET /api/product/featured?limit=10
    /// </summary>
    [HttpGet("featured")]
    public async Task<IActionResult> GetFeatured([FromQuery] int limit = 10)
    {
        var items = await Provider.Product.GetFeaturedProductsAsync(limit);
        return Ok(items);
    }

    /// <summary>
    /// GET /api/product/latest?page=1&pageSize=10
    /// </summary>
    [HttpGet("latest")]
    public async Task<IActionResult> GetLatest([FromQuery] int page = 1, [FromQuery] int pageSize = 10)
    {
        var result = await Provider.Product.GetLatestProductsAsync(page, pageSize);
        return Ok(result);
    }

    /// <summary>
    /// GET /api/product/category/{categoryId}?page=1&pageSize=10
    /// </summary>
    [HttpGet("category/{categoryId:int}")]
    public async Task<IActionResult> GetByCategory(short categoryId, [FromQuery] int page = 1, [FromQuery] int pageSize = 10)
    {
        var result = await Provider.Product.GetByCategoryAsync(categoryId, page, pageSize);
        return Ok(result);
    }

    /// <summary>
    /// GET /api/product/search?keyword=...&page=1&pageSize=10
    /// </summary>
    [HttpGet("search")]
    public async Task<IActionResult> Search([FromQuery] string keyword, [FromQuery] int page = 1, [FromQuery] int pageSize = 10)
    {
        var result = await Provider.Product.SearchProductsAsync(keyword, page, pageSize);
        return Ok(result);
    }

    /// <summary>
    /// GET /api/product/{id}/related?page=1&pageSize=10
    /// </summary>
    [HttpGet("{id:int}/related")]
    public async Task<IActionResult> GetRelated(int id, [FromQuery] int page = 1, [FromQuery] int pageSize = 10)
    {
        var result = await Provider.Product.GetRelatedProductsAsync(id, page, pageSize);
        return Ok(result);
    }

    /// <summary>
    /// GET /api/product/related/{id}
    /// </summary>
    [HttpGet("related/{id:int}")]
    public async Task<IActionResult> GetRelatedAlt(int id, [FromQuery] int page = 1, [FromQuery] int pageSize = 10)
    {
        var result = await Provider.Product.GetRelatedProductsAsync(id, page, pageSize);
        return Ok(result);
    }

    /// <summary>
    /// POST /api/product
    /// Creates a new product with support for single or multiple images.
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> Post([FromForm] Product obj, IFormFile? file, [FromForm] List<IFormFile>? files)
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

        if (files != null && files.Count > 0)
        {
            var savedNames = new List<string>();
            foreach (var f in files)
            {
                if (!Helper.ValidateImage(f, out string? err))
                {
                    return BadRequest(new { statusCode = 400, message = err });
                }
            }
            foreach (var f in files)
            {
                savedNames.Add(await Helper.SaveImageAsync(f, "images/products"));
            }
            obj.ImageUrl = string.Join(";", savedNames);
        }
        else if (file != null)
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
            return Ok(new { statusCode = 200, success = true, message = "Thêm món ăn thành công", data = obj, product = obj });
        }

        return BadRequest(new { statusCode = 400, message = "Thêm món ăn thất bại" });
    }

    /// <summary>
    /// PUT /api/product/{id}
    /// Updates product with support for single or multiple images.
    /// </summary>
    [HttpPut("{id:int}")]
    public async Task<IActionResult> Put(int id, [FromForm] Product obj, IFormFile? file, [FromForm] List<IFormFile>? files)
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

        if (files != null && files.Count > 0)
        {
            var savedNames = new List<string>();
            foreach (var f in files)
            {
                if (!Helper.ValidateImage(f, out string? err))
                {
                    return BadRequest(new { statusCode = 400, message = err });
                }
            }
            foreach (var f in files)
            {
                savedNames.Add(await Helper.SaveImageAsync(f, "images/products"));
            }

            // Cleanup old local files if not default
            if (!string.IsNullOrEmpty(existing.ImageUrl))
            {
                foreach (var old in existing.ImageUrl.Split(new[] { ';', '|' }, StringSplitOptions.RemoveEmptyEntries))
                {
                    if (old != "default_product.png" && !old.StartsWith("http://") && !old.StartsWith("https://"))
                    {
                        Helper.DeleteImage(old, "images/products");
                    }
                }
            }
            existing.ImageUrl = string.Join(";", savedNames);
        }
        else if (file != null)
        {
            if (!Helper.ValidateImage(file, out string? imageError))
            {
                return BadRequest(new { statusCode = 400, message = imageError });
            }

            if (!string.IsNullOrEmpty(existing.ImageUrl))
            {
                foreach (var old in existing.ImageUrl.Split(new[] { ';', '|' }, StringSplitOptions.RemoveEmptyEntries))
                {
                    if (old != "default_product.png" && !old.StartsWith("http://") && !old.StartsWith("https://"))
                    {
                        Helper.DeleteImage(old, "images/products");
                    }
                }
            }

            existing.ImageUrl = await Helper.SaveImageAsync(file, "images/products");
        }
        else if (!string.IsNullOrWhiteSpace(obj.ImageUrl))
        {
            existing.ImageUrl = obj.ImageUrl;
        }

        await Provider.Product.UpdateAsync(existing);
        return Ok(new { statusCode = 200, success = true, message = "Cập nhật món ăn thành công", data = existing, product = existing });
    }

    /// <summary>
    /// POST /api/product/{id}/upload-images
    /// Uploads multiple images and appends them to the product gallery.
    /// </summary>
    [HttpPost("{id:int}/upload-images")]
    public async Task<IActionResult> UploadImages(int id, [FromForm] List<IFormFile> files)
    {
        var existing = await Provider.Product.GetByIdAsync(id);
        if (existing == null)
        {
            return NotFound(new { statusCode = 404, message = "Không tìm thấy món ăn" });
        }

        if (files == null || files.Count == 0)
        {
            return BadRequest(new { statusCode = 400, message = "Không có tệp ảnh nào được tải lên" });
        }

        foreach (var f in files)
        {
            if (!Helper.ValidateImage(f, out string? err))
            {
                return BadRequest(new { statusCode = 400, message = err });
            }
        }

        var savedList = new List<string>();
        foreach (var f in files)
        {
            var savedName = await Helper.SaveImageAsync(f, "images/products");
            savedList.Add(savedName);
        }

        var currentImages = string.IsNullOrWhiteSpace(existing.ImageUrl)
            ? new List<string>()
            : existing.ImageUrl.Split(new[] { ';', '|' }, StringSplitOptions.RemoveEmptyEntries).ToList();

        currentImages.Remove("default_product.png");
        currentImages.AddRange(savedList);

        existing.ImageUrl = string.Join(";", currentImages.Distinct());
        await Provider.Product.UpdateAsync(existing);

        return Ok(new
        {
            statusCode = 200,
            success = true,
            message = $"Đã tải lên thành công {savedList.Count} ảnh vào bộ sưu tập món ăn",
            imageUrl = existing.ImageUrl,
            images = currentImages
        });
    }

    /// <summary>
    /// DELETE /api/product/{id}/images
    /// Removes a specific image from product gallery and deletes physical file from disk.
    /// </summary>
    [HttpDelete("{id:int}/images")]
    public async Task<IActionResult> DeleteProductImage(int id, [FromQuery] string imageName)
    {
        var existing = await Provider.Product.GetByIdAsync(id);
        if (existing == null)
        {
            return NotFound(new { statusCode = 404, message = "Không tìm thấy món ăn" });
        }

        if (string.IsNullOrWhiteSpace(imageName))
        {
            return BadRequest(new { statusCode = 400, message = "Tên ảnh cần xóa không được để trống" });
        }

        var currentImages = existing.ImageUrl
            .Split(new[] { ';', '|' }, StringSplitOptions.RemoveEmptyEntries)
            .Select(s => s.Trim())
            .ToList();

        if (!currentImages.Contains(imageName))
        {
            return BadRequest(new { statusCode = 400, message = "Ảnh không tồn tại trong danh sách ảnh của món ăn này" });
        }

        currentImages.Remove(imageName);
        if (!imageName.StartsWith("http://") && !imageName.StartsWith("https://"))
        {
            Helper.DeleteImage(imageName, "images/products");
        }

        existing.ImageUrl = currentImages.Count > 0 ? string.Join(";", currentImages) : "default_product.png";
        await Provider.Product.UpdateAsync(existing);

        return Ok(new
        {
            statusCode = 200,
            success = true,
            message = "Đã xóa ảnh khỏi bộ sưu tập thành công",
            imageUrl = existing.ImageUrl,
            images = currentImages
        });
    }

    /// <summary>
    /// DELETE /api/product/{id}
    /// Deletes product only if not referenced in any historical order. Cleans up all images from disk.
    /// </summary>
    [HttpDelete("{id:int}")]
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

        if (!string.IsNullOrEmpty(existing.ImageUrl))
        {
            var images = existing.ImageUrl.Split(new[] { ';', '|' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
            foreach (var img in images)
            {
                if (img != "default_product.png" && !img.StartsWith("http://") && !img.StartsWith("https://"))
                {
                    Helper.DeleteImage(img, "images/products");
                }
            }
        }

        await Provider.Product.DeleteAsync(id);
        return Ok(new { statusCode = 200, success = true, message = "Đã xóa món ăn thành công" });
    }
}
