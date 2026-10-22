using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Contracts;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Notifications;

public sealed class ReturnReminderWorker(IServiceScopeFactory scopes,IConfiguration configuration,ILogger<ReturnReminderWorker> logger):BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        if(!configuration.GetValue("Rental:BackgroundJobsEnabled",true))return;
        using var timer=new PeriodicTimer(TimeSpan.FromMinutes(1));
        while(!ct.IsCancellationRequested) {
            try { await RunAsync(ct); }
            catch(OperationCanceledException)when(ct.IsCancellationRequested){break;}
            catch(Exception ex){logger.LogWarning("Return reminder unavailable: {Type}",ex.GetType().Name);}
            try{await timer.WaitForNextTickAsync(ct);}catch(OperationCanceledException){break;}
        }
    }
    private async Task RunAsync(CancellationToken ct)
    {
        using var scope=scopes.CreateScope();var db=scope.ServiceProvider.GetRequiredService<RentalCameraContext>();
        var ids=await db.PhuLuc.AsNoTracking().Where(p=>(p.TrangThai=="CHO_KY"&&p.HanKyUtc<=DateTime.UtcNow || p.TrangThai=="CHO_XAC_NHAN"&&p.HanXuLyUtc<=DateTime.UtcNow)
            && !RentalPolicy.ProtectedContracts.Contains(p.MaHopDong)).Select(p=>p.MaHopDong).Distinct().ToListAsync(ct);
        foreach(var id in ids){await using var tx=await db.Database.BeginTransactionAsync(ct);await TransactionLock.AcquireAsync(db,"contract:"+id,ct);
            await RenewalEndpoints.ExpireAsync(id,db,ct);await tx.CommitAsync(ct);db.ChangeTracker.Clear();}
        var hours=scope.ServiceProvider.GetRequiredService<BranchWorkingHours>();
        var contracts=await db.HopDong.AsNoTracking().Where(h=>h.TrangThai=="DANG_THUE" && !RentalPolicy.ProtectedContracts.Contains(h.MaHopDong)).Select(h=>h.MaHopDong).ToListAsync(ct);
        foreach(var id in contracts){
            await using var tx=await db.Database.BeginTransactionAsync(ct);await TransactionLock.AcquireAsync(db,"contract:"+id,ct);
            var h=await db.HopDong.SingleAsync(h=>h.MaHopDong==id,ct);
            if(h.TrangThai!="DANG_THUE")continue;
            var details=await db.ChiTietHopDong.AsNoTracking().Where(d=>d.MaHopDong==id).ToListAsync(ct);
            if(details.Count==0||details.All(d=>d.NgayNhanThucTe!=null))continue;
            if(!await hours.IsOpenAsync(h.MaCuaHang,DateTime.UtcNow,ct))continue;
            var due=await RenewalEndpoints.EffectiveReturnAsync(h,db,ct);var utcDue=RentalPolicy.Utc(due);var now=DateTime.UtcNow;
            var started=RentalPolicy.Utc(details.Where(d=>d.NgayGiaoThucTe!=null).Select(d=>d.NgayGiaoThucTe!.Value).DefaultIfEmpty(h.ThoiGianBanGiao).Min());
            var milestone=SelectMilestone(utcDue,started,now);
            var code=milestone?.Code;
            if(code is null)continue;
            var opening=await hours.NextOpeningAsync(h.MaCuaHang,milestone!.Value.At,ct);
            if(opening is null||now<opening.Value)continue;
            var key=$"{code}:{id}:{due:yyyyMMddHHmmss}:{milestone.Value.Index}";
            if(await db.ThongBao.AnyAsync(n=>n.EventKey==key,ct))continue;
            var account=await db.KhachThue.Where(k=>k.MaKhachThue==h.MaKhachThue).Select(k=>k.MaTaiKhoan).SingleAsync(ct);
            var n=ApiAccess.AddNotification(db,account,"HOP_DONG",code.StartsWith("RETURN_DUE")?"Sắp đến hạn trả":"Đã quá hạn trả","Xem hạn trả có hiệu lực trong hợp đồng.",code,"HOP_DONG",id);
            n.EventKey=key;n.HanTraNhac=due;await db.SaveChangesAsync(ct);await tx.CommitAsync(ct);db.ChangeTracker.Clear();
        }
    }
    // Only the latest eligible milestone is sent. Older missed reminders are implicitly superseded.
    public static (string Code,DateTime At,int Index)? SelectMilestone(DateTime due,DateTime started,DateTime now)
    {
        if(now>due){var index=(int)Math.Floor((now-due).TotalDays);return("RETURN_OVERDUE",due.AddDays(index),index);}
        if(due.AddHours(-2)>=started&&now>=due.AddHours(-2))return("RETURN_DUE_2H",due.AddHours(-2),0);
        if(due.AddHours(-24)>=started&&now>=due.AddHours(-24))return("RETURN_DUE_24H",due.AddHours(-24),0);
        return null;
    }
}
