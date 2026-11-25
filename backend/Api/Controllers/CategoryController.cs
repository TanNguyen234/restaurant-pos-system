using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebApi.Models;
using WebApi.Services;

namespace WebApi.Api.Controllers;

public class CategoryFormDto
{
    [Required(ErrorMessage = "Tên danh mục không được để trống")]
    public string Name { get; set; } = string.Empty;
    public string? Title { get; set; }
    public string? Description { get; set; }
    public string? Icon { get; set; }
    public int SortOrder { get; set; } = 0;
    public bool IsActive { get; set; } = true;
}

[ApiController]
[Route("api/[controller]")]
public class CategoryController : BaseController
{
    [HttpGet]
    [AllowAnonymous]
    public IEnumerable<Category> GetCategories([FromQuery] bool includeInactive = false)
    {
        return Provider.Category.GetCategories(includeInactive);
    }

    [HttpGet("{id}")]
    [AllowAnonymous]
    public IActionResult GetById(short id)
    {
        var item = Provider.Category.GetById(id);
        if (item == null) return NotFound(new { success = false, message = "Không tìm thấy danh mục", error = "Không tìm thấy danh mục" });
        return Ok(item);
    }

    [HttpPost]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public async Task<IActionResult> Post([FromForm] CategoryFormDto dto, IFormFile? file)
    {
        if (!ModelState.IsValid || string.IsNullOrWhiteSpace(dto.Name))
        {
            return BadRequest(new { success = false, message = "Tên danh mục không được để trống", error = "Tên danh mục không được để trống" });
        }

        string? savedFile = null;
        try
        {
            string icon = "default_category.png";
            if (file != null)
            {
                if (!Helper.ValidateImage(file, out string? imageError))
                {
                    return BadRequest(new { statusCode = 400, success = false, message = imageError, error = imageError });
                }
                savedFile = await Helper.SaveImageAsync(file, "images/categories");
                icon = savedFile;
            }
            else if (!string.IsNullOrWhiteSpace(dto.Icon))
            {
                icon = dto.Icon.Trim();
            }

            var obj = new Category
            {
                Name = dto.Name.Trim(),
                Title = string.IsNullOrWhiteSpace(dto.Title) ? dto.Name.Trim() : dto.Title.Trim(),
                Description = dto.Description?.Trim() ?? "",
                Icon = icon,
                SortOrder = dto.SortOrder,
                IsActive = dto.IsActive,
                CreatedAt = DateTime.Now
            };

            int result = Provider.Category.Add(obj);
            if (result > 0) return Ok(obj);

            if (savedFile != null) Helper.DeleteImage(savedFile, "images/categories");
            return BadRequest(new { success = false, message = "Thêm danh mục thất bại", error = "Thêm danh mục thất bại" });
        }
        catch
        {
            if (savedFile != null) Helper.DeleteImage(savedFile, "images/categories");
            throw;
        }
    }

    [HttpPut("{id}")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public async Task<IActionResult> Put(short id, [FromForm] CategoryFormDto dto, IFormFile? file)
    {
        var existing = Provider.Category.GetById(id);
        if (existing == null) return NotFound(new { success = false, message = "Không tìm thấy danh mục", error = "Không tìm thấy danh mục" });

        if (!ModelState.IsValid || string.IsNullOrWhiteSpace(dto.Name))
        {
            return BadRequest(new { success = false, message = "Tên danh mục không được để trống", error = "Tên danh mục không được để trống" });
        }

        string? oldIconToDelete = null;
        string? newSavedFile = null;

        try
        {
            if (file != null)
            {
                if (!Helper.ValidateImage(file, out string? imageError))
                {
                    return BadRequest(new { statusCode = 400, success = false, message = imageError, error = imageError });
                }
                oldIconToDelete = existing.Icon;
                newSavedFile = await Helper.SaveImageAsync(file, "images/categories");
                existing.Icon = newSavedFile;
            }
            else if (!string.IsNullOrWhiteSpace(dto.Icon) && dto.Icon.Trim() != existing.Icon)
            {
                if (!existing.Icon.StartsWith("http://") && !existing.Icon.StartsWith("https://"))
                {
                    oldIconToDelete = existing.Icon;
                }
                existing.Icon = dto.Icon.Trim();
            }

            existing.Name = dto.Name.Trim();
            existing.Title = string.IsNullOrWhiteSpace(dto.Title) ? dto.Name.Trim() : dto.Title.Trim();
            existing.Description = dto.Description?.Trim() ?? existing.Description;
            existing.SortOrder = dto.SortOrder;
            existing.IsActive = dto.IsActive;

            Provider.Category.Update(existing);

            if (!string.IsNullOrWhiteSpace(oldIconToDelete) &&
                !oldIconToDelete.StartsWith("http://") &&
                !oldIconToDelete.StartsWith("https://"))
            {
                Helper.DeleteImage(oldIconToDelete, "images/categories");
            }

            return Ok(existing);
        }
        catch
        {
            if (newSavedFile != null) Helper.DeleteImage(newSavedFile, "images/categories");
            throw;
        }
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public IActionResult Delete(short id)
    {
        if (Provider.Category.HasProducts(id))
        {
            const string msg = "Không thể xóa danh mục vì vẫn còn sản phẩm thuộc danh mục này!";
            return BadRequest(new { success = false, message = msg, error = msg });
        }

        var existing = Provider.Category.GetById(id);
        if (existing == null)
        {
            return NotFound(new { success = false, message = "Không tìm thấy danh mục", error = "Không tìm thấy danh mục" });
        }

        string iconToDelete = existing.Icon;
        Provider.Category.Delete(id);

        if (!string.IsNullOrWhiteSpace(iconToDelete) &&
            !iconToDelete.StartsWith("http://") &&
            !iconToDelete.StartsWith("https://"))
        {
            Helper.DeleteImage(iconToDelete, "images/categories");
        }

        return Ok(new { success = true, message = "Đã xóa danh mục thành công" });
    }
}
