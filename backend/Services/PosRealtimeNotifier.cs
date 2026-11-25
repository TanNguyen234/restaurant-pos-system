using Microsoft.AspNetCore.SignalR;
using WebApi.Hubs;

namespace WebApi.Services;

/// <summary>
/// Dịch vụ phát sự kiện SignalR an toàn (fire-and-forget không làm gián đoạn giao dịch chính).
/// </summary>
public class PosRealtimeNotifier
{
    private readonly IHubContext<PosHub> _hubContext;

    public PosRealtimeNotifier(IHubContext<PosHub> hubContext)
    {
        _hubContext = hubContext;
    }

    private async Task BroadcastAsync(string method, object payload)
    {
        try
        {
            await _hubContext.Clients.Group(PosHub.AllChannel).SendAsync(method, payload);
        }
        catch
        {
            // Realtime push is best-effort; persistent DB transaction stays authoritative.
        }
    }

    public Task NotifyOrderChangedAsync(string eventType, object? payload = null) =>
        BroadcastAsync("OrderEvent", new
        {
            eventType,
            timestamp = DateTime.Now,
            data = payload
        });

    public Task NotifyKdsChangedAsync(object? payload = null) =>
        BroadcastAsync("KdsUpdated", new
        {
            timestamp = DateTime.Now,
            data = payload
        });

    public Task NotifyTableChangedAsync(object? payload = null) =>
        BroadcastAsync("TableUpdated", new
        {
            timestamp = DateTime.Now,
            data = payload
        });

    public Task NotifyInventoryAlertAsync(object? payload = null) =>
        BroadcastAsync("InventoryAlert", new
        {
            timestamp = DateTime.Now,
            data = payload
        });
}
