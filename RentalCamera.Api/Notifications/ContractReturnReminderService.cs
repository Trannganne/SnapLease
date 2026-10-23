using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Notifications;

public sealed class ContractReturnReminderService(
    IServiceScopeFactory scopeFactory,
    IConfiguration configuration,
    ILogger<ContractReturnReminderService> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var scanMinutes = Math.Clamp(
            configuration.GetValue("Rental:ReturnReminderScanMinutes", 5), 1, 1440);
        using var timer = new PeriodicTimer(TimeSpan.FromMinutes(scanMinutes));
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await SendRemindersAsync(stoppingToken);
                await timer.WaitForNextTickAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Không thể gửi thông báo nhắc hạn trả thiết bị.");
                await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
            }
        }
    }

    private async Task SendRemindersAsync(CancellationToken ct)
    {
        await using var scope = scopeFactory.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<RentalCameraContext>();
        var sender = scope.ServiceProvider.GetRequiredService<FirebaseNotificationSender>();
        var now = DateTime.Now;
        var reminderHours = Math.Clamp(
            configuration.GetValue("Rental:ReturnReminderHours", 24), 1, 168);
        var reminderCutoff = now.AddHours(reminderHours);

        var contracts = await db.HopDong.AsNoTracking()
            .Where(x => x.TrangThai == "DANG_THUE")
            .Select(x => new
            {
                x.MaHopDong,
                x.ThoiGianTraDuKien,
                MaTaiKhoan = db.KhachThue.Where(k => k.MaKhachThue == x.MaKhachThue)
                    .Select(k => k.MaTaiKhoan).Single(),
                ThoiHanGiaHan = db.PhuLuc
                    .Where(p => p.MaHopDong == x.MaHopDong && p.TrangThai == "DA_XAC_NHAN")
                    .Max(p => (DateTime?)p.ThoiHanTraMoi)
            })
            .ToListAsync(ct);

        var contractIds = contracts.Select(x => x.MaHopDong).ToList();
        var sent = await db.ThongBao.AsNoTracking()
            .Where(x => contractIds.Contains(x.TargetId!) &&
                (x.EventCode == "CONTRACT_RETURN_DUE_SOON" ||
                 x.EventCode == "CONTRACT_RETURN_OVERDUE"))
            .Select(x => new { x.EventCode, x.TargetId })
            .ToListAsync(ct);
        var sentKeys = sent.Select(x => $"{x.EventCode}:{x.TargetId}")
            .ToHashSet(StringComparer.Ordinal);
        var pending = new List<PendingReminder>();

        foreach (var contract in contracts)
        {
            var dueAt = contract.ThoiHanGiaHan ?? contract.ThoiGianTraDuKien;
            string? eventCode = null;
            string? title = null;
            string? body = null;
            if (dueAt <= now)
            {
                eventCode = "CONTRACT_RETURN_OVERDUE";
                title = "Hợp đồng đã quá hạn trả";
                body = $"Hợp đồng {contract.MaHopDong} đã quá hạn trả từ {dueAt:dd/MM/yyyy HH:mm}. Vui lòng liên hệ cửa hàng để hoàn trả thiết bị.";
            }
            else if (dueAt <= reminderCutoff)
            {
                eventCode = "CONTRACT_RETURN_DUE_SOON";
                title = "Sắp đến hạn trả thiết bị";
                body = $"Hợp đồng {contract.MaHopDong} cần trả thiết bị trước {dueAt:dd/MM/yyyy HH:mm}.";
            }

            if (eventCode is null || sentKeys.Contains($"{eventCode}:{contract.MaHopDong}")) continue;
            ApiAccess.AddNotification(db, contract.MaTaiKhoan, "HOAN_TRA", title!, body!,
                eventCode, "HOP_DONG", contract.MaHopDong);
            sentKeys.Add($"{eventCode}:{contract.MaHopDong}");
            pending.Add(new PendingReminder(contract.MaTaiKhoan, contract.MaHopDong, eventCode, title!, body!));
        }

        if (pending.Count == 0) return;
        await db.SaveChangesAsync(ct);
        foreach (var item in pending)
            await sender.SendToAccountAsync(item.AccountId, item.Title, item.Body,
                item.EventCode, "HOP_DONG", item.ContractId, ct);
        logger.LogInformation("Đã tạo {Count} thông báo nhắc hạn trả thiết bị.", pending.Count);
    }

    private sealed record PendingReminder(
        string AccountId,
        string ContractId,
        string EventCode,
        string Title,
        string Body);
}
