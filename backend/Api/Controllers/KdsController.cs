using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebApi.Models;
using WebApi.Services;

namespace WebApi.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "ADMIN,MANAGER,KITCHEN,HEAD_CHEF,BARISTA_LEAD,COOK_ASSISTANT")]
public class KdsController : BaseController
{
    private readonly PosRealtimeNotifier _realtime;

    public KdsController(PosRealtimeNotifier realtime)
    {
        _realtime = realtime;
    }
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

    [HttpGet("active-orders")]
    public async Task<IActionResult> GetActiveOrders()
    {
        var items = await Provider.Order.GetKdsItemsAsync();
        return Ok(items);
    }

    /// <summary>
    /// PUT /api/kds/{orderDetailId}/status
    /// Updates cooking status: 0 = Pending, 1 = Cooking, 2 = Ready, 3 = Served
    /// </summary>
    [HttpPut("{orderDetailId:int}/status")]
    [HttpPut("order-detail/{orderDetailId:int}/status")]
    public async Task<IActionResult> UpdateCookingStatus(int orderDetailId, [FromBody] UpdateCookingStatusDto dto)
    {
        if (dto == null || dto.CookingStatus < 0 || dto.CookingStatus > 3)
        {
            return BadRequest(new { statusCode = 400, success = false, message = "Trạng thái chế biến không hợp lệ (0: Chờ nấu, 1: Đang nấu, 2: Đã xong, 3: Đã giao)" });
        }

        var result = await Provider.Order.UpdateCookingStatusAsync(orderDetailId, dto.CookingStatus);
        if (!result.Success)
        {
            return BadRequest(new { statusCode = 400, success = false, message = result.Message });
        }

        await _realtime.NotifyKdsChangedAsync(new { orderDetailId, cookingStatus = dto.CookingStatus });
        await _realtime.NotifyOrderChangedAsync("KdsCookingStatus", new { orderDetailId, cookingStatus = dto.CookingStatus });

        return Ok(new
        {
            statusCode = 200,
            success = true,
            message = result.Message,
            orderDetailId,
            cookingStatus = dto.CookingStatus
        });
    }

    /// <summary>
    /// POST /api/kds/{orderDetailId}/void
    /// Báo hủy món từ màn hình Bếp kèm lý do và tự động tính lại tổng tiền đơn hàng
    /// </summary>
    [HttpPost("{orderDetailId:int}/void")]
    public async Task<IActionResult> VoidFromKitchen(int orderDetailId, [FromBody] KitchenVoidDto? dto = null)
    {
        string reason = string.IsNullOrWhiteSpace(dto?.Reason) ? "Bếp báo hết nguyên liệu" : dto.Reason.Trim();
        int voidQty = dto?.VoidQuantity ?? 0;

        var result = await Provider.Order.VoidDetailByIdAsync(orderDetailId, reason, voidQty);
        if (!result.Success)
        {
            return BadRequest(new { statusCode = 400, success = false, message = result.Message });
        }

        await _realtime.NotifyKdsChangedAsync(new { orderDetailId, voided = true });
        await _realtime.NotifyOrderChangedAsync("OrderVoided", result.Order);

        return Ok(new
        {
            statusCode = 200,
            success = true,
            message = result.Message,
            data = result.Order
        });
    }
}

public class UpdateCookingStatusDto
{
    public int CookingStatus { get; set; }
}

public class KitchenVoidDto
{
    public string? Reason { get; set; }
    public int VoidQuantity { get; set; } = 0;
}
