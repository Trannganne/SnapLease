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

        var utcNow = DateTime.UtcNow;
        var holds = await db.GiuCho.Include(x => x.ChiTiet).Where(x =>
            x.TrangThai == "DANG_GIU" && x.HetHanLuc <= utcNow).ToListAsync(ct);
        
        int holdCount = 0;
        foreach (var hold in holds) 
        {
            await using var tx = await db.Database.BeginTransactionAsync(System.Data.IsolationLevel.ReadCommitted, ct);
            try
            {
                hold.TrangThai = "HET_HAN";
                var cartLineIds = hold.ChiTiet.Where(x => x.MaChiTietGioHang != null).Select(x => x.MaChiTietGioHang).ToList();
                if (cartLineIds.Any())
                {
                    var cartLines = await db.ChiTietGioHang
                        .Where(x => cartLineIds.Contains(x.MaChiTietGioHang) && x.NguonTao == "THUE_NGAY")
                        .ToListAsync(ct);
                    
                    if (cartLines.Any())
                    {
                        db.ChiTietGioHang.RemoveRange(cartLines);
                    }
                }
                await db.SaveChangesAsync(ct);
                await tx.CommitAsync(ct);
                holdCount++;
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Failed to expire hold {MaGiuCho}", hold.MaGiuCho);
                db.ChangeTracker.Clear();
            }
        }

        var contracts = await db.HopDong.Where(x =>
            x.TrangThai == "CHO_KY" && x.NgayTaoHopDong <= signCutoff).ToListAsync(ct);
        
        int contractCount = 0;
        foreach (var contract in contracts) 
        {
            try
            {
                contract.TrangThai = "DA_HUY";
                await db.SaveChangesAsync(ct);
                contractCount++;
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Failed to expire contract {MaHopDong}", contract.MaHopDong);
                db.ChangeTracker.Clear();
            }
        }

        if (holdCount > 0 || contractCount > 0)
        {
            logger.LogInformation("Đã hết hạn {HoldCount} giữ chỗ và hủy {ContractCount} hợp đồng quá hạn ký.",
                holdCount, contractCount);
        }
    }
}
