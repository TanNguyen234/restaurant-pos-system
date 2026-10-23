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
    /// GET /api/kds/active-orders
    /// Direct array response for Flutter Mobile KitchenDisplayPage.
    /// </summary>
    [HttpGet("active-orders")]
    public async Task<IActionResult> GetActiveOrders()
    {
        var items = await Provider.Order.GetKdsItemsAsync();
        return Ok(items);
    }

    /// <summary>
    /// PUT /api/kds/{orderDetailId}/status
    /// Updates cooking status of an item: 0 = Pending, 1 = Cooking (In Progress), 2 = Ready.
    /// </summary>
    [HttpPut("{orderDetailId:int}/status")]
    public async Task<IActionResult> UpdateCookingStatus(int orderDetailId, [FromBody] UpdateCookingStatusDto dto)
    {
        if (dto == null || dto.CookingStatus < 0 || dto.CookingStatus > 2)
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
            orderDetailId = orderDetailId,
            cookingStatus = dto.CookingStatus
        });
    }

    /// <summary>
    /// PUT /api/kds/order-detail/{orderDetailId}/status
    /// Alternative route for Flutter mobile client compatibility.
    /// </summary>
    [HttpPut("order-detail/{orderDetailId:int}/status")]
    public async Task<IActionResult> UpdateCookingStatusAlt(int orderDetailId, [FromBody] UpdateCookingStatusDto dto)
    {
        return await UpdateCookingStatus(orderDetailId, dto);
    }
}

public class UpdateCookingStatusDto
{
    public int CookingStatus { get; set; }
}
