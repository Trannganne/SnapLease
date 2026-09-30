using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;

namespace RentalCamera.Api.Rental;

public sealed class ReservationExpirationService(
    IServiceScopeFactory scopeFactory,
    IConfiguration configuration,
    ILogger<ReservationExpirationService> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(30));
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await ExpireAsync(stoppingToken);
                await timer.WaitForNextTickAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Không thể đồng bộ giữ chỗ/hợp đồng hết hạn.");
                await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken);
            }
        }
    }

    private async Task ExpireAsync(CancellationToken ct)
    {
        await using var scope = scopeFactory.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<RentalCameraContext>();
        var now = DateTime.Now;
        var signMinutes = Math.Clamp(configuration.GetValue("Rental:ContractSignMinutes", 30), 1, 1440);
        var signCutoff = now.AddMinutes(-signMinutes);

        var holds = await db.GiuCho.Where(x =>
            x.TrangThai == "DANG_GIU" && x.HetHanLuc <= now).ToListAsync(ct);
        foreach (var hold in holds) hold.TrangThai = "HET_HAN";

        var contracts = await db.HopDong.Where(x =>
            x.TrangThai == "CHO_KY" && x.NgayTaoHopDong <= signCutoff).ToListAsync(ct);
        foreach (var contract in contracts) contract.TrangThai = "DA_HUY";

        if (holds.Count > 0 || contracts.Count > 0)
        {
            await db.SaveChangesAsync(ct);
            logger.LogInformation("Đã hết hạn {HoldCount} giữ chỗ và hủy {ContractCount} hợp đồng quá hạn ký.",
                holds.Count, contracts.Count);
        }
    }
}
