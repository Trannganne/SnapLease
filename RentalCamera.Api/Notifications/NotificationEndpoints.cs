using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;

namespace RentalCamera.Api.Notifications;

public static class NotificationEndpoints
{
    public static void MapNotificationEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/thong-bao").RequireAuthorization();

        group.MapGet("", async (
            ClaimsPrincipal principal, RentalCameraContext db,
            bool? daDoc, int? trang, int? kichThuocTrang, CancellationToken ct) =>
        {
            var accountId = principal.FindFirstValue(ClaimTypes.NameIdentifier)!;
            var page = Math.Max(1, trang ?? 1);
            var pageSize = Math.Clamp(kichThuocTrang ?? 20, 1, 100);
            var query = db.ThongBao.AsNoTracking().Where(x => x.MaTaiKhoan == accountId);
            if (daDoc.HasValue) query = query.Where(x => x.DaDoc == daDoc.Value);
            var total = await query.CountAsync(ct);
            var items = await query.OrderByDescending(x => x.ThoiGianGui)
                .Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct);
            return Results.Ok(new { trang = page, kichThuocTrang = pageSize, tongSo = total, duLieu = items });
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
}
