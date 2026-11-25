using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebApi.Models;
using WebApi.Services;

namespace WebApi.Api.Controllers;

public class ProductFormDto
{
    public short CategoryId { get; set; }
    public string ProductName { get; set; } = string.Empty;
    public decimal Price { get; set; }
    public string Unit { get; set; } = "Ly";
    public string? Description { get; set; }
    public string? ImageUrl { get; set; }
    public bool IsAvailable { get; set; } = true;
    public bool IsFeatured { get; set; } = false;
}

[ApiController]
[Route("api/[controller]")]
public class ProductController : BaseController
{
    private readonly PosRealtimeNotifier _realtime;

    public ProductController(PosRealtimeNotifier realtime)
    {
        _realtime = realtime;
    }
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

    [HttpGet("{id:int}")]
    public async Task<IActionResult> Get(int id)
    {
        var item = await Provider.Product.GetWithAttributesByIdAsync(id);
        if (item == null)
        {
            return NotFound(new { statusCode = 404, success = false, message = "Không tìm thấy món ăn" });
        }
        return Ok(item);
    }

    [HttpGet("featured")]
    public async Task<IActionResult> GetFeatured([FromQuery] int limit = 10)
    {
        var items = await Provider.Product.GetFeaturedProductsAsync(limit);
        return Ok(items);
    }

    [HttpGet("latest")]
    public async Task<IActionResult> GetLatest([FromQuery] int page = 1, [FromQuery] int pageSize = 10)
    {
        var result = await Provider.Product.GetLatestProductsAsync(page, pageSize);
        return Ok(result);
    }

    [HttpGet("category/{categoryId:int}")]
    [HttpGet("by-category/{categoryId:int}")]
    public async Task<IActionResult> GetByCategory(int categoryId, [FromQuery] int page = 1, [FromQuery] int pageSize = 10)
    {
        if (categoryId <= 0 || categoryId > short.MaxValue)
        {
            return NotFound(new { statusCode = 404, success = false, message = "Danh mục không tồn tại" });
        }
        var result = await Provider.Product.GetByCategoryAsync((short)categoryId, page, pageSize);
        return Ok(result);
    }

    [HttpGet("search")]
    public async Task<IActionResult> Search([FromQuery] string? keyword = null, [FromQuery] int page = 1, [FromQuery] int pageSize = 10)
    {
        var result = await Provider.Product.SearchProductsAsync(keyword, page, pageSize);
        return Ok(result);
    }

    [HttpGet("{id:int}/related")]
    [HttpGet("related/{id:int}")]
    public async Task<IActionResult> GetRelated(int id, [FromQuery] int page = 1, [FromQuery] int pageSize = 10)
    {
        var result = await Provider.Product.GetRelatedProductsAsync(id, page, pageSize);
        return Ok(result);
    }

    [HttpPost]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public async Task<IActionResult> Post([FromForm] ProductFormDto dto, IFormFile? file, [FromForm] List<IFormFile>? files)
    {
        if (string.IsNullOrWhiteSpace(dto.ProductName))
        {
            return BadRequest(new { statusCode = 400, success = false, message = "Tên món ăn không được để trống" });
        }

        if (dto.Price < 0)
        {
            return BadRequest(new { statusCode = 400, success = false, message = "Đơn giá món ăn không được âm" });
        }

        var category = Provider.Category.GetById(dto.CategoryId);
        if (category == null)
        {
            return BadRequest(new { statusCode = 400, success = false, message = "Danh mục được chọn không tồn tại" });
        }

        var newlySavedFiles = new List<string>();
        try
        {
            string resolvedImage = "default_product.png";
            if (files != null && files.Count > 0)
            {
                foreach (var f in files)
                {
                    if (!Helper.ValidateImage(f, out string? err))
                        return BadRequest(new { statusCode = 400, success = false, message = err });
                }
                foreach (var f in files)
                {
                    newlySavedFiles.Add(await Helper.SaveImageAsync(f, "images/products"));
                }
                resolvedImage = string.Join(";", newlySavedFiles);
            }
            else if (file != null)
            {
                if (!Helper.ValidateImage(file, out string? imageError))
                    return BadRequest(new { statusCode = 400, success = false, message = imageError });

                var saved = await Helper.SaveImageAsync(file, "images/products");
                newlySavedFiles.Add(saved);
                resolvedImage = saved;
            }
            else if (!string.IsNullOrWhiteSpace(dto.ImageUrl))
            {
                resolvedImage = dto.ImageUrl.Trim();
            }

            var obj = new Product
            {
                CategoryId = dto.CategoryId,
                ProductName = dto.ProductName.Trim(),
                Price = dto.Price,
                Unit = string.IsNullOrWhiteSpace(dto.Unit) ? "Ly" : dto.Unit.Trim(),
                Description = dto.Description?.Trim(),
                ImageUrl = resolvedImage,
                IsAvailable = dto.IsAvailable,
                IsFeatured = dto.IsFeatured
            };

            int result = await Provider.Product.AddAsync(obj);
            if (result > 0)
            {
                return Ok(new { statusCode = 200, success = true, message = "Thêm món ăn thành công", data = obj, product = obj });
            }

            foreach (var f in newlySavedFiles) Helper.DeleteImage(f, "images/products");
            return BadRequest(new { statusCode = 400, success = false, message = "Thêm món ăn thất bại" });
        }
        catch
        {
            foreach (var f in newlySavedFiles) Helper.DeleteImage(f, "images/products");
            throw;
        }
    }

    [HttpPut("{id:int}")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public async Task<IActionResult> Put(int id, [FromForm] ProductFormDto dto, IFormFile? file, [FromForm] List<IFormFile>? files)
    {
        var existing = await Provider.Product.GetByIdAsync(id);
        if (existing == null)
        {
            return NotFound(new { statusCode = 404, success = false, message = "Không tìm thấy món ăn" });
        }

        if (string.IsNullOrWhiteSpace(dto.ProductName))
        {
            return BadRequest(new { statusCode = 400, success = false, message = "Tên món ăn không được để trống" });
        }

        if (dto.Price < 0)
        {
            return BadRequest(new { statusCode = 400, success = false, message = "Đơn giá món ăn không được âm" });
        }

        var category = Provider.Category.GetById(dto.CategoryId);
        if (category == null)
        {
            return BadRequest(new { statusCode = 400, success = false, message = "Danh mục được chọn không tồn tại" });
        }

        var oldFilesToDelete = new List<string>();
        var newlySavedFiles = new List<string>();

        try
        {
            string? oldImageUrl = existing.ImageUrl;

            if (files != null && files.Count > 0)
            {
                foreach (var f in files)
                {
                    if (!Helper.ValidateImage(f, out string? err))
                        return BadRequest(new { statusCode = 400, success = false, message = err });
                }
                foreach (var f in files)
                {
                    newlySavedFiles.Add(await Helper.SaveImageAsync(f, "images/products"));
                }
                CollectLocalImages(oldImageUrl, oldFilesToDelete);
                existing.ImageUrl = string.Join(";", newlySavedFiles);
            }
            else if (file != null)
            {
                if (!Helper.ValidateImage(file, out string? imageError))
                    return BadRequest(new { statusCode = 400, success = false, message = imageError });

                var saved = await Helper.SaveImageAsync(file, "images/products");
                newlySavedFiles.Add(saved);
                CollectLocalImages(oldImageUrl, oldFilesToDelete);
                existing.ImageUrl = saved;
            }
            else if (!string.IsNullOrWhiteSpace(dto.ImageUrl) && dto.ImageUrl.Trim() != existing.ImageUrl)
            {
                CollectLocalImages(oldImageUrl, oldFilesToDelete);
                existing.ImageUrl = dto.ImageUrl.Trim();
            }

            existing.CategoryId = dto.CategoryId;
            existing.ProductName = dto.ProductName.Trim();
            existing.Price = dto.Price;
            existing.Unit = string.IsNullOrWhiteSpace(dto.Unit) ? existing.Unit : dto.Unit.Trim();
            existing.Description = dto.Description?.Trim();
            existing.IsAvailable = dto.IsAvailable;
            existing.IsFeatured = dto.IsFeatured;

            await Provider.Product.UpdateAsync(existing);

            foreach (var old in oldFilesToDelete)
            {
                Helper.DeleteImage(old, "images/products");
            }

            return Ok(new { statusCode = 200, success = true, message = "Cập nhật món ăn thành công", data = existing, product = existing });
        }
        catch
        {
            foreach (var f in newlySavedFiles) Helper.DeleteImage(f, "images/products");
            throw;
        }
    }

    [HttpPost("{id:int}/upload-images")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public async Task<IActionResult> UploadImages(int id, [FromForm] List<IFormFile> files)
    {
        var existing = await Provider.Product.GetByIdAsync(id);
        if (existing == null)
        {
            return NotFound(new { statusCode = 404, success = false, message = "Không tìm thấy món ăn" });
        }

        if (files == null || files.Count == 0)
        {
            return BadRequest(new { statusCode = 400, success = false, message = "Không có tệp ảnh nào được tải lên" });
        }

        foreach (var f in files)
        {
            if (!Helper.ValidateImage(f, out string? err))
                return BadRequest(new { statusCode = 400, success = false, message = err });
        }

        var savedList = new List<string>();
        try
        {
            foreach (var f in files)
            {
                savedList.Add(await Helper.SaveImageAsync(f, "images/products"));
            }

            var currentImages = string.IsNullOrWhiteSpace(existing.ImageUrl)
                ? new List<string>()
                : existing.ImageUrl.Split(new[] { ';', '|' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).ToList();

            currentImages.Remove("default_product.png");
            currentImages.AddRange(savedList);
            var distinctImages = currentImages.Distinct().ToList();

            existing.ImageUrl = string.Join(";", distinctImages);
            await Provider.Product.UpdateAsync(existing);

            return Ok(new
            {
                statusCode = 200,
                success = true,
                message = $"Đã tải lên thành công {savedList.Count} ảnh vào bộ sưu tập món ăn",
                imageUrl = existing.ImageUrl,
                images = distinctImages
            });
        }
        catch
        {
            foreach (var f in savedList) Helper.DeleteImage(f, "images/products");
            throw;
        }
    }

    [HttpDelete("{id:int}/images")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public async Task<IActionResult> DeleteProductImage(int id, [FromQuery] string imageName)
    {
        var existing = await Provider.Product.GetByIdAsync(id);
        if (existing == null)
        {
            return NotFound(new { statusCode = 404, success = false, message = "Không tìm thấy món ăn" });
        }

        if (string.IsNullOrWhiteSpace(imageName))
        {
            return BadRequest(new { statusCode = 400, success = false, message = "Tên ảnh cần xóa không được để trống" });
        }

        string targetName = imageName.Trim();
        var currentImages = string.IsNullOrWhiteSpace(existing.ImageUrl)
            ? new List<string>()
            : existing.ImageUrl.Split(new[] { ';', '|' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).ToList();

        if (!currentImages.Contains(targetName))
        {
            return BadRequest(new { statusCode = 400, success = false, message = "Ảnh không tồn tại trong danh sách ảnh của món ăn này" });
        }

        currentImages.Remove(targetName);
        existing.ImageUrl = currentImages.Count > 0 ? string.Join(";", currentImages) : "default_product.png";
        await Provider.Product.UpdateAsync(existing);

        if (!targetName.StartsWith("http://", StringComparison.OrdinalIgnoreCase) &&
            !targetName.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
        {
            Helper.DeleteImage(targetName, "images/products");
        }

        return Ok(new
        {
            statusCode = 200,
            success = true,
            message = "Đã xóa ảnh khỏi bộ sưu tập thành công",
            imageUrl = existing.ImageUrl,
            images = currentImages
        });
    }

    [HttpDelete("{id:int}")]
    [Authorize(Roles = "ADMIN,MANAGER")]
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
            return NotFound(new { statusCode = 404, success = false, message = "Không tìm thấy món ăn để xóa" });
        }

        var oldFiles = new List<string>();
        CollectLocalImages(existing.ImageUrl, oldFiles);

        await Provider.Product.DeleteAsync(id);

        foreach (var img in oldFiles)
        {
            Helper.DeleteImage(img, "images/products");
        }

        return Ok(new { statusCode = 200, success = true, message = "Đã xóa món ăn thành công" });
    }

    [HttpPut("{id:int}/toggle-availability")]
    [Authorize(Roles = "ADMIN,MANAGER,KITCHEN,HEAD_CHEF,BARISTA_LEAD,COOK_ASSISTANT,CASHIER,WAITER")]
    public async Task<IActionResult> ToggleAvailability(int id)
    {
        var product = await Provider.Product.GetByIdAsync(id);
        if (product == null)
        {
            return NotFound(new { statusCode = 404, success = false, message = "Không tìm thấy món ăn" });
        }

        product.IsAvailable = !product.IsAvailable;
        product.UpdatedAt = DateTime.Now;
        await Provider.Product.UpdateAsync(product);

        await _realtime.NotifyKdsChangedAsync(new { productId = product.ProductId, isAvailable = product.IsAvailable });

        return Ok(new
        {
            statusCode = 200,
            success = true,
            message = product.IsAvailable ? $"Đã mở bán lại món '{product.ProductName}'" : $"Đã đánh dấu tạm hết món '{product.ProductName}'",
            productId = product.ProductId,
            isAvailable = product.IsAvailable,
            data = product
        });
    }

    private static void CollectLocalImages(string? imageUrl, List<string> target)
    {
        if (string.IsNullOrWhiteSpace(imageUrl)) return;
        foreach (var img in imageUrl.Split(new[] { ';', '|' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            if (!img.StartsWith("http://", StringComparison.OrdinalIgnoreCase) &&
                !img.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
            {
                target.Add(img);
            }
        }
    }
}
