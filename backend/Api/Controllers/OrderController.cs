using Microsoft.AspNetCore.Authorization;
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
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER,WAITER,MEMBER")]
    public async Task<IActionResult> CreateOrder([FromBody] CreateOrderDto dto)
    {
        if (dto == null)
        {
            return BadRequest(new { statusCode = 400, message = "Dữ liệu đơn hàng không hợp lệ" });
        }

        var result = await Provider.Order.CreateOrderAsync(dto);
        if (!result.Success)
        {
            return BadRequest(new { statusCode = 400, success = false, message = result.Message, error = result.Message });
        }

        return Ok(new
        {
            statusCode = 200,
            success = true,
            message = result.Message,
            orderId = result.Order?.OrderId,
            orderCode = result.Order?.OrderCode,
            totalAmount = result.Order?.TotalAmount,
            discountAmount = result.Order?.DiscountAmount,
            finalAmount = result.Order?.FinalAmount,
            tableId = result.Order?.TableId,
            data = result.Order
        });
    }

    /// <summary>
    /// GET /api/order/admin
    /// Retrieves order management list for Admin & Cashier with date, status, and search filters.
    /// </summary>
    [HttpGet("admin")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER")]
    public async Task<IActionResult> GetAdminOrders(
        [FromQuery] DateTime? fromDate,
        [FromQuery] DateTime? toDate,
        [FromQuery] int? status,
        [FromQuery] string? search)
    {
        var orders = await Provider.Order.GetOrdersAsync(status, fromDate, toDate, search);
        decimal totalRevenue = orders.Where(o => o.PaymentStatus == 1).Sum(o => o.FinalAmount);

        return Ok(new
        {
            totalOrders = orders.Count,
            totalRevenue = totalRevenue,
            orders = orders
        });
    }

    /// <summary>
    /// GET /api/order
    /// Retrieves list of orders with optional status, date-range, and keyword filters.
    /// </summary>
    [HttpGet]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER,WAITER")]
    public async Task<IActionResult> GetOrders(
        [FromQuery] int? status = null,
        [FromQuery] DateTime? fromDate = null,
        [FromQuery] DateTime? toDate = null,
        [FromQuery] string? search = null)
    {
        var result = await Provider.Order.GetOrdersAsync(status, fromDate, toDate, search);
        return Ok(result);
    }

    /// <summary>
    /// GET /api/order/{id}
    /// Retrieves single order details including table name and itemized list.
    /// </summary>
    [HttpGet("{id:int}")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER,WAITER,MEMBER")]
    public async Task<IActionResult> GetOrderById(int id)
    {
        var order = await Provider.Order.GetOrderByIdAsync(id);
        if (order == null)
        {
            return NotFound(new { statusCode = 404, success = false, message = $"Không tìm thấy đơn hàng #{id}" });
        }
        return Ok(order);
    }

    /// <summary>
    /// PUT /api/order/{id}/status
    /// Updates order status (0: New, 1: Cooking, 2: Served, 3: Completed, 4: Cancelled).
    /// </summary>
    [HttpPut("{id:int}/status")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER,WAITER")]
    public async Task<IActionResult> UpdateStatus(int id, [FromBody] UpdateStatusDto dto)
    {
        var result = await Provider.Order.UpdateOrderStatusAsync(id, dto.Status);
        if (!result.Success)
        {
            return BadRequest(new { statusCode = 400, success = false, message = result.Message });
        }
        return Ok(new { statusCode = 200, success = true, message = result.Message, status = dto.Status });
    }

    /// <summary>
    /// GET /api/order/by-table/{tableId}
    /// Retrieves current active order for the specified table.
    /// </summary>
    [HttpGet("by-table/{tableId:int}")]
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

    /// <summary>
    /// POST /api/order/{id}/add-items
    /// Thêm món ăn vào đơn hàng đang phục vụ
    /// </summary>
    [HttpPost("{id:int}/add-items")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER,WAITER")]
    public async Task<IActionResult> AddItems(int id, [FromBody] List<CreateOrderItemDto> items)
    {
        if (items == null || items.Count == 0)
        {
            return BadRequest(new { statusCode = 400, success = false, message = "Vui lòng chọn ít nhất 1 món để thêm vào đơn" });
        }

        var result = await Provider.Order.AddItemsToOrderAsync(id, items);
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
}

public class UpdateStatusDto
{
    public int Status { get; set; }
}
