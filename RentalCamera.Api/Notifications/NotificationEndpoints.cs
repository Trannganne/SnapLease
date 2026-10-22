using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;

namespace RentalCamera.Api.Notifications;

public static class NotificationEndpoints
{
    public static void MapNotificationEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/thong-bao").RequireAuthorization();
        group.MapGet("/{id}", async (string id, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var account = principal.FindFirstValue(ClaimTypes.NameIdentifier);
            var x = await db.ThongBao.AsNoTracking().SingleOrDefaultAsync(x => x.MaThongBao == id && x.MaTaiKhoan == account, ct);
            return x is null ? Results.NotFound() : Results.Ok(new { x.MaThongBao, x.Loai, x.TieuDe, x.NoiDung, x.DaDoc,
                thoiGianGui = Timestamp(x), x.EventCode, x.TargetType, x.TargetId });
        });

        group.MapGet("", async (
            ClaimsPrincipal principal, RentalCameraContext db,
            bool? daDoc, string? nhom, int? trang, int? kichThuocTrang, CancellationToken ct) =>
        {
            var accountId = principal.FindFirstValue(ClaimTypes.NameIdentifier)!;
            var page = Math.Max(1, trang ?? 1);
            var pageSize = Math.Clamp(kichThuocTrang ?? 20, 1, 100);
            var query = db.ThongBao.AsNoTracking().Where(x => x.MaTaiKhoan == accountId);
            if (daDoc.HasValue) query = query.Where(x => x.DaDoc == daDoc.Value);
            if (nhom is not null && nhom is not ("HOP_DONG" or "THANH_TOAN")) return Results.BadRequest(new { loi = "Nhóm không hợp lệ." });
            if (nhom == "HOP_DONG") query = query.Where(x => x.Loai == "HOP_DONG" || x.Loai == "BAN_GIAO" || x.Loai == "GIA_HAN");
            if (nhom == "THANH_TOAN") query = query.Where(x => x.Loai == "THANH_TOAN" || x.Loai == "HOAN_TIEN");
            var total = await query.CountAsync(ct);
            var unread = await query.CountAsync(x => !x.DaDoc, ct);
            var items = await query.OrderByDescending(x => x.ThoiGianGui)
                .Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct);
            return Results.Ok(new { trang = page, kichThuocTrang = pageSize, tongSo = total, chuaDoc = unread,
                duLieu = items.Select(x => new { x.MaThongBao, x.Loai, x.TieuDe, x.NoiDung, x.DaDoc,
                    thoiGianGui = Timestamp(x), x.EventCode, x.TargetType, x.TargetId }) });
        });

        group.MapPut("/{id}/da-doc", async (
            string id, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var accountId = principal.FindFirstValue(ClaimTypes.NameIdentifier)!;
            var notification = await db.ThongBao
                .SingleOrDefaultAsync(x => x.MaThongBao == id && x.MaTaiKhoan == accountId, ct);
            if (notification is null) return Results.NotFound();
            notification.DaDoc = true;
            await db.SaveChangesAsync(ct);
            return Results.NoContent();
        });
    }
    // Legacy rows did not record their timezone; preserve their wall clock without inventing an offset.
    private static DateTime Timestamp(ThongBao row) => DateTime.SpecifyKind(row.ThoiGianGui,
        row.EventKey is null ? DateTimeKind.Unspecified : DateTimeKind.Utc);
}
