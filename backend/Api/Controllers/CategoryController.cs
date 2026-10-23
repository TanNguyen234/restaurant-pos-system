using Microsoft.AspNetCore.Mvc;
using WebApi.Models;
using WebApi.Services;

namespace WebApi.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CategoryController : BaseController
{
    [HttpGet]
    public IEnumerable<Category> GetCategories()
    {
        return Provider.Category.GetCategories();
    }

    [HttpGet("{id}")]
    public IActionResult GetById(short id)
    {
        var item = Provider.Category.GetById(id);
        if (item == null) return NotFound(new { error = "Không tìm thấy danh mục" });
        return Ok(item);
    }

    [HttpPost]
    public async Task<IActionResult> Post([FromForm] Category obj, IFormFile? file)
    {
        if (ModelState.IsValid)
        {
            if (file != null)
            {
                if (!Helper.ValidateImage(file, out string? imageError))
                {
                    return BadRequest(new { statusCode = 400, success = false, message = imageError });
                }
                obj.Icon = await Helper.SaveImageAsync(file, "images/categories");
            }
            else if (string.IsNullOrEmpty(obj.Icon))
            {
                obj.Icon = "default_category.png";
            }

            int result = Provider.Category.Add(obj);
            if (result > 0) return Ok(obj);
        }
        return BadRequest(new { error = "Thêm danh mục thất bại" });
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> Put(short id, [FromForm] Category obj, IFormFile? file)
    {
        var existing = Provider.Category.GetById(id);
        if (existing == null) return NotFound(new { error = "Không tìm thấy danh mục" });

        existing.Name = obj.Name;
        existing.Title = obj.Title;
        existing.Description = obj.Description;
        existing.SortOrder = obj.SortOrder;

        if (file != null)
        {
            if (!Helper.ValidateImage(file, out string? imageError))
            {
                return BadRequest(new { statusCode = 400, success = false, message = imageError });
            }
            // Xóa ảnh cũ nếu có
            Helper.DeleteImage(existing.Icon, "images/categories");
            // Lưu ảnh mới
            existing.Icon = await Helper.SaveImageAsync(file, "images/categories");
        }

        Provider.Category.Update(existing);
        return Ok(existing);
    }

    [HttpDelete("{id}")]
    public IActionResult Delete(short id)
    {
        // Kiểm tra ràng buộc: nếu còn sản phẩm thì chặn xóa
        if (Provider.Category.HasProducts(id))
        {
            return BadRequest(new { error = "Không thể xóa danh mục vì vẫn còn sản phẩm thuộc danh mục này!" });
        }

        var existing = Provider.Category.GetById(id);
        if (existing != null)
        {
            Helper.DeleteImage(existing.Icon, "images/categories");
            Provider.Category.Delete(id);
            return Ok(new { message = "Đã xóa danh mục thành công" });
        }
        return NotFound(new { error = "Không tìm thấy danh mục" });
    }
}
