using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Operations;

public static class AuditEndpoints
{
    public static void UseBusinessAudit(this WebApplication app)
    {
        app.Use(async (context, next) =>
        {
            await next();

            if (context.User.Identity?.IsAuthenticated != true ||
                context.Request.Method is not ("POST" or "PUT" or "PATCH" or "DELETE") ||
                context.Response.StatusCode >= 500)
                return;

            try
            {
                await using var scope = app.Services.CreateAsyncScope();
                var db = scope.ServiceProvider.GetRequiredService<RentalCameraContext>();
                var accountId = context.User.FindFirstValue(ClaimTypes.NameIdentifier);
                var role = context.User.FindFirstValue(ClaimTypes.Role);
                var storeId = role == "NHAN_VIEN"
                    ? await db.NhanVien.AsNoTracking().Where(x => x.MaTaiKhoan == accountId)
                        .Select(x => x.MaCuaHang).FirstOrDefaultAsync()
                    : null;
                var routeValues = context.Request.RouteValues;
                var entityId = routeValues.TryGetValue("id", out var id) ? id?.ToString() : null;
                var endpointName = context.GetEndpoint()?.DisplayName;

                db.NhatKyHeThong.Add(new NhatKyHeThong
                {
                    MaNhatKy = ApiAccess.NewId("NK"),
                    MaTaiKhoan = accountId,
                    VaiTro = role,
                    HanhDong = context.Request.Method,
                    DuongDan = (context.Request.Path.Value ?? "/")[..Math.Min((context.Request.Path.Value ?? "/").Length, 500)],
                    DoiTuong = endpointName?[..Math.Min(endpointName.Length, 100)],
                    MaDoiTuong = entityId?[..Math.Min(entityId.Length, 100)],
                    MaCuaHang = storeId,
                    TrangThaiHttp = context.Response.StatusCode,
                    DiaChiIp = context.Connection.RemoteIpAddress?.ToString(),
                    ThoiGian = DateTime.UtcNow
                });
                await db.SaveChangesAsync();
            }
            catch (Exception ex)
            {
                app.Logger.LogError(ex, "Không thể ghi nhật ký thao tác {Method} {Path}.",
                    context.Request.Method, context.Request.Path);
            }
        });
    }

    public static void MapAuditEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/he-thong/nhat-ky", async (
            string? maTaiKhoan, string? hanhDong, string? doiTuong,
            DateTime? tuNgay, DateTime? denNgay, int? trang, int? kichThuocTrang,
            RentalCameraContext db, CancellationToken ct) =>
        {
            var page = Math.Max(trang ?? 1, 1);
            var pageSize = Math.Clamp(kichThuocTrang ?? 50, 1, 200);
            var query = db.NhatKyHeThong.AsNoTracking();
            if (!string.IsNullOrWhiteSpace(maTaiKhoan))
                query = query.Where(x => x.MaTaiKhoan == maTaiKhoan.Trim());
            if (!string.IsNullOrWhiteSpace(hanhDong))
                query = query.Where(x => x.HanhDong == hanhDong.Trim().ToUpper());
            if (!string.IsNullOrWhiteSpace(doiTuong))
                query = query.Where(x => x.DoiTuong != null && x.DoiTuong.Contains(doiTuong.Trim()));
            if (tuNgay.HasValue) query = query.Where(x => x.ThoiGian >= tuNgay.Value);
            if (denNgay.HasValue) query = query.Where(x => x.ThoiGian < denNgay.Value.AddDays(1));

            var total = await query.CountAsync(ct);
            var data = await query.OrderByDescending(x => x.ThoiGian)
                .Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct);
            return Results.Ok(new
            {
                trang = page, kichThuocTrang = pageSize, tongSo = total,
                tongTrang = total == 0 ? 0 : (int)Math.Ceiling(total / (double)pageSize),
                duLieu = data
            });
        }).RequireAuthorization("Admin").WithName("Tra cứu nhật ký hệ thống");
    }
}
