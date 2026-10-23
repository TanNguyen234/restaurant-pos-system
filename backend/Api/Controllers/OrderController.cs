using Microsoft.AspNetCore.Mvc;
using WebApi.Models;

namespace WebApi.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class OrderController : BaseController
{
    /// <summary>
    /// POST /api/order
    /// Creates a new order or processes an offline order sync with server-calculated totals.
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> CreateOrder([FromBody] CreateOrderDto dto)
    {
        if (dto == null)
        {
            return BadRequest(new { statusCode = 400, message = "Dữ liệu đơn hàng không hợp lệ" });
        }

        var result = await Provider.Order.CreateOrderAsync(dto);
        if (!result.Success)
        {
            return BadRequest(new { statusCode = 400, success = false, message = result.Message });
        }

        return Ok(new
        {
            statusCode = 200,
            success = true,
            message = result.Message,
            data = result.Order
        });
    }

    /// <summary>
    /// GET /api/order
    /// Retrieves paginated list of orders with optional status, date-range, and keyword filters.
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetOrders(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 10,
        [FromQuery] int? status = null,
        [FromQuery] int? paymentStatus = null,
        [FromQuery] DateTime? fromDate = null,
        [FromQuery] DateTime? toDate = null,
        [FromQuery] string? search = null)
    {
        var result = await Provider.Order.GetOrdersAsync(page, pageSize, status, paymentStatus, fromDate, toDate, search);
        return Ok(result);
    }

    /// <summary>
    /// GET /api/order/{id}
    /// Retrieves single order details including table name and itemized list.
    /// </summary>
    [HttpGet("{id}")]
    public async Task<IActionResult> GetOrderById(int id)
    {
        var order = await Provider.Order.GetOrderByIdAsync(id);
        if (order == null)
        {
            return NotFound(new { statusCode = 404, message = "Không tìm thấy đơn hàng" });
        }
        return Ok(order);
    }

    /// <summary>
    /// PUT /api/order/{id}/status
    /// Updates order status (0: New, 1: Cooking, 2: Served, 3: Completed, 4: Cancelled).
    /// </summary>
    [HttpPut("{id}/status")]
    public async Task<IActionResult> UpdateStatus(int id, [FromBody] UpdateStatusDto dto)
    {
        var result = await Provider.Order.UpdateOrderStatusAsync(id, dto.Status);
        if (!result.Success)
        {
            return BadRequest(new { statusCode = 400, success = false, message = result.Message });
        }
        return Ok(new { statusCode = 200, success = true, message = result.Message });
    }

    /// <summary>
    /// GET /api/order/by-table/{tableId}
    /// Retrieves current active order for the specified table.
    /// </summary>
    [HttpGet("by-table/{tableId}")]
    public async Task<IActionResult> GetByTable(int tableId)
    {
        var table = Provider.Table.GetById(tableId);
        if (table == null)
        {
            return NotFound(new { statusCode = 404, message = "Không tìm thấy bàn ăn" });
        }

        if (!table.CurrentOrderId.HasValue)
        {
            return Ok(new { statusCode = 200, hasActiveOrder = false, message = "Bàn hiện đang trống, chưa có đơn" });
        }

        var order = await Provider.Order.GetOrderByIdAsync(table.CurrentOrderId.Value);
        return Ok(new { statusCode = 200, hasActiveOrder = true, data = order });
    }
}

public class UpdateStatusDto
{
    public int Status { get; set; }
}
