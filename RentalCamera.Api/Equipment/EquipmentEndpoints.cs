using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;
using RentalCamera.Api.Rental;

namespace RentalCamera.Api.Equipment;

public static class EquipmentEndpoints
{
    private static readonly string[] ValidStates =
        ["SAN_SANG", "DU_PHONG", "DANG_GIU", "DANG_THUE", "BAO_TRI", "HONG", "NGUNG_KINH_DOANH"];

    public static void MapEquipmentEndpoints(this IEndpointRouteBuilder app)
    {
        var devices = app.MapGroup("/api/thiet-bi").RequireAuthorization("Staff");
        devices.MapGet("", async (
            ClaimsPrincipal principal, RentalCameraContext db, string? maCuaHang,
            string? maDongMay, string? trangThai, CancellationToken ct) =>
        {
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            var query = db.ThietBi.AsNoTracking().AsQueryable();
            if (!scope.IsAdmin) query = query.Where(x => x.MaCuaHang == scope.StoreId);
            else if (!string.IsNullOrWhiteSpace(maCuaHang)) query = query.Where(x => x.MaCuaHang == maCuaHang);
            if (!string.IsNullOrWhiteSpace(maDongMay)) query = query.Where(x => x.MaDongMay == maDongMay);
            if (!string.IsNullOrWhiteSpace(trangThai)) query = query.Where(x => x.TrangThai == trangThai);
            var data = await query.OrderBy(x => x.MaCuaHang).ThenBy(x => x.MaDongMay).ThenBy(x => x.SoSerial)
                .Select(x => new
                {
                    x.MaThietBi, x.MaDongMay, x.DongMay.TenDongMay, x.MaCuaHang,
                    x.CuaHang.TenCuaHang, x.SoSerial, x.TinhTrang, x.TrangThai, x.NgayNhap,
                    x.DongMay.MaDanhMuc, x.DongMay.DanhMuc.TenDanhMuc,
                    x.DongMay.MaThuongHieu, x.DongMay.ThuongHieu.TenThuongHieu,
                    x.DongMay.GiaThueNgay, x.DongMay.TienCoc, x.DongMay.PhanTramGiamGia,
                    x.DongMay.TGBatDau, x.DongMay.TGKetThuc,
                    AnhDaiDien = x.DongMay.AnhThietBi.Where(a => a.LaAnhDaiDien)
                        .Select(a => a.DuongDanAnh).FirstOrDefault()
                }).ToListAsync(ct);
            return Results.Ok(data);
        });
        devices.MapGet("/{id}", async (string id, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            var item = await db.ThietBi.AsNoTracking().Where(x => x.MaThietBi == id)
                .Select(x => new
                {
                    x.MaThietBi, x.MaDongMay, x.DongMay.TenDongMay, x.MaCuaHang,
                    x.CuaHang.TenCuaHang, x.SoSerial, x.TinhTrang, x.TrangThai, x.NgayNhap,
                    x.DongMay.MoTa, x.DongMay.MaDanhMuc, x.DongMay.DanhMuc.TenDanhMuc,
                    x.DongMay.MaThuongHieu, x.DongMay.ThuongHieu.TenThuongHieu,
                    x.DongMay.GiaThueNgay, x.DongMay.TienCoc, x.DongMay.PhanTramGiamGia,
                    x.DongMay.TGBatDau, x.DongMay.TGKetThuc,
                    Anh = x.DongMay.AnhThietBi.OrderBy(a => a.ThuTuHienThi)
                        .Select(a => new
                        {
                            a.MaAnh, a.DuongDanAnh, a.LaAnhDaiDien, a.ThuTuHienThi
                        }).ToList(),
                    RowVersion = Convert.ToBase64String(x.RowVersion)
                }).FirstOrDefaultAsync(ct);
            if (item is null) return Results.NotFound();
            if (!scope.IsAdmin && item.MaCuaHang != scope.StoreId) return Results.Forbid();
            return Results.Ok(item);
        });
        devices.MapPost("", async (DeviceRequest request, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            var storeId = scope.IsAdmin ? request.MaCuaHang : scope.StoreId!;
            var error = ValidateDevice(request, storeId);
            if (error is not null) return Results.BadRequest(new { loi = error });
            if (!await db.CuaHang.AnyAsync(x => x.MaCuaHang == storeId, ct) ||
                !await db.DongMay.AnyAsync(x => x.MaDongMay == request.MaDongMay, ct))
                return Results.BadRequest(new { loi = "Cửa hàng hoặc dòng máy không tồn tại." });
            if (await db.ThietBi.AnyAsync(x => x.SoSerial == request.SoSerial.Trim(), ct))
                return Results.Conflict(new { loi = "Số serial đã tồn tại." });
            var entity = new ThietBi
            {
                MaThietBi = ApiAccess.NewId("TB"), MaDongMay = request.MaDongMay,
                MaCuaHang = storeId, SoSerial = request.SoSerial.Trim(),
                TinhTrang = request.TinhTrang.Trim(), TrangThai = request.TrangThai,
                NgayNhap = request.NgayNhap
            };
            db.ThietBi.Add(entity);
            await db.SaveChangesAsync(ct);
            return Results.Created($"/api/thiet-bi/{entity.MaThietBi}", entity);
        });
        devices.MapPut("/{id}", async (string id, UpdateDeviceRequest request, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            var entity = await db.ThietBi.SingleOrDefaultAsync(x => x.MaThietBi == id, ct);
            if (entity is null) return Results.NotFound();
            if (!scope.IsAdmin && entity.MaCuaHang != scope.StoreId) return Results.Forbid();
            if (string.IsNullOrWhiteSpace(request.SoSerial) || string.IsNullOrWhiteSpace(request.TinhTrang))
                return Results.BadRequest();
            if (await db.ThietBi.AnyAsync(x => x.MaThietBi != id && x.SoSerial == request.SoSerial.Trim(), ct))
                return Results.Conflict(new { loi = "Số serial đã tồn tại." });
            entity.SoSerial = request.SoSerial.Trim();
            entity.TinhTrang = request.TinhTrang.Trim();
            entity.NgayNhap = request.NgayNhap;
            await db.SaveChangesAsync(ct);
            return Results.Ok(entity);
        });
        devices.MapPut("/{id}/trang-thai", async (string id, DeviceStateRequest request, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            if (!ValidStates.Contains(request.TrangThai)) return Results.BadRequest(new { loi = "Trạng thái không hợp lệ." });
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            var entity = await db.ThietBi.SingleOrDefaultAsync(x => x.MaThietBi == id, ct);
            if (entity is null) return Results.NotFound();
            if (!scope.IsAdmin && entity.MaCuaHang != scope.StoreId) return Results.Forbid();
            if (entity.TrangThai == "DANG_THUE" && request.TrangThai != "DANG_THUE")
            {
                var active = await db.ChiTietHopDong.Join(db.HopDong, c => c.MaHopDong, h => h.MaHopDong, (c, h) => new { c, h })
                    .AnyAsync(x => x.c.MaThietBi == id && x.h.TrangThai == "DANG_THUE" && x.c.NgayNhanThucTe == null, ct);
                if (active) return Results.Conflict(new { loi = "Thiết bị đang thuộc hợp đồng chưa nhận lại." });
            }
            if (entity.TrangThai == "DANG_GIU" && request.TrangThai != "DANG_GIU")
            {
                var assigned = await db.ChiTietHopDong.Join(db.HopDong,
                        c => c.MaHopDong, h => h.MaHopDong, (c, h) => new { c, h })
                    .AnyAsync(x => x.c.MaThietBi == id && x.c.NgayGiaoThucTe == null &&
                        x.h.TrangThai == "CHO_BAN_GIAO", ct);
                if (assigned)
                    return Results.Conflict(new
                    {
                        loi = "Thiết bị đang giữ cho hợp đồng chờ bàn giao; hãy dùng nghiệp vụ thay máy dự phòng."
                    });
            }
            entity.TrangThai = request.TrangThai;
            if (!string.IsNullOrWhiteSpace(request.TinhTrang)) entity.TinhTrang = request.TinhTrang.Trim();
            await db.SaveChangesAsync(ct);
            return Results.Ok(new { entity.MaThietBi, entity.TrangThai, entity.TinhTrang });
        });
        devices.MapDelete("/{id}", async (string id, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            var entity = await db.ThietBi.SingleOrDefaultAsync(x => x.MaThietBi == id, ct);
            if (entity is null) return Results.NotFound(new { loi = "Thiết bị không tồn tại.", code = "DEVICE_NOT_FOUND" });
            if (!scope.IsAdmin && entity.MaCuaHang != scope.StoreId) return Results.Forbid();
            if (await db.ChiTietHopDong.AnyAsync(x => x.MaThietBi == id, ct))
                return Results.Conflict(new { loi = "Thiết bị đã phát sinh hợp đồng; chỉ có thể ngừng kinh doanh.", code = "DEVICE_HAS_CONTRACT" });
            db.ThietBi.Remove(entity); await db.SaveChangesAsync(ct); return Results.NoContent();
        });
        devices.MapGet("/{id}/lich-su", async (string id, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            var device = await db.ThietBi.AsNoTracking().SingleOrDefaultAsync(x => x.MaThietBi == id, ct);
            if (device is null) return Results.NotFound();
            if (!scope.IsAdmin && device.MaCuaHang != scope.StoreId) return Results.Forbid();
            var history = await db.ChiTietHopDong.AsNoTracking().Where(x => x.MaThietBi == id)
                .Join(db.HopDong, c => c.MaHopDong, h => h.MaHopDong, (c, h) => new
                {
                    h.MaHopDong, h.MaKhachThue, h.TrangThai, h.ThoiGianBanGiao,
                    h.ThoiGianTraDuKien, c.NgayGiaoThucTe, c.NgayNhanThucTe,
                    c.TinhTrangLucGiao, c.TinhTrangLucNhan, c.CoHuHong
                }).OrderByDescending(x => x.ThoiGianBanGiao).ToListAsync(ct);
            return Results.Ok(history);
        });

        app.MapGet("/api/lich-thue", async (
            ClaimsPrincipal principal, RentalCameraContext db, string? maCuaHang,
            string? maThietBi, DateTime? tuNgay, DateTime? denNgay, CancellationToken ct) =>
        {
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            var query = db.ChiTietHopDong.AsNoTracking().Join(db.HopDong,
                c => c.MaHopDong, h => h.MaHopDong, (c, h) => new { c, h });
            if (!scope.IsAdmin) query = query.Where(x => x.h.MaCuaHang == scope.StoreId);
            else if (!string.IsNullOrWhiteSpace(maCuaHang)) query = query.Where(x => x.h.MaCuaHang == maCuaHang);
            if (!string.IsNullOrWhiteSpace(maThietBi)) query = query.Where(x => x.c.MaThietBi == maThietBi);
            if (tuNgay.HasValue) query = query.Where(x => x.h.ThoiGianTraDuKien >= tuNgay.Value);
            if (denNgay.HasValue) query = query.Where(x => x.h.ThoiGianBanGiao <= denNgay.Value);
            var data = await query.OrderBy(x => x.h.ThoiGianBanGiao).Select(x => new
            {
                x.h.MaHopDong, x.h.MaCuaHang, x.c.MaThietBi, x.h.ThoiGianBanGiao,
                x.h.ThoiGianTraDuKien, x.h.TrangThai
            }).ToListAsync(ct);
            return Results.Ok(data);
        }).RequireAuthorization("Staff");

        app.MapPut("/api/dong-may/{id}/gia", async (string id, PriceRequest request, RentalCameraContext db, CancellationToken ct) =>
        {
            if (request.GiaThueNgay < 0 || request.TienCoc < 0 || request.PhanTramGiamGia is < 0 or > 100)
                return Results.BadRequest(new { loi = "Giá không hợp lệ." });
            if (request.TGBatDau.HasValue != request.TGKetThuc.HasValue ||
                request.TGBatDau.HasValue && request.TGKetThuc <= request.TGBatDau)
                return Results.BadRequest(new { loi = "Khoảng thời gian giảm giá không hợp lệ." });
            var model = await db.DongMay.SingleOrDefaultAsync(x => x.MaDongMay == id, ct);
            if (model is null) return Results.NotFound();
            model.GiaThueNgay = request.GiaThueNgay;
            model.TienCoc = request.TienCoc;
            model.PhanTramGiamGia = request.PhanTramGiamGia;
            model.TGBatDau = request.TGBatDau;
            model.TGKetThuc = request.TGKetThuc;
            await db.SaveChangesAsync(ct);
            return Results.Ok(new { model.MaDongMay, model.GiaThueNgay, model.TienCoc, model.PhanTramGiamGia,
                model.TGBatDau, model.TGKetThuc,
                phanTramGiamGiaHieuLuc = RentalPromotionPolicy.EffectiveCatalogPercent(model) });
        }).RequireAuthorization("Admin");

        app.MapPost("/api/dong-may/khuyen-mai/reset-het-han", async (RentalCameraContext db, CancellationToken ct) =>
        {
            var now = DateTime.UtcNow;
            var expired = await db.DongMay.Where(x => x.PhanTramGiamGia > 0 && x.TGKetThuc != null && x.TGKetThuc <= now)
                .ToListAsync(ct);
            foreach (var model in expired)
            {
                model.PhanTramGiamGia = 0;
                model.TGBatDau = null;
                model.TGKetThuc = null;
            }
            await db.SaveChangesAsync(ct);
            return Results.Ok(new { soDongMayDaReset = expired.Count, thoiGianXuLyUtc = now });
        }).RequireAuthorization("Admin");
    }

    private static string? ValidateDevice(DeviceRequest request, string storeId)
    {
        if (string.IsNullOrWhiteSpace(storeId) || string.IsNullOrWhiteSpace(request.MaDongMay) ||
            string.IsNullOrWhiteSpace(request.SoSerial) || string.IsNullOrWhiteSpace(request.TinhTrang))
            return "Thiếu thông tin thiết bị.";
        if (!ValidStates.Contains(request.TrangThai)) return "Trạng thái không hợp lệ.";
        return null;
    }
}

public sealed record DeviceRequest(
    string MaDongMay, string MaCuaHang, string SoSerial,
    string TinhTrang, string TrangThai, DateOnly? NgayNhap);
public sealed record UpdateDeviceRequest(string SoSerial, string TinhTrang, DateOnly? NgayNhap);
public sealed record DeviceStateRequest(string TrangThai, string? TinhTrang);
public sealed record PriceRequest(decimal GiaThueNgay, decimal TienCoc, decimal PhanTramGiamGia,
    DateTime? TGBatDau = null, DateTime? TGKetThuc = null);
