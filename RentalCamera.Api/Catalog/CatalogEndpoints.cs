using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Catalog;

public static class CatalogEndpoints
{
    public static void MapCatalogEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/cua-hang", async (RentalCameraContext db, CancellationToken ct) =>
            await db.CuaHang.AsNoTracking().Where(x => x.TrangThai == "HOAT_DONG")
                .OrderBy(x => x.TenCuaHang)
                .Select(x => new { x.MaCuaHang, x.TenCuaHang, x.DiaChi, x.SoDienThoai, x.Email, x.MoTa })
                .ToListAsync(ct));

        var categories = app.MapGroup("/api/danh-muc");
        categories.MapGet("", async (RentalCameraContext db, CancellationToken ct) =>
            await db.DanhMuc.AsNoTracking().Where(x => x.TrangThai == "HOAT_DONG")
                .OrderBy(x => x.TenDanhMuc).ToListAsync(ct));
        categories.MapPost("", async (CategoryRequest request, RentalCameraContext db, CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(request.TenDanhMuc) || request.TenDanhMuc.Length > 150)
                return Results.BadRequest(new { loi = "Tên danh mục không hợp lệ." });
            if (await db.DanhMuc.AnyAsync(x => x.TenDanhMuc == request.TenDanhMuc.Trim(), ct))
                return Results.Conflict(new { loi = "Tên danh mục đã tồn tại." });
            var entity = new DanhMuc
            {
                MaDanhMuc = ApiAccess.NewId("DM"), TenDanhMuc = request.TenDanhMuc.Trim(),
                MoTa = request.MoTa?.Trim(), TrangThai = "HOAT_DONG"
            };
            db.DanhMuc.Add(entity);
            await db.SaveChangesAsync(ct);
            return Results.Created($"/api/danh-muc/{entity.MaDanhMuc}", entity);
        }).RequireAuthorization("Admin");
        categories.MapPut("/{id}", async (string id, UpdateCategoryRequest request, RentalCameraContext db, CancellationToken ct) =>
        {
            var entity = await db.DanhMuc.SingleOrDefaultAsync(x => x.MaDanhMuc == id, ct);
            if (entity is null) return Results.NotFound();
            if (string.IsNullOrWhiteSpace(request.TenDanhMuc) ||
                request.TrangThai is not ("HOAT_DONG" or "TAM_AN"))
                return Results.BadRequest(new { loi = "Tên hoặc trạng thái danh mục không hợp lệ." });
            if (await db.DanhMuc.AnyAsync(x => x.MaDanhMuc != id && x.TenDanhMuc == request.TenDanhMuc.Trim(), ct))
                return Results.Conflict(new { loi = "Tên danh mục đã tồn tại." });
            entity.TenDanhMuc = request.TenDanhMuc.Trim();
            entity.MoTa = request.MoTa?.Trim();
            entity.TrangThai = request.TrangThai;
            await db.SaveChangesAsync(ct);
            return Results.Ok(entity);
        }).RequireAuthorization("Admin");

        var brands = app.MapGroup("/api/thuong-hieu");
        brands.MapGet("", async (RentalCameraContext db, CancellationToken ct) =>
            await db.ThuongHieu.AsNoTracking().OrderBy(x => x.TenThuongHieu).ToListAsync(ct));
        brands.MapPost("", async (BrandRequest request, RentalCameraContext db, CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(request.TenThuongHieu) || request.TenThuongHieu.Length > 150)
                return Results.BadRequest(new { loi = "Tên thương hiệu không hợp lệ." });
            if (await db.ThuongHieu.AnyAsync(x => x.TenThuongHieu == request.TenThuongHieu.Trim(), ct))
                return Results.Conflict(new { loi = "Tên thương hiệu đã tồn tại." });
            var entity = new ThuongHieu
            {
                MaThuongHieu = ApiAccess.NewId("TH"), TenThuongHieu = request.TenThuongHieu.Trim(),
                QuocGia = request.QuocGia?.Trim()
            };
            db.ThuongHieu.Add(entity);
            await db.SaveChangesAsync(ct);
            return Results.Created($"/api/thuong-hieu/{entity.MaThuongHieu}", entity);
        }).RequireAuthorization("Admin");
        brands.MapPut("/{id}", async (string id, BrandRequest request, RentalCameraContext db, CancellationToken ct) =>
        {
            var entity = await db.ThuongHieu.SingleOrDefaultAsync(x => x.MaThuongHieu == id, ct);
            if (entity is null) return Results.NotFound();
            if (string.IsNullOrWhiteSpace(request.TenThuongHieu)) return Results.BadRequest();
            if (await db.ThuongHieu.AnyAsync(x => x.MaThuongHieu != id && x.TenThuongHieu == request.TenThuongHieu.Trim(), ct))
                return Results.Conflict(new { loi = "Tên thương hiệu đã tồn tại." });
            entity.TenThuongHieu = request.TenThuongHieu.Trim();
            entity.QuocGia = request.QuocGia?.Trim();
            await db.SaveChangesAsync(ct);
            return Results.Ok(entity);
        }).RequireAuthorization("Admin");

        var models = app.MapGroup("/api/dong-may");
        models.MapGet("", async (
            RentalCameraContext db, string? tuKhoa, string? maDanhMuc, string? maThuongHieu,
            string? maCuaHang, int? trang, int? kichThuocTrang, CancellationToken ct) =>
        {
            var page = Math.Max(1, trang ?? 1);
            var pageSize = Math.Clamp(kichThuocTrang ?? 20, 1, 100);
            var query = db.DongMay.AsNoTracking().AsQueryable();
            if (!string.IsNullOrWhiteSpace(tuKhoa))
            {
                var keyword = tuKhoa.Trim();
                query = query.Where(x => x.TenDongMay.Contains(keyword) || x.ThuongHieu.TenThuongHieu.Contains(keyword));
            }
            if (!string.IsNullOrWhiteSpace(maDanhMuc)) query = query.Where(x => x.MaDanhMuc == maDanhMuc);
            if (!string.IsNullOrWhiteSpace(maThuongHieu)) query = query.Where(x => x.MaThuongHieu == maThuongHieu);
            if (!string.IsNullOrWhiteSpace(maCuaHang))
                query = query.Where(x => db.ThietBi.Any(t => t.MaDongMay == x.MaDongMay && t.MaCuaHang == maCuaHang && t.TrangThai == "SAN_SANG"));
            var total = await query.CountAsync(ct);
            var items = await query.OrderBy(x => x.TenDongMay).Skip((page - 1) * pageSize).Take(pageSize)
                .Select(x => new
                {
                    x.MaDongMay, x.TenDongMay, x.MoTa, x.GiaThueNgay, x.TienCoc, x.PhanTramGiamGia,
                    x.MaDanhMuc, x.DanhMuc.TenDanhMuc, x.MaThuongHieu, x.ThuongHieu.TenThuongHieu,
                    AnhDaiDien = x.AnhThietBi.Where(a => a.LaAnhDaiDien)
                        .Select(a => a.DuongDanAnh).FirstOrDefault(),
                    Rating = db.DanhGia.Where(r => db.ChiTietHopDong.Any(d =>
                            d.MaChiTietHopDong == r.MaChiTietHopDong && db.ThietBi.Any(t =>
                                t.MaThietBi == d.MaThietBi && t.MaDongMay == x.MaDongMay)))
                        .Average(r => (double?)r.SoSao) ?? 0d,
                    ReviewCount = db.DanhGia.Count(r => db.ChiTietHopDong.Any(d =>
                        d.MaChiTietHopDong == r.MaChiTietHopDong && db.ThietBi.Any(t =>
                            t.MaThietBi == d.MaThietBi && t.MaDongMay == x.MaDongMay))),
                    Available = db.ThietBi.Any(t =>
                        t.MaDongMay == x.MaDongMay && t.TrangThai == "SAN_SANG"),
                    BranchIds = db.ThietBi.Where(t => t.MaDongMay == x.MaDongMay)
                        .Select(t => t.MaCuaHang).Distinct().OrderBy(branchId => branchId).ToList()
                }).ToListAsync(ct);
            return Results.Ok(new { trang = page, kichThuocTrang = pageSize, tongSo = total, duLieu = items });
        });
        models.MapGet("/{id}", async (string id, RentalCameraContext db, CancellationToken ct) =>
        {
            var result = await db.DongMay.AsNoTracking().Where(x => x.MaDongMay == id)
                .Select(x => new
                {
                    x.MaDongMay, x.TenDongMay, x.MoTa, x.GiaThueNgay, x.TienCoc, x.PhanTramGiamGia,
                    x.MaDanhMuc, x.DanhMuc.TenDanhMuc, x.MaThuongHieu, x.ThuongHieu.TenThuongHieu,
                    Anh = x.AnhThietBi.OrderBy(a => a.ThuTuHienThi)
                        .Select(a => new
                        {
                            a.MaAnh, a.DuongDanAnh, a.LaAnhDaiDien, a.ThuTuHienThi
                        }).ToList(),
                    TonKho = db.ThietBi.Where(t => t.MaDongMay == id)
                        .GroupBy(t => t.MaCuaHang).Select(g => new
                        {
                            MaCuaHang = g.Key, TongSo = g.Count(),
                            SanSang = g.Count(t => t.TrangThai == "SAN_SANG")
                        }).ToList()
                }).FirstOrDefaultAsync(ct);
            return result is null ? Results.NotFound() : Results.Ok(result);
        });
        models.MapPost("", async (ModelRequest request, RentalCameraContext db, CancellationToken ct) =>
        {
            var validation = ValidateModel(request);
            if (validation is not null) return Results.BadRequest(new { loi = validation });
            if (!await db.DanhMuc.AnyAsync(x => x.MaDanhMuc == request.MaDanhMuc, ct) ||
                !await db.ThuongHieu.AnyAsync(x => x.MaThuongHieu == request.MaThuongHieu, ct))
                return Results.BadRequest(new { loi = "Danh mục hoặc thương hiệu không tồn tại." });
            if (await db.DongMay.AnyAsync(x => x.MaThuongHieu == request.MaThuongHieu && x.TenDongMay == request.TenDongMay.Trim(), ct))
                return Results.Conflict(new { loi = "Dòng máy đã tồn tại." });
            var entity = new DongMay
            {
                MaDongMay = ApiAccess.NewId("DONG"), MaDanhMuc = request.MaDanhMuc,
                MaThuongHieu = request.MaThuongHieu, TenDongMay = request.TenDongMay.Trim(),
                MoTa = request.MoTa?.Trim(), GiaThueNgay = request.GiaThueNgay,
                TienCoc = request.TienCoc, PhanTramGiamGia = request.PhanTramGiamGia
            };
            db.DongMay.Add(entity);
            await db.SaveChangesAsync(ct);
            return Results.Created($"/api/dong-may/{entity.MaDongMay}", entity);
        }).RequireAuthorization("Admin");
        models.MapPut("/{id}", async (string id, ModelRequest request, RentalCameraContext db, CancellationToken ct) =>
        {
            var entity = await db.DongMay.SingleOrDefaultAsync(x => x.MaDongMay == id, ct);
            if (entity is null) return Results.NotFound();
            var validation = ValidateModel(request);
            if (validation is not null) return Results.BadRequest(new { loi = validation });
            if (await db.DongMay.AnyAsync(x => x.MaDongMay != id && x.MaThuongHieu == request.MaThuongHieu && x.TenDongMay == request.TenDongMay.Trim(), ct))
                return Results.Conflict(new { loi = "Dòng máy đã tồn tại." });
            entity.MaDanhMuc = request.MaDanhMuc;
            entity.MaThuongHieu = request.MaThuongHieu;
            entity.TenDongMay = request.TenDongMay.Trim();
            entity.MoTa = request.MoTa?.Trim();
            entity.GiaThueNgay = request.GiaThueNgay;
            entity.TienCoc = request.TienCoc;
            entity.PhanTramGiamGia = request.PhanTramGiamGia;
            await db.SaveChangesAsync(ct);
            return Results.Ok(entity);
        }).RequireAuthorization("Admin");
        models.MapPost("/{id}/anh", async (string id, ImageRequest request, RentalCameraContext db, CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(request.DuongDanAnh) || request.ThuTuHienThi < 0)
                return Results.BadRequest();
            if (!await db.DongMay.AnyAsync(x => x.MaDongMay == id, ct)) return Results.NotFound();
            if (request.LaAnhDaiDien)
            {
                var current = await db.AnhThietBi.Where(x => x.MaDongMay == id && x.LaAnhDaiDien).ToListAsync(ct);
                current.ForEach(x => x.LaAnhDaiDien = false);
            }
            var image = new AnhThietBi
            {
                MaAnh = ApiAccess.NewId("A"), MaDongMay = id, DuongDanAnh = request.DuongDanAnh.Trim(),
                LaAnhDaiDien = request.LaAnhDaiDien, ThuTuHienThi = request.ThuTuHienThi
            };
            db.AnhThietBi.Add(image);
            await db.SaveChangesAsync(ct);
            return Results.Created($"/api/dong-may/{id}", image);
        }).RequireAuthorization("Admin");
        models.MapDelete("/{id}/anh/{maAnh}", async (string id, string maAnh, RentalCameraContext db, CancellationToken ct) =>
        {
            var image = await db.AnhThietBi.SingleOrDefaultAsync(x => x.MaAnh == maAnh && x.MaDongMay == id, ct);
            if (image is null) return Results.NotFound();
            db.AnhThietBi.Remove(image);
            await db.SaveChangesAsync(ct);
            return Results.NoContent();
        }).RequireAuthorization("Admin");
    }

    private static string? ValidateModel(ModelRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.TenDongMay) || string.IsNullOrWhiteSpace(request.MaDanhMuc) ||
            string.IsNullOrWhiteSpace(request.MaThuongHieu)) return "Thiếu thông tin dòng máy.";
        if (request.GiaThueNgay < 0 || request.TienCoc < 0 || request.PhanTramGiamGia is < 0 or > 100)
            return "Giá, tiền cọc hoặc tỷ lệ giảm giá không hợp lệ.";
        return null;
    }
}

public sealed record CategoryRequest(string TenDanhMuc, string? MoTa);
public sealed record UpdateCategoryRequest(string TenDanhMuc, string? MoTa, string TrangThai);
public sealed record BrandRequest(string TenThuongHieu, string? QuocGia);
public sealed record ModelRequest(
    string MaDanhMuc, string MaThuongHieu, string TenDongMay, string? MoTa,
    decimal GiaThueNgay, decimal TienCoc, decimal PhanTramGiamGia);
public sealed record ImageRequest(string DuongDanAnh, bool LaAnhDaiDien, int ThuTuHienThi);
