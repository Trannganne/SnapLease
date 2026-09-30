using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Reviews;

public static class ReviewEndpoints
{
    public static void MapReviewEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost("/api/danh-gia", async (
            CreateReviewRequest request, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            if (request.SoSao is < 1 or > 5) return Results.BadRequest(new { loi = "Số sao phải từ 1 đến 5." });
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            var detail = await db.ChiTietHopDong
                .Join(db.HopDong, d => d.MaHopDong, h => h.MaHopDong, (d, h) => new { d, h })
                .SingleOrDefaultAsync(x => x.d.MaChiTietHopDong == request.MaChiTietHopDong, ct);
            if (detail is null) return Results.NotFound();
            if (detail.h.MaKhachThue != customerId) return Results.Forbid();
            if (detail.h.TrangThai != "HOAN_THANH")
                return Results.Conflict(new { loi = "Chỉ được đánh giá sau khi hoàn tất hợp đồng." });
            if (await db.DanhGia.AnyAsync(x => x.MaChiTietHopDong == request.MaChiTietHopDong && x.MaKhachThue == customerId, ct))
                return Results.Conflict(new { loi = "Thiết bị trong hợp đồng này đã được đánh giá." });
            var review = new DanhGia
            {
                MaDanhGia = ApiAccess.NewId("DG"), MaChiTietHopDong = request.MaChiTietHopDong,
                MaKhachThue = customerId, SoSao = request.SoSao,
                NhanXet = request.NhanXet?.Trim(), NgayDanhGia = DateTime.Now
            };
            db.DanhGia.Add(review);
            await db.SaveChangesAsync(ct);
            return Results.Created($"/api/danh-gia/{review.MaDanhGia}", review);
        }).RequireAuthorization("Customer");

        app.MapGet("/api/dong-may/{id}/danh-gia", async (
            string id, int? trang, int? kichThuocTrang, RentalCameraContext db, CancellationToken ct) =>
        {
            var page = Math.Max(1, trang ?? 1);
            var size = Math.Clamp(kichThuocTrang ?? 20, 1, 100);
            var query = db.DanhGia.AsNoTracking()
                .Where(x => db.ChiTietHopDong.Any(d => d.MaChiTietHopDong == x.MaChiTietHopDong
                    && db.ThietBi.Any(t => t.MaThietBi == d.MaThietBi && t.MaDongMay == id)));
            var total = await query.CountAsync(ct);
            var average = await query.AverageAsync(x => (double?)x.SoSao, ct);
            var data = await query.OrderByDescending(x => x.NgayDanhGia).Skip((page - 1) * size).Take(size)
                .Join(db.KhachThue, x => x.MaKhachThue, k => k.MaKhachThue, (x, k) => new
                { x.MaDanhGia, x.SoSao, x.NhanXet, x.NgayDanhGia, k.HoTen }).ToListAsync(ct);
            return Results.Ok(new { trang = page, kichThuocTrang = size, tongSo = total, diemTrungBinh = average, duLieu = data });
        });

        app.MapGet("/api/danh-gia/cua-toi", async (ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();
            var data = await db.DanhGia.AsNoTracking().Where(x => x.MaKhachThue == customerId)
                .OrderByDescending(x => x.NgayDanhGia).ToListAsync(ct);
            return Results.Ok(data);
        }).RequireAuthorization("Customer");
    }
}

public sealed record CreateReviewRequest(string MaChiTietHopDong, byte SoSao, string? NhanXet);
