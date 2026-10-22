using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Notifications;

public static class NotificationEvents
{
    public static async Task CollectAsync(RentalCameraContext db, CancellationToken ct)
    {
        db.ChangeTracker.DetectChanges();
        foreach (var entry in db.ChangeTracker.Entries<HopDong>().Where(e => e.State == EntityState.Added ||
                     e.State == EntityState.Modified && e.Property(x => x.TrangThai).IsModified).ToList())
        {
            var h = entry.Entity;
            var code = h.TrangThai switch {
                "CHO_KY" => "CONTRACT_CREATED", "DA_KY" => "CONTRACT_SIGNED", "CHO_BAN_GIAO" => "CONTRACT_AWAITING_HANDOVER",
                "DANG_THUE" => "CONTRACT_RENTING", "HOAN_THANH" => "CONTRACT_COMPLETED", "DA_HUY" => "CONTRACT_CANCELLED", _ => null };
            if (code is null) continue;
            var account = await db.KhachThue.Where(x => x.MaKhachThue == h.MaKhachThue).Select(x => x.MaTaiKhoan).SingleAsync(ct);
            Add(db, account, "HOP_DONG", code, "HOP_DONG", h.MaHopDong, "Cập nhật hợp đồng thuê");
        }
        foreach (var entry in db.ChangeTracker.Entries<PhuLuc>().Where(e => e.State == EntityState.Added ||
                     e.State == EntityState.Modified && e.Property(x => x.TrangThai).IsModified).ToList())
        {
            var p = entry.Entity;
            var account = await db.HopDong.Where(x => x.MaHopDong == p.MaHopDong).Join(db.KhachThue,
                h => h.MaKhachThue, k => k.MaKhachThue, (h, k) => k.MaTaiKhoan).SingleAsync(ct);
            Add(db, account, "GIA_HAN", "EXTENSION_" + p.TrangThai, "HOP_DONG", p.MaHopDong,
                "Cập nhật yêu cầu gia hạn", "extension:" + p.MaPhuLuc + ":" + p.TrangThai);
        }
        foreach (var entry in db.ChangeTracker.Entries<ThanhToan>().Where(e => e.State == EntityState.Added ||
                     e.State == EntityState.Modified && e.Property(x => x.TrangThai).IsModified).ToList())
        {
            var p = entry.Entity;
            var account = await db.HopDong.Where(x => x.MaHopDong == p.MaHopDong).Join(db.KhachThue,
                h => h.MaKhachThue, k => k.MaKhachThue, (h, k) => k.MaTaiKhoan).SingleAsync(ct);
            Add(db, account, p.LoaiThanhToan.StartsWith("HOAN") ? "HOAN_TIEN" : "THANH_TOAN",
                "PAYMENT_" + p.TrangThai, "HOP_DONG", p.MaHopDong, "Cập nhật giao dịch thanh toán", "payment:" + p.MaThanhToan + ":" + p.TrangThai);
        }
        // Notification and per-device delivery are part of the business SaveChanges transaction.
        foreach (var notification in db.ChangeTracker.Entries<ThongBao>().Where(x => x.State == EntityState.Added).Select(x => x.Entity).ToList())
        {
            if (notification.EventKey is null) continue; // legacy rows are never replayed as new events
            var devices = await db.FcmDeviceToken.AsNoTracking().Where(x => x.MaTaiKhoan == notification.MaTaiKhoan && x.IsActive).Select(x => x.Id).ToListAsync(ct);
            foreach (var device in devices)
            {
                if (db.NotificationDelivery.Local.Any(x => x.MaThongBao == notification.MaThongBao && x.DeviceTokenId == device)) continue;
                db.NotificationDelivery.Add(new NotificationDelivery { Id = Guid.NewGuid().ToString(), MaThongBao = notification.MaThongBao,
                    DeviceTokenId = device, NextAttemptUtc = DateTime.UtcNow });
            }
        }
    }

    private static void Add(RentalCameraContext db, string account, string type, string code, string targetType, string target, string title, string? key = null)
    {
        key ??= code + ":" + targetType + ":" + target;
        if (db.ThongBao.Local.Any(x => x.EventKey == key)) return;
        var n = ApiAccess.AddNotification(db, account, type, title, "Mở thông báo để xem trạng thái mới nhất.", code, targetType, target);
        n.EventKey = key;
    }
}
