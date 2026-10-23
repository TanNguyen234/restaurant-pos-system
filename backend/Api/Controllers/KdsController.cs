using Microsoft.AspNetCore.Mvc;
using WebApi.Models;

namespace WebApi.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class KdsController : BaseController
{
    /// <summary>
    /// GET /api/kds/active-orders
    /// Lấy danh sách các món ăn / đồ uống đang cần chế biến cho màn hình Bếp & Pha chế
    /// </summary>
    [HttpGet("active-orders")]
    public IActionResult GetActiveOrders()
    {
        var items = Provider.Order.GetKdsActiveItems();
        return Ok(items);
    }

    /// <summary>
    /// PUT /api/kds/order-detail/{id}/status
    /// Cập nhật trạng thái nấu của món ăn (0: Chờ nấu -> 1: Đang làm -> 2: Đã nấu xong)
    /// </summary>
    [HttpPut("order-detail/{id:int}/status")]
    public IActionResult UpdateCookingStatus(int id, [FromBody] UpdateCookingStatusRequest request)
    {
        if (request == null)
        {
            return BadRequest(new { success = false, message = "Dữ liệu trạng thái không hợp lệ" });
        }

        var result = Provider.Order.UpdateCookingStatus(id, request.CookingStatus);
        if (!result.Success)
        {
            return BadRequest(new { success = false, message = result.Message });
        }

        return Ok(new
        {
            success = true,
            message = result.Message,
            orderDetailId = id,
            cookingStatus = request.CookingStatus
        });
    }
}

public class UpdateCookingStatusRequest
{
    public int CookingStatus { get; set; }
}
