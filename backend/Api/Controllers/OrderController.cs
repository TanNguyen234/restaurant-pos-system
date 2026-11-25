using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebApi.Models;

namespace WebApi.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class OrderController : BaseController
{
    private int? GetCallerAccountId()
    {
        var claim = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("accountId");
        return int.TryParse(claim, out int id) && id > 0 ? id : null;
    }

    private bool IsStaffUser() =>
        User.IsInRole("ADMIN") || User.IsInRole("MANAGER") || User.IsInRole("CASHIER") || User.IsInRole("WAITER") || User.IsInRole("KITCHEN");

    [HttpPost]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER,WAITER,MEMBER")]
    public async Task<IActionResult> CreateOrder([FromBody] CreateOrderDto dto)
    {
        if (dto == null)
        {
            return BadRequest(new { statusCode = 400, success = false, message = "Dữ liệu đơn hàng không hợp lệ" });
        }

        var result = await Provider.Order.CreateOrderAsync(dto, GetCallerAccountId());
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

    [HttpGet("admin")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER")]
    public async Task<IActionResult> GetAdminOrders(
        [FromQuery] DateTime? fromDate,
        [FromQuery] DateTime? toDate,
        [FromQuery] int? status,
        [FromQuery] string? search)
    {
        var orders = await Provider.Order.GetOrdersAsync(status, fromDate, toDate, search);
        var topProducts = await Provider.Order.GetTopSellingProductsAsync(fromDate, toDate, 5);
        decimal totalRevenue = orders
            .Where(o => o.PaymentStatus == 1 && o.Status != 4)
            .Sum(o => o.FinalAmount);

        return Ok(new
        {
            totalOrders = orders.Count,
            totalRevenue,
            orders,
            topProducts
        });
    }

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

    [HttpGet("lookup")]
    [Authorize]
    public async Task<IActionResult> LookupOrders([FromQuery] string? query = null)
    {
        var result = await Provider.Order.LookupOrdersAsync(query, GetCallerAccountId(), IsStaffUser());
        return Ok(new
        {
            statusCode = 200,
            success = true,
            total = result.Count,
            items = result,
            data = result
        });
    }

    [HttpGet("{id:int}")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER,WAITER,MEMBER")]
    public async Task<IActionResult> GetOrderById(int id)
    {
        var order = await Provider.Order.GetOrderByIdAsync(id);
        if (order == null)
        {
            return NotFound(new { statusCode = 404, success = false, message = $"Không tìm thấy đơn hàng #{id}" });
        }

        if (!IsStaffUser())
        {
            int? callerId = GetCallerAccountId();
            if (order.AccountId.HasValue && callerId.HasValue && order.AccountId.Value != callerId.Value)
            {
                return Forbid();
            }
        }

        return Ok(order);
    }

    [HttpPut("{id:int}/status")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER,WAITER")]
    public async Task<IActionResult> UpdateStatus(int id, [FromBody] UpdateStatusDto dto)
    {
        bool canCompleteOrCancel = User.IsInRole("ADMIN") || User.IsInRole("MANAGER") || User.IsInRole("CASHIER");
        var result = await Provider.Order.UpdateOrderStatusAsync(id, dto.Status, canCompleteOrCancel);
        if (!result.Success)
        {
            return BadRequest(new { statusCode = 400, success = false, message = result.Message });
        }
        return Ok(new { statusCode = 200, success = true, message = result.Message, status = dto.Status });
    }

    [HttpPut("{id:int}/discount")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER")]
    public async Task<IActionResult> ApplyDiscount(int id, [FromBody] ApplyDiscountDto dto)
    {
        if (dto == null)
        {
            return BadRequest(new { statusCode = 400, success = false, message = "Thông tin chiết khấu không hợp lệ" });
        }

        var result = await Provider.Order.ApplyManualDiscountAsync(id, dto);
        if (!result.Success)
        {
            return BadRequest(new { statusCode = 400, success = false, message = result.Message });
        }

        return Ok(new { statusCode = 200, success = true, message = result.Message, data = result.Order });
    }

    [HttpGet("by-table/{tableId:int}")]
    [Authorize]
    public async Task<IActionResult> GetByTable(int tableId)
    {
        var table = Provider.Table.GetById(tableId);
        if (table == null)
        {
            return NotFound(new { statusCode = 404, success = false, message = "Không tìm thấy bàn ăn" });
        }

        var order = await Provider.Order.GetActiveOrderByTableIdAsync(tableId);
        if (order == null)
        {
            return Ok(new { statusCode = 200, hasActiveOrder = false, message = "Bàn hiện đang trống, chưa có đơn" });
        }

        return Ok(new { statusCode = 200, hasActiveOrder = true, data = order });
    }

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

    [HttpPost("{id:int}/void-item")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER,WAITER")]
    public async Task<IActionResult> VoidItem(int id, [FromBody] VoidItemDto dto)
    {
        if (dto == null || dto.OrderDetailId <= 0)
        {
            return BadRequest(new { statusCode = 400, success = false, message = "Thông tin món cần hủy không hợp lệ" });
        }

        string reason = string.IsNullOrWhiteSpace(dto.Reason) ? "Khách đổi ý / Không dùng nữa" : dto.Reason.Trim();
        var result = await Provider.Order.VoidOrderItemAsync(id, dto.OrderDetailId, reason, dto.VoidQuantity);
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
