using WebApi.Models;

namespace WebApi.Services;

/// <summary>
/// Tác vụ nền chạy định kỳ mỗi 60 giây để:
/// 1) Tự động khóa bàn (Status = 3) khi sắp đến giờ đặt bàn (trong vòng 60 phút tới).
/// 2) Tự động chuyển đặt bàn quá hạn (ExpiresAt &lt;= now) sang NoShow (Status = 4) và nhả bàn.
/// </summary>
public class ReservationExpirationService : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly PosRealtimeNotifier _realtime;
    private readonly ILogger<ReservationExpirationService> _logger;

    public ReservationExpirationService(
        IServiceScopeFactory scopeFactory,
        PosRealtimeNotifier realtime,
        ILogger<ReservationExpirationService> logger)
    {
        _scopeFactory = scopeFactory;
        _realtime = realtime;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        try
        {
            await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
        }
        catch (OperationCanceledException)
        {
            return;
        }

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = _scopeFactory.CreateScope();
                var db = scope.ServiceProvider.GetRequiredService<RestaurantPosContext>();
                var repo = new TableRepository(db);
                var sync = repo.SyncReservationStates();

                if (sync.ChangedTableIds.Count > 0)
                {
                    await _realtime.NotifyTableChangedAsync(new
                    {
                        action = "ReservationAutoSync",
                        expiredCount = sync.ExpiredCount,
                        lockedCount = sync.LockedCount,
                        tableIds = sync.ChangedTableIds
                    });
                }
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                _logger.LogDebug(ex, "ReservationExpirationService tick skipped");
            }

            try
            {
                await Task.Delay(TimeSpan.FromSeconds(60), stoppingToken);
            }
            catch (OperationCanceledException)
            {
                break;
            }
        }
    }
}
