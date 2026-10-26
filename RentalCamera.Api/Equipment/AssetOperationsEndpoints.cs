using System.Data;
using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Equipment;

public static class AssetOperationsEndpoints
{
    private static readonly string[] MaintenanceStates = ["MOI_TAO", "DANG_XU_LY", "HOAN_TAT", "HUY"];
    private static readonly string[] DamageLevels = ["NHE", "TRUNG_BINH", "NANG"];
    private static readonly string[] DamageStates = ["CHUA_SUA", "DANG_SUA", "DA_SUA", "KHONG_SUA"];
    private static readonly string[] BranchStates = ["HOAT_DONG", "TAM_KHOA"];

    public static void MapAssetOperationsEndpoints(this IEndpointRouteBuilder app)
    {
        MapBranchEndpoints(app);
        MapMaintenanceEndpoints(app);
        MapDamageEndpoints(app);
    }

    private static void MapBranchEndpoints(IEndpointRouteBuilder app)
    {
        app.MapGet("/api/cua-hang/quan-ly", async (
            RentalCameraContext db, string? trangThai, CancellationToken ct) =>
        {
            var state = string.IsNullOrWhiteSpace(trangThai) ? null : trangThai.Trim().ToUpperInvariant();
            if (state is not null && !BranchStates.Contains(state))
                return Results.BadRequest(new { loi = "Trạng thái chi nhánh không hợp lệ." });

            var query = db.CuaHang.AsNoTracking().AsQueryable();
            if (state is not null) query = query.Where(x => x.TrangThai == state);
            var data = await query.OrderBy(x => x.TenCuaHang)
                .Select(x => new
                {
                    x.MaCuaHang, x.TenCuaHang, x.DiaChi, x.SoDienThoai, x.Email, x.MoTa, x.TrangThai,
                    SoNhanVien = db.NhanVien.Count(n => n.MaCuaHang == x.MaCuaHang && n.TrangThai == "HOAT_DONG"),
                    SoThietBi = db.ThietBi.Count(t => t.MaCuaHang == x.MaCuaHang)
                }).ToListAsync(ct);
            return Results.Ok(data);
        }).RequireAuthorization("Admin");

        app.MapGet("/api/cua-hang/{id}", async (
            string id, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            if (!scope.IsAdmin && scope.StoreId != id) return Results.Forbid();
            var item = await db.CuaHang.AsNoTracking().Where(x => x.MaCuaHang == id)
                .Select(x => new
                {
                    x.MaCuaHang, x.TenCuaHang, x.DiaChi, x.SoDienThoai, x.Email, x.MoTa, x.TrangThai,
                    SoNhanVien = db.NhanVien.Count(n => n.MaCuaHang == x.MaCuaHang && n.TrangThai == "HOAT_DONG"),
                    SoThietBi = db.ThietBi.Count(t => t.MaCuaHang == x.MaCuaHang)
                }).SingleOrDefaultAsync(ct);
            return item is null ? Results.NotFound() : Results.Ok(item);
        }).RequireAuthorization("Staff");

        app.MapPost("/api/cua-hang", async (
            BranchRequest request, RentalCameraContext db, CancellationToken ct) =>
        {
            var error = ValidateBranch(request);
            if (error is not null) return Results.BadRequest(new { loi = error });
            var name = request.TenCuaHang.Trim();
            var phone = request.SoDienThoai.Trim();
            var email = NormalizeOptional(request.Email);
            if (await db.CuaHang.AnyAsync(x => x.TenCuaHang == name || x.SoDienThoai == phone ||
                    (email != null && x.Email == email), ct))
                return Results.Conflict(new { loi = "Tên, số điện thoại hoặc email chi nhánh đã tồn tại." });

            var entity = new CuaHang
            {
                MaCuaHang = ApiAccess.NewId("CH"),
                TenCuaHang = name,
                DiaChi = request.DiaChi.Trim(),
                SoDienThoai = phone,
                Email = email,
                MoTa = NormalizeOptional(request.MoTa),
                TrangThai = "HOAT_DONG"
            };
            db.CuaHang.Add(entity);
            await db.SaveChangesAsync(ct);
            return Results.Created($"/api/cua-hang/{entity.MaCuaHang}", entity);
        }).RequireAuthorization("Admin");

        app.MapPut("/api/cua-hang/{id}", async (
            string id, BranchRequest request, RentalCameraContext db, CancellationToken ct) =>
        {
            var error = ValidateBranch(request);
            if (error is not null) return Results.BadRequest(new { loi = error });
            var entity = await db.CuaHang.SingleOrDefaultAsync(x => x.MaCuaHang == id, ct);
            if (entity is null) return Results.NotFound();
            var name = request.TenCuaHang.Trim();
            var phone = request.SoDienThoai.Trim();
            var email = NormalizeOptional(request.Email);
            if (await db.CuaHang.AnyAsync(x => x.MaCuaHang != id &&
                    (x.TenCuaHang == name || x.SoDienThoai == phone || (email != null && x.Email == email)), ct))
                return Results.Conflict(new { loi = "Tên, số điện thoại hoặc email chi nhánh đã tồn tại." });

            entity.TenCuaHang = name;
            entity.DiaChi = request.DiaChi.Trim();
            entity.SoDienThoai = phone;
            entity.Email = email;
            entity.MoTa = NormalizeOptional(request.MoTa);
            await db.SaveChangesAsync(ct);
            return Results.Ok(entity);
        }).RequireAuthorization("Admin");

        app.MapPut("/api/cua-hang/{id}/trang-thai", async (
            string id, BranchStateRequest request, RentalCameraContext db, CancellationToken ct) =>
        {
            var state = request.TrangThai?.Trim().ToUpperInvariant();
            if (state is null || !BranchStates.Contains(state))
                return Results.BadRequest(new { loi = "Trạng thái chi nhánh không hợp lệ." });
            var entity = await db.CuaHang.SingleOrDefaultAsync(x => x.MaCuaHang == id, ct);
            if (entity is null) return Results.NotFound();
            if (entity.TrangThai == state)
                return Results.Ok(new { entity.MaCuaHang, entity.TrangThai, thayDoi = false });

            if (state == "TAM_KHOA")
            {
                if (await db.NhanVien.AnyAsync(x => x.MaCuaHang == id && x.TrangThai == "HOAT_DONG", ct))
                    return Results.Conflict(new { loi = "Chi nhánh còn nhân viên đang hoạt động." });
                if (await db.ThietBi.AnyAsync(x => x.MaCuaHang == id &&
                        (x.TrangThai == "DANG_GIU" || x.TrangThai == "DANG_THUE"), ct))
                    return Results.Conflict(new { loi = "Chi nhánh còn thiết bị đang giữ hoặc đang thuê." });
                if (await db.HopDong.AnyAsync(x => x.MaCuaHang == id &&
                        x.TrangThai != "DA_HUY" && x.TrangThai != "HOAN_THANH", ct))
                    return Results.Conflict(new { loi = "Chi nhánh còn hợp đồng chưa kết thúc." });
            }

            entity.TrangThai = state;
            await db.SaveChangesAsync(ct);
            return Results.Ok(new { entity.MaCuaHang, entity.TrangThai, thayDoi = true });
        }).RequireAuthorization("Admin");
    }

    private static void MapMaintenanceEndpoints(IEndpointRouteBuilder app)
    {
        var maintenance = app.MapGroup("/api/bao-tri").RequireAuthorization("Staff");

        maintenance.MapGet("", async (
            ClaimsPrincipal principal, RentalCameraContext db, string? maCuaHang,
            string? maThietBi, string? trangThai, CancellationToken ct) =>
        {
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            var query = db.PhieuBaoTri.AsNoTracking().AsQueryable();
            if (!scope.IsAdmin) query = query.Where(x => x.MaCuaHang == scope.StoreId);
            else if (!string.IsNullOrWhiteSpace(maCuaHang)) query = query.Where(x => x.MaCuaHang == maCuaHang);
            if (!string.IsNullOrWhiteSpace(maThietBi)) query = query.Where(x => x.MaThietBi == maThietBi);
            if (!string.IsNullOrWhiteSpace(trangThai)) query = query.Where(x => x.TrangThai == trangThai);
            var data = await query.OrderByDescending(x => x.ThoiGianTao).ToListAsync(ct);
            return Results.Ok(data);
        });

        maintenance.MapGet("/{id}", async (
            string id, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            var item = await db.PhieuBaoTri.AsNoTracking().SingleOrDefaultAsync(x => x.MaPhieuBaoTri == id, ct);
            if (item is null) return Results.NotFound();
            if (!scope.IsAdmin && item.MaCuaHang != scope.StoreId) return Results.Forbid();
            var damages = await db.HuHongThietBi.AsNoTracking()
                .Where(x => x.MaPhieuBaoTri == id).OrderBy(x => x.ThoiGianGhiNhan).ToListAsync(ct);
            return Results.Ok(new { phieu = item, huHong = damages });
        });

        maintenance.MapPost("", async (
            MaintenanceCreateRequest request, ClaimsPrincipal principal,
            RentalCameraContext db, CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(request.MaThietBi) || string.IsNullOrWhiteSpace(request.MoTaLoi) ||
                request.MoTaLoi.Trim().Length > 1000 || request.ChiPhiDuKien < 0 ||
                NormalizeOptional(request.GhiChu)?.Length > 1000)
                return Results.BadRequest(new { loi = "Thông tin phiếu bảo trì không hợp lệ." });
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            var device = await db.ThietBi.SingleOrDefaultAsync(x => x.MaThietBi == request.MaThietBi, ct);
            if (device is null) return Results.NotFound(new { loi = "Không tìm thấy thiết bị." });
            if (!scope.IsAdmin && device.MaCuaHang != scope.StoreId) return Results.Forbid();
            if (device.TrangThai is "DANG_GIU" or "DANG_THUE")
                return Results.Conflict(new { loi = "Thiết bị đang giữ hoặc đang thuê, chưa thể đưa đi bảo trì." });
            if (await db.PhieuBaoTri.AnyAsync(x => x.MaThietBi == device.MaThietBi &&
                    (x.TrangThai == "MOI_TAO" || x.TrangThai == "DANG_XU_LY"), ct))
                return Results.Conflict(new { loi = "Thiết bị đã có phiếu bảo trì chưa hoàn tất." });

            var entity = new PhieuBaoTri
            {
                MaPhieuBaoTri = ApiAccess.NewId("BT"),
                MaThietBi = device.MaThietBi,
                MaCuaHang = device.MaCuaHang,
                MoTaLoi = request.MoTaLoi.Trim(),
                TrangThai = "MOI_TAO",
                ChiPhiDuKien = request.ChiPhiDuKien,
                GhiChu = NormalizeOptional(request.GhiChu),
                NguoiTao = ApiAccess.AccountId(principal) ?? "SYSTEM",
                ThoiGianTao = DateTime.UtcNow
            };
            device.TrangThai = "BAO_TRI";
            db.PhieuBaoTri.Add(entity);
            await db.SaveChangesAsync(ct);
            return Results.Created($"/api/bao-tri/{entity.MaPhieuBaoTri}", entity);
        });

        maintenance.MapPut("/{id}", async (
            string id, MaintenanceUpdateRequest request, ClaimsPrincipal principal,
            RentalCameraContext db, CancellationToken ct) =>
        {
            var state = request.TrangThai?.Trim().ToUpperInvariant();
            if (string.IsNullOrWhiteSpace(request.MoTaLoi) || request.MoTaLoi.Trim().Length > 1000 ||
                request.ChiPhiDuKien < 0 || NormalizeOptional(request.GhiChu)?.Length > 1000 ||
                state is null || !MaintenanceStates.Contains(state) || state == "HOAN_TAT")
                return Results.BadRequest(new { loi = "Thông tin cập nhật phiếu bảo trì không hợp lệ." });
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            var entity = await db.PhieuBaoTri.SingleOrDefaultAsync(x => x.MaPhieuBaoTri == id, ct);
            if (entity is null) return Results.NotFound();
            if (!scope.IsAdmin && entity.MaCuaHang != scope.StoreId) return Results.Forbid();
            if (entity.TrangThai is "HOAN_TAT" or "HUY")
                return Results.Conflict(new { loi = "Phiếu bảo trì đã kết thúc." });

            entity.MoTaLoi = request.MoTaLoi.Trim();
            entity.ChiPhiDuKien = request.ChiPhiDuKien;
            entity.GhiChu = NormalizeOptional(request.GhiChu);
            entity.TrangThai = state;
            if (state == "DANG_XU_LY" && entity.ThoiGianBatDau is null) entity.ThoiGianBatDau = DateTime.UtcNow;
            if (state == "HUY")
            {
                var device = await db.ThietBi.SingleAsync(x => x.MaThietBi == entity.MaThietBi, ct);
                if (device.TrangThai == "BAO_TRI") device.TrangThai = "SAN_SANG";
            }
            await db.SaveChangesAsync(ct);
            return Results.Ok(entity);
        });

        maintenance.MapPut("/{id}/hoan-tat", async (
            string id, MaintenanceCompleteRequest request, ClaimsPrincipal principal,
            RentalCameraContext db, CancellationToken ct) =>
        {
            var deviceState = request.TrangThaiThietBi?.Trim().ToUpperInvariant();
            if (request.ChiPhiThucTe < 0 || deviceState is not ("SAN_SANG" or "HONG" or "NGUNG_KINH_DOANH") ||
                NormalizeOptional(request.TinhTrangThietBi)?.Length > 200 ||
                NormalizeOptional(request.GhiChu)?.Length > 1000)
                return Results.BadRequest(new { loi = "Chi phí hoặc trạng thái thiết bị sau bảo trì không hợp lệ." });
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            var entity = await db.PhieuBaoTri.SingleOrDefaultAsync(x => x.MaPhieuBaoTri == id, ct);
            if (entity is null) return Results.NotFound();
            if (!scope.IsAdmin && entity.MaCuaHang != scope.StoreId) return Results.Forbid();
            if (entity.TrangThai is "HOAN_TAT" or "HUY")
                return Results.Conflict(new { loi = "Phiếu bảo trì đã kết thúc." });

            var device = await db.ThietBi.SingleAsync(x => x.MaThietBi == entity.MaThietBi, ct);
            entity.TrangThai = "HOAN_TAT";
            entity.ChiPhiThucTe = request.ChiPhiThucTe;
            entity.GhiChu = NormalizeOptional(request.GhiChu) ?? entity.GhiChu;
            entity.ThoiGianBatDau ??= DateTime.UtcNow;
            entity.ThoiGianHoanTat = DateTime.UtcNow;
            device.TrangThai = deviceState;
            if (!string.IsNullOrWhiteSpace(request.TinhTrangThietBi))
                device.TinhTrang = request.TinhTrangThietBi.Trim();
            await db.SaveChangesAsync(ct);
            return Results.Ok(new { phieu = entity, device.MaThietBi, device.TrangThai, device.TinhTrang });
        });
    }

    private static void MapDamageEndpoints(IEndpointRouteBuilder app)
    {
        app.MapGet("/api/thiet-bi/{id}/hu-hong", async (
            string id, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var device = await GetAccessibleDeviceAsync(id, principal, db, ct);
            if (device.Error is not null) return device.Error;
            var data = await db.HuHongThietBi.AsNoTracking().Where(x => x.MaThietBi == id)
                .OrderByDescending(x => x.ThoiGianGhiNhan)
                .Select(x => new
                {
                    x.MaHuHong, x.MaThietBi, x.MaPhieuBaoTri, x.MoTa, x.MucDo,
                    x.ChiPhiSuaChua, x.TrangThai, x.TinhTrangSauSuaChua,
                    x.NguoiGhiNhan, x.ThoiGianGhiNhan, x.ThoiGianCapNhat,
                    LichSu = db.LichSuCapNhatHuHong.Where(h => h.MaHuHong == x.MaHuHong)
                        .OrderByDescending(h => h.ThoiGian).ToList()
                }).ToListAsync(ct);
            return Results.Ok(data);
        }).RequireAuthorization("Staff");

        app.MapPost("/api/thiet-bi/{id}/hu-hong", async (
            string id, DamageCreateRequest request, ClaimsPrincipal principal,
            RentalCameraContext db, CancellationToken ct) =>
        {
            var level = request.MucDo?.Trim().ToUpperInvariant();
            if (string.IsNullOrWhiteSpace(request.MoTa) || request.MoTa.Trim().Length > 1000 ||
                level is null || !DamageLevels.Contains(level) || request.ChiPhiSuaChua < 0)
                return Results.BadRequest(new { loi = "Thông tin hư hỏng không hợp lệ." });
            var access = await GetAccessibleDeviceAsync(id, principal, db, ct);
            if (access.Error is not null) return access.Error;
            var device = access.Device!;
            if (device.TrangThai is "DANG_GIU" or "DANG_THUE")
                return Results.Conflict(new { loi = "Thiết bị đang giữ hoặc đang thuê." });
            if (!string.IsNullOrWhiteSpace(request.MaPhieuBaoTri) && !await db.PhieuBaoTri.AnyAsync(
                    x => x.MaPhieuBaoTri == request.MaPhieuBaoTri && x.MaThietBi == id, ct))
                return Results.BadRequest(new { loi = "Phiếu bảo trì không thuộc thiết bị này." });

            var entity = new HuHongThietBi
            {
                MaHuHong = ApiAccess.NewId("HH"),
                MaThietBi = id,
                MaPhieuBaoTri = NormalizeOptional(request.MaPhieuBaoTri),
                MoTa = request.MoTa.Trim(),
                MucDo = level,
                ChiPhiSuaChua = request.ChiPhiSuaChua,
                TrangThai = "CHUA_SUA",
                NguoiGhiNhan = ApiAccess.AccountId(principal) ?? "SYSTEM",
                ThoiGianGhiNhan = DateTime.UtcNow
            };
            if (device.TrangThai != "BAO_TRI" && device.TrangThai != "NGUNG_KINH_DOANH")
                device.TrangThai = "HONG";
            db.HuHongThietBi.Add(entity);
            await db.SaveChangesAsync(ct);
            return Results.Created($"/api/thiet-bi/{id}/hu-hong", entity);
        }).RequireAuthorization("Staff");

        app.MapPut("/api/hu-hong/{id}", async (
            string id, DamageUpdateRequest request, ClaimsPrincipal principal,
            RentalCameraContext db, CancellationToken ct) =>
        {
            var state = request.TrangThai?.Trim().ToUpperInvariant();
            if (state is null || !DamageStates.Contains(state) || request.ChiPhiSuaChua < 0 ||
                NormalizeOptional(request.TinhTrangSauSuaChua)?.Length > 500 ||
                NormalizeOptional(request.GhiChu)?.Length > 1000)
                return Results.BadRequest(new { loi = "Trạng thái hoặc chi phí sửa chữa không hợp lệ." });
            var entity = await db.HuHongThietBi.SingleOrDefaultAsync(x => x.MaHuHong == id, ct);
            if (entity is null) return Results.NotFound();
            var access = await GetAccessibleDeviceAsync(entity.MaThietBi, principal, db, ct);
            if (access.Error is not null) return access.Error;

            db.LichSuCapNhatHuHong.Add(new LichSuCapNhatHuHong
            {
                MaLichSu = ApiAccess.NewId("LSHH"),
                MaHuHong = entity.MaHuHong,
                TrangThaiCu = entity.TrangThai,
                TrangThaiMoi = state,
                ChiPhiCu = entity.ChiPhiSuaChua,
                ChiPhiMoi = request.ChiPhiSuaChua,
                NguoiThaoTac = ApiAccess.AccountId(principal) ?? "SYSTEM",
                GhiChu = NormalizeOptional(request.GhiChu),
                ThoiGian = DateTime.UtcNow
            });
            entity.TrangThai = state;
            entity.ChiPhiSuaChua = request.ChiPhiSuaChua;
            entity.TinhTrangSauSuaChua = NormalizeOptional(request.TinhTrangSauSuaChua);
            entity.ThoiGianCapNhat = DateTime.UtcNow;
            await db.SaveChangesAsync(ct);
            return Results.Ok(entity);
        }).RequireAuthorization("Staff");
    }

    private static async Task<DeviceAccessResult> GetAccessibleDeviceAsync(
        string id, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct)
    {
        var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
        if (scope is null) return new(null, Results.Forbid());
        var device = await db.ThietBi.SingleOrDefaultAsync(x => x.MaThietBi == id, ct);
        if (device is null) return new(null, Results.NotFound());
        if (!scope.IsAdmin && device.MaCuaHang != scope.StoreId)
            return new(null, Results.Forbid());
        return new(device, null);
    }

    private static string? ValidateBranch(BranchRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.TenCuaHang) || request.TenCuaHang.Trim().Length > 200 ||
            string.IsNullOrWhiteSpace(request.DiaChi) || request.DiaChi.Trim().Length > 500 ||
            string.IsNullOrWhiteSpace(request.SoDienThoai) || request.SoDienThoai.Trim().Length > 15 ||
            NormalizeOptional(request.MoTa)?.Length > 500)
            return "Tên, địa chỉ hoặc số điện thoại chi nhánh không hợp lệ.";
        if (!string.IsNullOrWhiteSpace(request.Email) &&
            (!request.Email.Contains('@') || request.Email.Trim().Length > 255))
            return "Email chi nhánh không hợp lệ.";
        return null;
    }

    private static string? NormalizeOptional(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private sealed record DeviceAccessResult(ThietBi? Device, IResult? Error);
}

public sealed record BranchRequest(
    string TenCuaHang, string DiaChi, string SoDienThoai, string? Email, string? MoTa);
public sealed record BranchStateRequest(string TrangThai);
public sealed record MaintenanceCreateRequest(
    string MaThietBi, string MoTaLoi, decimal? ChiPhiDuKien, string? GhiChu);
public sealed record MaintenanceUpdateRequest(
    string MoTaLoi, string TrangThai, decimal? ChiPhiDuKien, string? GhiChu);
public sealed record MaintenanceCompleteRequest(
    decimal ChiPhiThucTe, string TrangThaiThietBi, string? TinhTrangThietBi, string? GhiChu);
public sealed record DamageCreateRequest(
    string MoTa, string MucDo, decimal ChiPhiSuaChua, string? MaPhieuBaoTri);
public sealed record DamageUpdateRequest(
    string TrangThai, decimal ChiPhiSuaChua, string? TinhTrangSauSuaChua, string? GhiChu);
