using Microsoft.AspNetCore.Mvc;
using WebApi.Models;

namespace WebApi.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class KdsController : BaseController
{
    /// <summary>
    /// GET /api/kds
    /// Retrieves active dishes for the Kitchen Display System (sorted by status and creation time).
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetKdsItems()
    {
        var items = await Provider.Order.GetKdsItemsAsync();
        return Ok(new
        {
            statusCode = 200,
            success = true,
            totalItems = items.Count,
            data = items
        });
    }

    /// <summary>
    /// PUT /api/kds/{orderDetailId}/status
    /// Updates cooking status of an item: 0 = Pending, 1 = Cooking (In Progress), 2 = Ready.
    /// </summary>
    [HttpPut("{orderDetailId}/status")]
    public async Task<IActionResult> UpdateCookingStatus(int orderDetailId, [FromBody] UpdateCookingStatusDto dto)
    {
        if (dto.CookingStatus < 0 || dto.CookingStatus > 2)
        {
            return BadRequest(new { statusCode = 400, message = "Trạng thái chế biến không hợp lệ (0: Chờ nấu, 1: Đang nấu, 2: Đã xong)" });
        }

        var result = await Provider.Order.UpdateCookingStatusAsync(orderDetailId, dto.CookingStatus);
        if (!result.Success)
        {
            return BadRequest(new { statusCode = 400, success = false, message = result.Message });
        }

        return Ok(new
        {
            statusCode = 200,
            success = true,
            message = result.Message,
            cookingStatus = dto.CookingStatus
        });
    }
}

public class UpdateCookingStatusDto
{
    public int CookingStatus { get; set; }
}
