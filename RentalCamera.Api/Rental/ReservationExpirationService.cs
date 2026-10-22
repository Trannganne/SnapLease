using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Contracts;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Rental;

public sealed class ReservationExpirationService(
    IServiceScopeFactory scopeFactory,
    IConfiguration configuration,
    ILogger<ReservationExpirationService> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if(!configuration.GetValue("Rental:BackgroundJobsEnabled",true))return;
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
        var now = RentalPolicy.LocalNow;
        var signMinutes = Math.Clamp(configuration.GetValue("Rental:ContractSignMinutes", 30), 1, 1440);
        var signCutoff = now.AddMinutes(-signMinutes);

        var utcNow = DateTime.UtcNow;
        var holds = await db.GiuCho.AsNoTracking().Where(x =>
            x.TrangThai == "DANG_GIU" && x.HetHanLuc <= utcNow)
            .Select(x=>new{x.MaGiuCho,x.MaKhachThue}).ToListAsync(ct);
        
        int holdCount = 0;
        foreach (var candidate in holds)
        {
            await using var tx = await db.Database.BeginTransactionAsync(System.Data.IsolationLevel.ReadCommitted, ct);
            try
            {
                await TransactionLock.AcquireAsync(db,"cart:"+candidate.MaKhachThue,ct);
                var hold=await db.GiuCho.Include(x=>x.ChiTiet).SingleAsync(x=>x.MaGiuCho==candidate.MaGiuCho,ct);
                if(hold.TrangThai!="DANG_GIU"||hold.HetHanLuc>DateTime.UtcNow)continue;
                hold.TrangThai = "HET_HAN";
                var cartLineIds = hold.ChiTiet.Where(x => x.MaChiTietGioHang != null).Select(x => x.MaChiTietGioHang).ToList();
                if (cartLineIds.Any())
                {
                    var cartLines = await db.ChiTietGioHang
                        .Where(x => cartLineIds.Contains(x.MaChiTietGioHang) && x.NguonTao == "THUE_NGAY")
                        .ToListAsync(ct);
                    
                    if (cartLines.Any())
                    {
                        foreach(var line in cartLines)line.DaChuyenHopDong=true;
                    }
                }
                await db.SaveChangesAsync(ct);
                await tx.CommitAsync(ct);
                holdCount++;
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Failed to expire hold {MaGiuCho}", candidate.MaGiuCho);
            }
            finally { db.ChangeTracker.Clear(); }
        }

        var protectedIds=RentalPolicy.ProtectedContracts.ToArray();
        var contracts = await db.HopDong.AsNoTracking().Where(x =>
            x.TrangThai == "CHO_KY" && x.NgayTaoHopDong <= signCutoff && !protectedIds.Contains(x.MaHopDong))
            .Select(x=>x.MaHopDong).ToListAsync(ct);
        
        int contractCount = 0;
        foreach (var id in contracts)
        {
            try
            {
                await using var tx=await db.Database.BeginTransactionAsync(ct);
                await TransactionLock.AcquireAsync(db,"contract:"+id,ct);
                var contract=await db.HopDong.SingleAsync(x=>x.MaHopDong==id,ct);
                if(contract.TrangThai!="CHO_KY"||contract.NgayTaoHopDong>signCutoff)continue;
                contract.TrangThai = "DA_HUY";
                await db.SaveChangesAsync(ct);
                await tx.CommitAsync(ct);
                contractCount++;
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Failed to expire contract {MaHopDong}", id);
            }
            finally { db.ChangeTracker.Clear(); }
        }

        if (holdCount > 0 || contractCount > 0)
        {
            logger.LogInformation("Đã hết hạn {HoldCount} giữ chỗ và hủy {ContractCount} hợp đồng quá hạn ký.",
                holdCount, contractCount);
        }
    }
}
