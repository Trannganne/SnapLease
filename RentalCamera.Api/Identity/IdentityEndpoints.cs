using System.Security.Claims;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Identity;

public static class IdentityEndpoints
{
    public static void MapIdentityEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/giay-to").RequireAuthorization();

        group.MapGet("/cua-toi", async (ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            var data = await db.GiayToTuyThan.AsNoTracking().Where(x => x.MaKhachThue == customerId)
                .OrderByDescending(x => x.NgayTaiLen).ToListAsync(ct);
            return Results.Ok(data);
        }).RequireAuthorization("Customer");

        group.MapPost("", async (IdentityDocumentRequest request, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            if (request.LoaiGiayTo is not ("CCCD" or "HO_CHIEU" or "GPLX") ||
                string.IsNullOrWhiteSpace(request.HoTen) || request.HoTen.Length > 150 ||
                string.IsNullOrWhiteSpace(request.SoGiayTo) || string.IsNullOrWhiteSpace(request.MatTruocUrl))
                return Results.BadRequest(new { loi = "Thông tin giấy tờ không hợp lệ." });
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            if (await db.GiayToTuyThan.AnyAsync(x => x.SoGiayTo == request.SoGiayTo.Trim(), ct))
                return Results.Conflict(new { loi = "Số giấy tờ đã tồn tại." });
            var entity = new GiayToTuyThan
            {
                MaGiayTo = ApiAccess.NewId("GT"), MaKhachThue = customerId,
                LoaiGiayTo = request.LoaiGiayTo, SoGiayTo = request.SoGiayTo.Trim(),
                MatTruocUrl = request.MatTruocUrl.Trim(), MatSauUrl = request.MatSauUrl?.Trim(),
                NgayTaiLen = DateTime.Now, TrangThaiXacMinh = "CHO_XAC_MINH"
            };
            var customer = await db.KhachThue.SingleAsync(x => x.MaKhachThue == customerId, ct);
            customer.HoTen = request.HoTen.Trim();
            db.GiayToTuyThan.Add(entity);
            await db.SaveChangesAsync(ct);
            return Results.Created($"/api/giay-to/{entity.MaGiayTo}", entity);
        }).RequireAuthorization("Customer");

        group.MapGet("/cho-xac-minh", async (ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            var query = db.GiayToTuyThan.AsNoTracking().Where(x => x.TrangThaiXacMinh == "CHO_XAC_MINH");
            if (!scope.IsAdmin)
                query = query.Where(x => db.GioHang.Any(g => g.MaKhachThue == x.MaKhachThue && g.MaCuaHang == scope.StoreId));
            var data = await query.OrderBy(x => x.NgayTaiLen)
                .Join(db.KhachThue, g => g.MaKhachThue, k => k.MaKhachThue, (g, k) => new
                {
                    g.MaGiayTo, g.MaKhachThue, k.HoTen, g.LoaiGiayTo, g.SoGiayTo,
                    g.MatTruocUrl, g.MatSauUrl, g.NgayTaiLen
                }).ToListAsync(ct);
            return Results.Ok(data);
        }).RequireAuthorization("Staff");

        group.MapPut("/{id}/xac-minh", async (
            string id, VerifyIdentityRequest request, ClaimsPrincipal principal,
            RentalCameraContext db, CancellationToken ct) =>
        {
            if (request.KetQua is not ("HOP_LE" or "TU_CHOI")) return Results.BadRequest();
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            var document = await db.GiayToTuyThan.SingleOrDefaultAsync(x => x.MaGiayTo == id, ct);
            if (document is null) return Results.NotFound();
            if (!scope.IsAdmin && !await db.GioHang.AnyAsync(
                x => x.MaKhachThue == document.MaKhachThue && x.MaCuaHang == scope.StoreId, ct))
                return Results.Forbid();
            if (document.TrangThaiXacMinh != "CHO_XAC_MINH")
                return Results.Conflict(new { loi = "Giấy tờ đã được xử lý." });
            document.TrangThaiXacMinh = request.KetQua;
            document.GhiChu = request.GhiChu?.Trim();
            var customer = await db.KhachThue.SingleAsync(x => x.MaKhachThue == document.MaKhachThue, ct);
            if (request.KetQua == "HOP_LE" && document.LoaiGiayTo == "CCCD")
            {
                var cccd = document.SoGiayTo.Trim();
                if (await db.KhachThue.AnyAsync(x => x.CCCD == cccd && x.MaKhachThue != customer.MaKhachThue, ct))
                    return Results.Conflict(new { loi = "CCCD đã được sử dụng bởi khách thuê khác." });
                customer.CCCD = cccd;
            }
            ApiAccess.AddNotification(db, customer.MaTaiKhoan, "XAC_MINH_GIAY_TO", "Kết quả xác minh giấy tờ",
                request.KetQua == "HOP_LE" ? "Giấy tờ của bạn đã được xác minh." : $"Giấy tờ bị từ chối. {request.GhiChu}");
            try
            {
                await db.SaveChangesAsync(ct);
            }
            catch (DbUpdateException ex) when (ex.InnerException is SqlException { Number: 2601 or 2627 })
            {
                return Results.Conflict(new { loi = "CCCD đã được sử dụng bởi khách thuê khác." });
            }
            return Results.Ok(new { document.MaGiayTo, document.TrangThaiXacMinh, document.GhiChu });
        }).RequireAuthorization("Staff");
    }
}

public sealed record IdentityDocumentRequest(
    string HoTen, string LoaiGiayTo, string SoGiayTo, string MatTruocUrl, string? MatSauUrl);
public sealed record VerifyIdentityRequest(string KetQua, string? GhiChu);
