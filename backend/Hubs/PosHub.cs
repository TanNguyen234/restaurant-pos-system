using Microsoft.AspNetCore.SignalR;

namespace WebApi.Hubs;

/// <summary>
/// SignalR Hub điều phối sự kiện thời gian thực giữa Phục vụ, Bếp KDS, Thu ngân và Quản trị viên.
/// </summary>
public class PosHub : Hub
{
    public const string AllChannel = "pos_all";

    public override async Task OnConnectedAsync()
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, AllChannel);
        await base.OnConnectedAsync();
    }

    public async Task JoinChannel(string channel)
    {
        if (!string.IsNullOrWhiteSpace(channel))
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, channel.Trim());
        }
    }
}
