using System.Collections.Concurrent;
using System.Security.Claims;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebApi.Models;
using WebApi.Services;

namespace WebApi.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class OrderController : BaseController
{
    private readonly PosRealtimeNotifier _realtime;
    private static readonly ConcurrentDictionary<string, Queue<DateTime>> _qrRateLimits = new();

    public OrderController(PosRealtimeNotifier realtime)
    {
        _realtime = realtime;
    }

    private int? GetCallerAccountId()
    {
        var claim = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("accountId");
        return int.TryParse(claim, out int id) && id > 0 ? id : null;
    }

    private bool IsStaffUser() =>
        User.IsInRole("ADMIN") || User.IsInRole("MANAGER") || User.IsInRole("CASHIER") || User.IsInRole("WAITER") || User.IsInRole("KITCHEN");

    private string? ReadGuestToken(string? bodyToken = null)
    {
        var hdr = Request.Headers["X-Guest-Token"].FirstOrDefault();
        return !string.IsNullOrWhiteSpace(hdr) ? hdr.Trim() : (string.IsNullOrWhiteSpace(bodyToken) ? null : bodyToken.Trim());
    }

    private async Task BroadcastInventorySideEffectsAsync(OrderRepository repo)
    {
        if (repo.LastLowStockAlerts.Count > 0 || repo.LastAvailabilityChanges.Count > 0)
        {
            await _realtime.NotifyInventoryAlertAsync(new
            {
                action = "OrderStockSync",
                lowStockAlerts = repo.LastLowStockAlerts,
                availabilityChanges = repo.LastAvailabilityChanges
            });
        }
        if (repo.LastAvailabilityChanges.Count > 0)
        {
            await _realtime.NotifyKdsChangedAsync(new { availabilityChanges = repo.LastAvailabilityChanges });
        }
    }

    [HttpPost]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER,WAITER,MEMBER,VIP_MEMBER")]
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

        await _realtime.NotifyOrderChangedAsync("OrderCreated", result.Order);
        await _realtime.NotifyKdsChangedAsync(new { orderId = result.Order?.OrderId });
        if (result.Order?.TableId != null)
        {
            await _realtime.NotifyTableChangedAsync(new { tableId = result.Order.TableId });
        }
        await BroadcastInventorySideEffectsAsync(Provider.Order);

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
            guestToken = result.Order?.GuestAccessToken,
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
    [AllowAnonymous]
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
            if (order.AccountId.HasValue)
            {
                if (!callerId.HasValue) return Unauthorized(new { statusCode = 401, success = false, message = "Vui lòng đăng nhập để xem đơn hàng" });
                if (order.AccountId.Value != callerId.Value) return Forbid();
            }
            else
            {
                bool validGuest = await Provider.Order.VerifyGuestTokenAsync(id, ReadGuestToken());
                if (!validGuest)
                {
                    if (!callerId.HasValue)
                        return Unauthorized(new { statusCode = 401, success = false, message = "Thiếu mã xác thực đơn khách vãng lai" });
                    return Forbid();
                }
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

        await _realtime.NotifyOrderChangedAsync("OrderStatusUpdated", new { orderId = id, status = dto.Status, tableId = result.TableId });
        if (dto.Status == 4)
        {
            await _realtime.NotifyKdsChangedAsync(new { orderId = id, cancelled = true });
        }
        if (result.TableId.HasValue && (dto.Status == 3 || dto.Status == 4))
        {
            await _realtime.NotifyTableChangedAsync(new { tableId = result.TableId.Value });
        }
        await BroadcastInventorySideEffectsAsync(Provider.Order);

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

        await _realtime.NotifyOrderChangedAsync("OrderUpdated", result.Order);
        return Ok(new { statusCode = 200, success = true, message = result.Message, data = result.Order });
    }

    [HttpGet("by-table/{tableId:int}")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER,WAITER,KITCHEN")]
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
    public async Task<IActionResult> AddItems(int id, [FromBody] JsonElement body)
    {
        var jsonOpts = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
        List<CreateOrderItemDto> items;
        string? idempotencyKey = Request.Headers["X-Idempotency-Key"].FirstOrDefault();
        string? discountCode = null;

        if (body.ValueKind == JsonValueKind.Array)
        {
            items = JsonSerializer.Deserialize<List<CreateOrderItemDto>>(body.GetRawText(), jsonOpts) ?? new();
        }
        else if (body.ValueKind == JsonValueKind.Object)
        {
            var req = JsonSerializer.Deserialize<AddOrderItemsRequestDto>(body.GetRawText(), jsonOpts);
            items = req?.Items ?? new();
            idempotencyKey ??= req?.IdempotencyKey;
            discountCode = req?.DiscountCode;
        }
        else
        {
            return BadRequest(new { statusCode = 400, success = false, message = "Định dạng danh sách món không hợp lệ" });
        }

        if (items.Count == 0)
        {
            return BadRequest(new { statusCode = 400, success = false, message = "Vui lòng chọn ít nhất 1 món để thêm vào đơn" });
        }

        var result = await Provider.Order.AddItemsToOrderAsync(id, items, idempotencyKey, discountCode, GetCallerAccountId());
        if (!result.Success)
        {
            return BadRequest(new { statusCode = 400, success = false, message = result.Message });
        }

        await _realtime.NotifyOrderChangedAsync("OrderUpdated", result.Order);
        await _realtime.NotifyKdsChangedAsync(new { orderId = id });
        await BroadcastInventorySideEffectsAsync(Provider.Order);

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

        await _realtime.NotifyOrderChangedAsync("OrderVoided", result.Order);
        await _realtime.NotifyKdsChangedAsync(new { orderId = id });
        await BroadcastInventorySideEffectsAsync(Provider.Order);

        return Ok(new
        {
            statusCode = 200,
            success = true,
            message = result.Message,
            data = result.Order
        });
    }

    [HttpGet("analytics")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER")]
    public async Task<IActionResult> GetAnalytics(
        [FromQuery] int days = 7,
        [FromQuery] DateTime? fromDate = null,
        [FromQuery] DateTime? toDate = null)
    {
        var analytics = await Provider.Order.GetAnalyticsAsync(days, fromDate, toDate);
        return Ok(analytics);
    }

    [HttpGet("export-csv")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER")]
    public async Task<IActionResult> ExportCsv(
        [FromQuery] DateTime? fromDate = null,
        [FromQuery] DateTime? toDate = null,
        [FromQuery] int? status = null,
        [FromQuery] string? search = null)
    {
        var csv = await Provider.Order.ExportOrdersCsvAsync(fromDate, toDate, status, search);
        var bom = new byte[] { 0xEF, 0xBB, 0xBF };
        var body = Encoding.UTF8.GetBytes(csv);
        var bytes = new byte[bom.Length + body.Length];
        Buffer.BlockCopy(bom, 0, bytes, 0, bom.Length);
        Buffer.BlockCopy(body, 0, bytes, bom.Length, body.Length);
        return File(bytes, "text/csv; charset=utf-8", $"orders_report_{DateTime.Now:yyyyMMdd_HHmm}.csv");
    }

    [HttpPost("qr-self-order")]
    [AllowAnonymous]
    public async Task<IActionResult> CreateQrSelfOrder([FromBody] CreateOrderDto dto)
    {
        if (dto == null || !dto.TableId.HasValue || dto.TableId.Value <= 0)
        {
            return BadRequest(new { statusCode = 400, success = false, message = "Thiếu mã bàn QR hợp lệ" });
        }
        if (dto.Items == null || dto.Items.Count == 0)
        {
            return BadRequest(new { statusCode = 400, success = false, message = "Vui lòng chọn ít nhất 1 món để gọi tại bàn" });
        }

        string clientIp = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown";
        string rateKey = $"{clientIp}:T{dto.TableId.Value}";
        var q = _qrRateLimits.GetOrAdd(rateKey, _ => new Queue<DateTime>());
        lock (q)
        {
            var cutoff = DateTime.UtcNow.AddMinutes(-1);
            while (q.Count > 0 && q.Peek() < cutoff) q.Dequeue();
            if (q.Count >= 8)
            {
                return StatusCode(429, new { statusCode = 429, success = false, message = "Bạn gửi đơn QR quá nhanh, vui lòng đợi 1 phút." });
            }
            q.Enqueue(DateTime.UtcNow);
        }

        var table = Provider.Table.GetById(dto.TableId.Value);
        if (table == null)
        {
            return NotFound(new { statusCode = 404, success = false, message = $"Không tìm thấy bàn #{dto.TableId.Value}" });
        }

        int? callerId = GetCallerAccountId();
        var activeOrder = await Provider.Order.GetActiveOrderByTableIdAsync(table.TableId);
        (bool Success, string Message, OrderDto? Order) result;
        if (activeOrder != null)
        {
            result = await Provider.Order.AddItemsToOrderAsync(
                activeOrder.OrderId,
                dto.Items,
                dto.IdempotencyKey,
                dto.DiscountCode,
                callerId);
        }
        else
        {
            dto.OrderType = 1;
            dto.CustomerName = string.IsNullOrWhiteSpace(dto.CustomerName)
                ? $"Khách QR - {table.TableName}"
                : dto.CustomerName.Trim();
            dto.Note = string.IsNullOrWhiteSpace(dto.Note)
                ? "[QR Self-Order]"
                : $"[QR Self-Order] {dto.Note.Trim()}";
            result = await Provider.Order.CreateOrderAsync(dto, callerId);
        }

        if (!result.Success)
        {
            return BadRequest(new { statusCode = 400, success = false, message = result.Message });
        }

        await _realtime.NotifyOrderChangedAsync("QrSelfOrder", result.Order);
        await _realtime.NotifyKdsChangedAsync(new { orderId = result.Order?.OrderId, tableId = table.TableId });
        await _realtime.NotifyTableChangedAsync(new { tableId = table.TableId });
        await BroadcastInventorySideEffectsAsync(Provider.Order);

        return Ok(new
        {
            statusCode = 200,
            success = true,
            message = $"Đã gửi đơn QR cho {table.TableName} xuống Bếp KDS!",
            orderId = result.Order?.OrderId,
            orderCode = result.Order?.OrderCode,
            totalAmount = result.Order?.TotalAmount,
            discountAmount = result.Order?.DiscountAmount,
            finalAmount = result.Order?.FinalAmount,
            tableId = table.TableId,
            guestToken = result.Order?.GuestAccessToken,
            data = result.Order
        });
    }

    [HttpPost("{id:int}/cancel-unpaid")]
    [AllowAnonymous]
    public async Task<IActionResult> CancelUnpaidOrder(int id, [FromBody] CancelUnpaidRequestDto? body = null)
    {
        var existing = await Provider.Order.GetOrderByIdAsync(id);
        if (existing == null)
        {
            return NotFound(new { statusCode = 404, success = false, message = $"Không tìm thấy đơn hàng #{id}" });
        }

        int? callerId = GetCallerAccountId();
        bool isStaff = IsStaffUser();
        string? guestToken = ReadGuestToken(body?.GuestToken);

        if (existing.AccountId.HasValue && !isStaff)
        {
            if (!callerId.HasValue) return Unauthorized(new { statusCode = 401, success = false, message = "Vui lòng đăng nhập để hủy đơn của bạn" });
            if (callerId.Value != existing.AccountId.Value) return Forbid();
        }

        var result = await Provider.Order.CancelUnpaidOrderAsync(id, callerId, isStaff, guestToken);
        if (result.Forbidden)
        {
            if (!callerId.HasValue)
                return Unauthorized(new { statusCode = 401, success = false, message = result.Message });
            return Forbid();
        }
        if (!result.Success)
        {
            return BadRequest(new { statusCode = 400, success = false, message = result.Message });
        }

        await _realtime.NotifyOrderChangedAsync("OrderCancelled", new { orderId = id, tableId = result.TableId });
        if (result.TableId.HasValue)
        {
            await _realtime.NotifyTableChangedAsync(new { tableId = result.TableId.Value });
        }
        await BroadcastInventorySideEffectsAsync(Provider.Order);

        return Ok(new { statusCode = 200, success = true, message = result.Message, orderId = id, tableId = result.TableId });
    }
}

public class UpdateStatusDto
{
    public int Status { get; set; }
}
