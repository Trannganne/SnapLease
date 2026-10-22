using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using RentalCamera.Api.Data;
using RentalCamera.Api.Contracts;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Notifications;

public sealed class NotificationDeliveryWorker(IServiceScopeFactory scopes, FirebaseApp firebase, IConfiguration configuration, ILogger<NotificationDeliveryWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if(!configuration.GetValue("Notifications:PushEnabled",false))return;
        // Test DB/recipient configuration always selects the fail-closed guard.
        var guarded = TestPushDeliveryPolicy.Configured(configuration);
        var policy = guarded ? TestPushDeliveryPolicy.FromConfiguration(configuration) : null;
        if (guarded && policy is null) { logger.LogWarning("Continuous test push configuration invalid; worker disabled"); return; }
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(15));
        while (!stoppingToken.IsCancellationRequested)
        {
            try {
                if (policy is null) await DrainAsync(stoppingToken);
                else {
                    using var scope = scopes.CreateScope();
                    var db = scope.ServiceProvider.GetRequiredService<RentalCameraContext>();
                    for (var i = 0; i < 50 && await policy.DrainOneAsync(db, SendPushAsync, stoppingToken); i++) db.ChangeTracker.Clear();
                    if (policy.Halted) { logger.LogWarning("Continuous test push disabled: {Code}", policy.HaltReason); return; }
                    if (policy.LastProblem is not null) logger.LogWarning("Continuous test push deferred: {Code}", policy.LastProblem);
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception ex) { logger.LogWarning("Push outbox unavailable: {Type}", ex.GetType().Name); }
            try { await timer.WaitForNextTickAsync(stoppingToken); } catch (OperationCanceledException) { break; }
        }
    }

    private async Task DrainAsync(CancellationToken ct)
    {
        for (var i=0; i<50; i++)
        {
            using var scope = scopes.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<RentalCameraContext>();
            NotificationDelivery? delivery;
            await using (var tx = await db.Database.BeginTransactionAsync(ct))
            {
                delivery = await db.NotificationDelivery.FromSqlRaw("""
                    SELECT TOP (1) * FROM NotificationDelivery WITH (UPDLOCK,READPAST,ROWLOCK)
                    WHERE (State='PENDING' AND NextAttemptUtc<=SYSUTCDATETIME())
                       OR (State='SENDING' AND LeaseUntilUtc<=SYSUTCDATETIME())
                    ORDER BY NextAttemptUtc,Id
                    """).AsTracking().FirstOrDefaultAsync(ct);
                if (delivery is null) return;
                delivery.State="SENDING"; delivery.Attempts++; delivery.LeaseUntilUtc=DateTime.UtcNow.AddMinutes(2);
                await db.SaveChangesAsync(ct); await tx.CommitAsync(ct);
            }
            var n = await db.ThongBao.AsNoTracking().SingleAsync(x => x.MaThongBao == delivery.MaThongBao, ct);
            var testAccount=configuration["Notifications:TestAccountId"];
            if(!string.IsNullOrWhiteSpace(testAccount)&&n.MaTaiKhoan!=testAccount) {
                delivery.State="SKIPPED_TEST_SCOPE";delivery.LeaseUntilUtc=null;await db.SaveChangesAsync(ct);continue;
            }
            // Serialize a reminder's final state check and transport submission with signing,
            // handover/return/cancellation. This prevents an old-due send racing a signed extension.
            await using var sendGuard=n.HanTraNhac.HasValue?await db.Database.BeginTransactionAsync(ct):null;
            if(sendGuard is not null)await TransactionLock.AcquireAsync(db,"contract:"+n.TargetId,ct);
            if(n.HanTraNhac.HasValue) {
                var h=await db.HopDong.AsNoTracking().SingleOrDefaultAsync(h=>h.MaHopDong==n.TargetId,ct);
                if(h is null||h.TrangThai!="DANG_THUE"||await RenewalEndpoints.EffectiveReturnAsync(h,db,ct)!=n.HanTraNhac.Value||
                    !await db.ChiTietHopDong.AnyAsync(d=>d.MaHopDong==h.MaHopDong&&d.NgayNhanThucTe==null,ct)||
                    n.EventCode!.StartsWith("RETURN_DUE")&&DateTime.UtcNow>RentalPolicy.Utc(n.HanTraNhac.Value)) {
                    delivery.State="SUPERSEDED";delivery.LeaseUntilUtc=null;await SaveDeliveryAsync(db,sendGuard,ct);continue;
                }
                var details=await db.ChiTietHopDong.AsNoTracking().Where(d=>d.MaHopDong==h.MaHopDong)
                    .Select(d=>new{d.NgayGiaoThucTe,d.NgayNhanThucTe}).ToListAsync(ct);
                var started=RentalPolicy.Utc(details.Where(d=>d.NgayGiaoThucTe!=null).Select(d=>d.NgayGiaoThucTe!.Value).DefaultIfEmpty(h.ThoiGianBanGiao).Min());
                if(!IsCurrentReminder(n,h.MaHopDong,started,DateTime.UtcNow)) {
                    delivery.State="SUPERSEDED";delivery.LeaseUntilUtc=null;await SaveDeliveryAsync(db,sendGuard,ct);continue;
                }
                var hours=scope.ServiceProvider.GetRequiredService<BranchWorkingHours>();
                if(!await hours.IsOpenAsync(h.MaCuaHang,DateTime.UtcNow,ct)) {
                    delivery.State="PENDING";delivery.Attempts--;delivery.LeaseUntilUtc=null;
                    delivery.NextAttemptUtc=await hours.NextOpeningAsync(h.MaCuaHang,DateTime.UtcNow,ct)??DateTime.UtcNow.AddDays(1);
                    await SaveDeliveryAsync(db,sendGuard,ct);continue;
                }
            }
            var device = await db.FcmDeviceToken.SingleOrDefaultAsync(x => x.Id == delivery.DeviceTokenId && x.IsActive && x.MaTaiKhoan == n.MaTaiKhoan, ct);
            if (device is null) { delivery.State="SKIPPED"; }
            else try
            {
                using var sendTimeout=CancellationTokenSource.CreateLinkedTokenSource(ct);
                sendTimeout.CancelAfter(TimeSpan.FromSeconds(8));
                await SendPushAsync(device, n, sendTimeout.Token);
                delivery.State="SENT"; delivery.LastErrorCode=null;
            }
            catch (FirebaseMessagingException ex)
            {
                delivery.LastErrorCode=ex.MessagingErrorCode?.ToString() ?? "FIREBASE_ERROR";
                if (ex.MessagingErrorCode == MessagingErrorCode.Unregistered)
                { device.IsActive=false; device.UpdatedAt=DateTime.UtcNow; delivery.State="INVALID_DEVICE"; }
                else { delivery.State=delivery.Attempts>=8 ? "FAILED" : "PENDING"; delivery.NextAttemptUtc=DateTime.UtcNow.AddSeconds(Math.Min(3600,15*Math.Pow(2,delivery.Attempts))); }
            }
            catch(OperationCanceledException)when(!ct.IsCancellationRequested) {
                delivery.LastErrorCode="TRANSPORT_UNCERTAIN";delivery.State=delivery.Attempts>=8?"FAILED":"PENDING";
                delivery.NextAttemptUtc=DateTime.UtcNow.AddMinutes(2);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                delivery.LastErrorCode="TRANSPORT_UNCERTAIN"; delivery.State=delivery.Attempts>=8 ? "FAILED" : "PENDING";
                delivery.NextAttemptUtc=DateTime.UtcNow.AddMinutes(2);
            }
            delivery.LeaseUntilUtc=null;
            await SaveDeliveryAsync(db,sendGuard,ct);
        }
    }
    private async Task SendPushAsync(FcmDeviceToken device, ThongBao n, CancellationToken ct)
    {
        await FirebaseMessaging.GetMessaging(firebase).SendAsync(new Message {
                    Fid = device.Token,
                    Notification = new Notification { Title="SNAPLEASE", Body="Bạn có thông báo mới." },
                    Data = new Dictionary<string,string> { ["notificationId"]=n.MaThongBao, ["eventCode"]=n.EventCode ?? "",
                        ["targetType"]=n.TargetType ?? "", ["targetId"]=n.TargetId ?? "" },
                    Android = new AndroidConfig { CollapseKey=n.MaThongBao, Notification=new AndroidNotification { Tag=n.MaThongBao } }
                }, ct);
    }
    private static async Task SaveDeliveryAsync(RentalCameraContext db,IDbContextTransaction? guard,CancellationToken ct)
    {
        await db.SaveChangesAsync(ct);
        if(guard is not null)await guard.CommitAsync(ct);
    }
    public static bool IsCurrentReminder(ThongBao n,string contractId,DateTime startedUtc,DateTime nowUtc)
    {
        if(n.HanTraNhac is not DateTime due)return false;
        var latest=ReturnReminderWorker.SelectMilestone(RentalPolicy.Utc(due),startedUtc,nowUtc);
        return latest.HasValue&&n.EventKey==$"{latest.Value.Code}:{contractId}:{due:yyyyMMddHHmmss}:{latest.Value.Index}";
    }
}
