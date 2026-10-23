using Microsoft.AspNetCore.Mvc;
using WebApi.Models;
using WebApi.Services;

namespace WebApi.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ProductController : BaseController
{
    [HttpGet]
    public IActionResult GetProducts(
        [FromQuery] short? categoryId,
        [FromQuery] string? search,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 10,
        [FromQuery] string? sortBy = null)
    {
        var result = Provider.Product.GetPaged(categoryId, search, page, pageSize, sortBy);
        return Ok(result);
    }

    [HttpGet("featured")]
    public IActionResult GetFeatured([FromQuery] int limit = 10)
    {
        var items = Provider.Product.GetFeatured(limit);
        return Ok(items);
    }

    [HttpGet("{id}")]
    public IActionResult GetById(int id)
    {
        var detail = Provider.Product.GetDetailById(id);
        if (detail == null)
        {
            return NotFound(new { error = "Không tìm thấy sản phẩm" });
        }
        return Ok(detail);
    }

    [HttpGet("related/{id}")]
    public IActionResult GetRelated(int id, [FromQuery] int page = 1, [FromQuery] int pageSize = 6)
    {
        var product = Provider.Product.GetById(id);
        if (product == null)
        {
            return NotFound(new { error = "Không tìm thấy sản phẩm" });
        }

        var result = Provider.Product.GetRelatedProducts(id, product.CategoryId, page, pageSize);
        return Ok(result);
    }

    [HttpGet("{id}/attributes")]
    public IActionResult GetAttributes(int id)
    {
        var attrs = Provider.Product.GetAttributes(id);
        return Ok(attrs);
    }

    [HttpPost]
    public async Task<IActionResult> Post([FromForm] Product obj, IFormFile? file)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        if (file != null && file.Length > 0)
        {
            obj.ImageUrl = await Helper.SaveImageAsync(file, "images/products");
        }
        else if (string.IsNullOrEmpty(obj.ImageUrl))
        {
            obj.ImageUrl = "default_product.png";
        }

        int result = Provider.Product.Add(obj);
        if (result > 0)
        {
            return CreatedAtAction(nameof(GetById), new { id = obj.ProductId }, obj);
        }
        return BadRequest(new { error = "Thêm sản phẩm thất bại" });
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> Put(int id, [FromForm] Product obj, IFormFile? file)
    {
        var existing = Provider.Product.GetById(id);
        if (existing == null)
        {
            return NotFound(new { error = "Không tìm thấy sản phẩm" });
        }

        existing.CategoryId = obj.CategoryId;
        existing.ProductName = obj.ProductName;
        existing.Price = obj.Price;
        existing.Unit = obj.Unit;
        existing.Description = obj.Description;
        existing.IsAvailable = obj.IsAvailable;
        existing.IsFeatured = obj.IsFeatured;

        if (file != null && file.Length > 0)
        {
            // Xóa ảnh cũ nếu có (bảo toàn nếu là ảnh default)
            Helper.DeleteImage(existing.ImageUrl, "images/products");
            // Lưu ảnh mới
            existing.ImageUrl = await Helper.SaveImageAsync(file, "images/products");
        }

        Provider.Product.Update(existing);
        return Ok(existing);
    }

    [HttpDelete("{id}")]
    public IActionResult Delete(int id)
    {
        // Kiểm tra ràng buộc bảo toàn kế toán: Nếu sản phẩm đã từng nằm trong đơn hàng thì chặn xóa
        if (Provider.Product.HasOrders(id))
        {
            return BadRequest(new
            {
                error = "Sản phẩm đã có trong hóa đơn, không được xóa để bảo toàn số liệu kế toán! Hãy chọn ẩn sản phẩm."
            });
        }

        var existing = Provider.Product.GetById(id);
        if (existing == null)
        {
            return NotFound(new { error = "Không tìm thấy sản phẩm" });
        }

        Helper.DeleteImage(existing.ImageUrl, "images/products");
        Provider.Product.Delete(id);
        return Ok(new { message = "Đã xóa sản phẩm thành công" });
    }
}
