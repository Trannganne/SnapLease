using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Penalties;

public static class PenaltyEndpoints
{
    public static void MapPenaltyEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/phieu-phat").RequireAuthorization();

        group.MapGet("", async (
            ClaimsPrincipal principal, RentalCameraContext db, string? maHopDong,
            string? maCuaHang, string? trangThai, CancellationToken ct) =>
        {
            var query = db.PhieuPhat.AsNoTracking()
                .Join(db.ChiTietHopDong, p => p.MaChiTietHopDong, c => c.MaChiTietHopDong, (p, c) => new { p, c })
                .Join(db.HopDong, x => x.c.MaHopDong, h => h.MaHopDong, (x, h) => new { x.p, x.c, h });
            if (principal.IsInRole("KHACH_HANG"))
            {
                var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
                query = query.Where(x => x.h.MaKhachThue == customerId);
            }
            else
            {
                var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
                if (scope is null) return Results.Forbid();
                if (!scope.IsAdmin) query = query.Where(x => x.h.MaCuaHang == scope.StoreId);
                else if (!string.IsNullOrWhiteSpace(maCuaHang)) query = query.Where(x => x.h.MaCuaHang == maCuaHang);
            }
            if (!string.IsNullOrWhiteSpace(maHopDong)) query = query.Where(x => x.h.MaHopDong == maHopDong);
            if (!string.IsNullOrWhiteSpace(trangThai)) query = query.Where(x => x.p.TrangThai == trangThai);
            var data = await query.OrderByDescending(x => x.p.NgayLap).Select(x => new
            {
                x.p.MaPhieuPhat, x.h.MaHopDong, x.c.MaThietBi, x.p.MaChiTietHopDong,
                x.p.LoaiViPham, x.p.SoTien, x.p.MoTa, x.p.NgayLap, x.p.TrangThai
            }).ToListAsync(ct);
            return Results.Ok(data);
        });

        group.MapGet("/{id}", async (string id, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var item = await db.PhieuPhat.AsNoTracking().Where(x => x.MaPhieuPhat == id)
                .Join(db.ChiTietHopDong, p => p.MaChiTietHopDong, c => c.MaChiTietHopDong, (p, c) => new { p, c })
                .Join(db.HopDong, x => x.c.MaHopDong, h => h.MaHopDong, (x, h) => new
                {
                    x.p.MaPhieuPhat, x.p.MaChiTietHopDong, h.MaHopDong, h.MaKhachThue,
                    h.MaCuaHang, x.c.MaThietBi, x.p.LoaiViPham, x.p.SoTien, x.p.MoTa,
                    x.p.NgayLap, x.p.TrangThai
                }).FirstOrDefaultAsync(ct);
            if (item is null) return Results.NotFound();
            if (principal.IsInRole("KHACH_HANG"))
            {
                var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
                if (item.MaKhachThue != customerId) return Results.Forbid();
            }
            else if (!principal.IsInRole("ADMIN"))
            {
                var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
                if (scope?.StoreId != item.MaCuaHang) return Results.Forbid();
            }
            return Results.Ok(item);
        });

        group.MapPost("", async (PenaltyRequest request, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            if (request.LoaiViPham is not ("TRA_TRE" or "HU_HONG" or "THIEU_PHU_KIEN" or "KHAC") ||
                request.SoTien < 0 || string.IsNullOrWhiteSpace(request.MoTa)) return Results.BadRequest();
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            var detail = await db.ChiTietHopDong.Join(db.HopDong, c => c.MaHopDong, h => h.MaHopDong, (c, h) => new { c, h })
                .SingleOrDefaultAsync(x => x.c.MaChiTietHopDong == request.MaChiTietHopDong, ct);
            if (detail is null) return Results.NotFound();
            if (!scope.IsAdmin && detail.h.MaCuaHang != scope.StoreId) return Results.Forbid();
            var entity = new PhieuPhat
            {
                MaPhieuPhat = ApiAccess.NewId("PP"), MaChiTietHopDong = request.MaChiTietHopDong,
                LoaiViPham = request.LoaiViPham, SoTien = request.SoTien,
                MoTa = request.MoTa.Trim(), NgayLap = DateTime.Now, TrangThai = "CHO_XAC_NHAN"
            };
            db.PhieuPhat.Add(entity);
            await db.SaveChangesAsync(ct);
            return Results.Created($"/api/phieu-phat/{entity.MaPhieuPhat}", entity);
        }).RequireAuthorization("Staff");

        group.MapPut("/{id}/xac-nhan", async (string id, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
            await ChangeState(id, "DA_XAC_NHAN", principal, db, ct)).RequireAuthorization("Staff");
        group.MapPut("/{id}/huy", async (string id, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
            await ChangeState(id, "HUY", principal, db, ct)).RequireAuthorization("Staff");
    }

    private static async Task<IResult> ChangeState(
        string id, string state, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct)
    {
        var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
        if (scope is null) return Results.Forbid();
        var row = await db.PhieuPhat.Join(db.ChiTietHopDong, p => p.MaChiTietHopDong, c => c.MaChiTietHopDong, (p, c) => new { p, c })
            .Join(db.HopDong, x => x.c.MaHopDong, h => h.MaHopDong, (x, h) => new { x.p, h })
            .SingleOrDefaultAsync(x => x.p.MaPhieuPhat == id, ct);
        if (row is null) return Results.NotFound();
        if (!scope.IsAdmin && row.h.MaCuaHang != scope.StoreId) return Results.Forbid();
        if (row.p.TrangThai != "CHO_XAC_NHAN") return Results.Conflict(new { loi = "Phiếu phạt đã được xử lý." });
        row.p.TrangThai = state;
        await db.SaveChangesAsync(ct);
        return Results.Ok(row.p);
    }
}

public sealed record PenaltyRequest(
    string MaChiTietHopDong, string LoaiViPham, decimal SoTien, string MoTa);
