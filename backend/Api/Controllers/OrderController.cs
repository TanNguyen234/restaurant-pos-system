using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using WebApi.Models;

namespace WebApi.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class OrderController : BaseController
{
    /// <summary>
    /// POST /api/order
    /// Tạo đơn hàng mới từ giỏ hàng (Mobile / Web POS)
    /// </summary>
    [HttpPost]
    public IActionResult CreateOrder([FromBody] CreateOrderRequest request)
    {
        if (request == null || request.Items == null || request.Items.Count == 0)
        {
            return BadRequest(new { statusCode = 400, error = "Giỏ hàng không có món nào để tạo đơn" });
        }

        // Server owns the identity and discount authorization.
        request.AccountId = int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var currentId) ? currentId : null;
        if (!User.IsInRole("ADMIN") && !User.IsInRole("MANAGER"))
            request.DiscountAmount = 0;
        var result = Provider.Order.CreateOrder(request);
        if (!result.Success)
        {
            return BadRequest(new { statusCode = 400, error = result.Message });
        }

        var order = result.Order!;
        return Ok(new
        {
            statusCode = 200,
            orderId = order.OrderId,
            orderCode = order.OrderCode,
            totalAmount = order.TotalAmount,
            discountAmount = order.DiscountAmount,
            finalAmount = order.FinalAmount,
            tableId = order.TableId,
            message = result.Message
        });
    }

    /// <summary>
    /// GET /api/order/admin
    /// Lấy danh sách quản trị đơn hàng kèm bộ lọc ngày, trạng thái, tìm kiếm
    /// </summary>
    [HttpGet("admin")]
    public IActionResult GetAdminOrders(
        [FromQuery] DateTime? fromDate,
        [FromQuery] DateTime? toDate,
        [FromQuery] int? status,
        [FromQuery] string? search,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50)
    {
        var result = Provider.Order.GetAdminOrders(fromDate, toDate, status, search, page, pageSize);
        return Ok(result);
    }

    /// <summary>
    /// GET /api/order/{id}
    /// Lấy chi tiết đơn hàng theo ID kèm danh sách món
    /// </summary>
    [HttpGet("{id:int}")]
    public IActionResult GetById(int id)
    {
        var order = Provider.Order.GetOrderById(id);
        if (order == null)
        {
            return NotFound(new { success = false, message = $"Không tìm thấy đơn hàng #{id}" });
        }
        return Ok(order);
    }

    /// <summary>
    /// GET /api/order/by-table/{tableId}
    /// Lấy đơn hàng đang hoạt động của bàn ăn
    /// </summary>
    [HttpGet("by-table/{tableId:int}")]
    public IActionResult GetByTable(int tableId)
    {
        var order = Provider.Order.GetActiveOrderByTable(tableId);
        if (order == null)
        {
            return NotFound(new { success = false, message = $"Bàn #{tableId} hiện không có đơn hàng đang hoạt động" });
        }
        return Ok(order);
    }

    /// <summary>
    /// PUT /api/order/{id}/status
    /// Cập nhật trạng thái đơn hàng (0: Mới, 1: Đang nấu, 2: Đã phục vụ, 3: Hoàn thành, 4: Hủy)
    /// </summary>
    [HttpPut("{id:int}/status")]
    public IActionResult UpdateStatus(int id, [FromBody] UpdateOrderStatusRequest request)
    {
        if (request == null)
        {
            return BadRequest(new { success = false, message = "Dữ liệu trạng thái không hợp lệ" });
        }

        var result = Provider.Order.UpdateOrderStatus(id, request.Status);
        if (!result.Success)
        {
            return BadRequest(new { success = false, message = result.Message });
        }

        return Ok(new { success = true, message = result.Message, status = request.Status });
    }
}

public class UpdateOrderStatusRequest
{
    public int Status { get; set; }
}
