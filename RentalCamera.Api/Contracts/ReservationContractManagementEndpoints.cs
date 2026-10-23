using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Contracts;

public static class ReservationContractManagementEndpoints
{
    private static readonly HashSet<string> HoldStatuses = new(StringComparer.OrdinalIgnoreCase)
    {
        "DANG_GIU", "HET_HAN", "DA_CHUYEN_HOP_DONG", "DA_HUY"
    };

    private static readonly HashSet<string> ContractStatuses = new(StringComparer.OrdinalIgnoreCase)
    {
        "CHO_KY", "DA_KY", "CHO_BAN_GIAO", "DANG_THUE",
        "CHO_HOAN_TRA", "HOAN_THANH", "DA_HUY"
    };

    public static void MapReservationContractManagementEndpoints(this IEndpointRouteBuilder app)
    {
        var managedHolds = app.MapGroup("/api/giu-cho/quan-ly")
            .RequireAuthorization("Staff");

        managedHolds.MapGet("", async (
            string? maCuaHang,
            string? trangThai,
            DateTime? tuNgay,
            DateTime? denNgay,
            string? tuKhoa,
            int? trang,
            int? kichThuocTrang,
            ClaimsPrincipal principal,
            RentalCameraContext db,
            CancellationToken ct) =>
        {
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            if (!ValidatePaging(trang, kichThuocTrang, out var page, out var pageSize, out var pagingError))
                return Results.BadRequest(new { loi = pagingError });
            if (!string.IsNullOrWhiteSpace(trangThai) &&
                !HoldStatuses.Contains(trangThai.Trim()))
                return Results.BadRequest(new { loi = "Trạng thái giữ chỗ không hợp lệ." });
            if (tuNgay.HasValue && denNgay.HasValue && tuNgay > denNgay)
                return Results.BadRequest(new { loi = "Từ ngày phải nhỏ hơn hoặc bằng đến ngày." });
            if (!scope.IsAdmin && !string.IsNullOrWhiteSpace(maCuaHang) &&
                !string.Equals(scope.StoreId, maCuaHang.Trim(), StringComparison.OrdinalIgnoreCase))
                return Results.Forbid();

            var utcNow = DateTime.UtcNow;
            await db.GiuCho
                .Where(x => x.TrangThai == "DANG_GIU" && x.HetHanLuc <= utcNow)
                .ExecuteUpdateAsync(setters => setters.SetProperty(x => x.TrangThai, "HET_HAN"), ct);

            var query = db.GiuCho.AsNoTracking().AsQueryable();
            if (!scope.IsAdmin)
                query = query.Where(x => x.MaCuaHang == scope.StoreId);
            else if (!string.IsNullOrWhiteSpace(maCuaHang))
                query = query.Where(x => x.MaCuaHang == maCuaHang.Trim());

            if (!string.IsNullOrWhiteSpace(trangThai))
            {
                var normalizedStatus = trangThai.Trim().ToUpperInvariant();
                query = query.Where(x => x.TrangThai == normalizedStatus);
            }
            if (tuNgay.HasValue) query = query.Where(x => x.NgayTao >= tuNgay.Value);
            if (denNgay.HasValue) query = query.Where(x => x.NgayTao <= denNgay.Value);
            if (!string.IsNullOrWhiteSpace(tuKhoa))
            {
                var keyword = tuKhoa.Trim();
                query = query.Where(x => x.MaGiuCho.Contains(keyword) ||
                    x.MaKhachThue.Contains(keyword));
            }

            var total = await query.CountAsync(ct);
            var data = await query
                .OrderByDescending(x => x.NgayTao)
                .ThenByDescending(x => x.MaGiuCho)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(x => new
                {
                    x.MaGiuCho,
                    x.MaGioHang,
                    x.MaKhachThue,
                    TenKhachHang = db.KhachThue.Where(k => k.MaKhachThue == x.MaKhachThue)
                        .Select(k => k.HoTen).FirstOrDefault(),
                    x.MaCuaHang,
                    TenCuaHang = db.CuaHang.Where(c => c.MaCuaHang == x.MaCuaHang)
                        .Select(c => c.TenCuaHang).FirstOrDefault(),
                    x.NgayTao,
                    x.HetHanLuc,
                    x.TrangThai,
                    ConHieuLuc = x.TrangThai == "DANG_GIU" && x.HetHanLuc > utcNow,
                    SoDongThietBi = db.ChiTietGiuCho.Count(c => c.MaGiuCho == x.MaGiuCho),
                    TongSoLuong = db.ChiTietGiuCho.Where(c => c.MaGiuCho == x.MaGiuCho)
                        .Sum(c => (int?)c.SoLuong) ?? 0,
                    MaHopDong = db.HopDong.Where(h => h.MaGiuCho == x.MaGiuCho)
                        .Select(h => h.MaHopDong).FirstOrDefault()
                })
                .ToListAsync(ct);

            return Results.Ok(new
            {
                duLieu = data,
                trang = page,
                kichThuocTrang = pageSize,
                tongSoBanGhi = total,
                tongSoTrang = (int)Math.Ceiling(total / (double)pageSize),
                thoiGianServer = utcNow
            });
        });

        managedHolds.MapGet("/{id}", async (
            string id,
            ClaimsPrincipal principal,
            RentalCameraContext db,
            CancellationToken ct) =>
        {
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();

            var hold = await db.GiuCho.Include(x => x.ChiTiet)
                .SingleOrDefaultAsync(x => x.MaGiuCho == id, ct);
            if (hold is null) return Results.NotFound();
            if (!scope.IsAdmin && hold.MaCuaHang != scope.StoreId) return Results.Forbid();

            if (hold.TrangThai == "DANG_GIU" && hold.HetHanLuc <= DateTime.UtcNow)
            {
                hold.TrangThai = "HET_HAN";
                await db.SaveChangesAsync(ct);
            }

            var customer = await db.KhachThue.AsNoTracking()
                .Where(x => x.MaKhachThue == hold.MaKhachThue)
                .Select(x => new
                {
                    x.MaKhachThue,
                    x.HoTen,
                    x.SoDienThoai,
                    x.Email,
                    x.CCCD
                }).SingleOrDefaultAsync(ct);
            var store = await db.CuaHang.AsNoTracking()
                .Where(x => x.MaCuaHang == hold.MaCuaHang)
                .Select(x => new { x.MaCuaHang, x.TenCuaHang, x.DiaChi, x.SoDienThoai })
                .SingleOrDefaultAsync(ct);
            var modelIds = hold.ChiTiet.Select(x => x.MaDongMay).Distinct().ToList();
            var models = await db.DongMay.AsNoTracking()
                .Where(x => modelIds.Contains(x.MaDongMay))
                .ToDictionaryAsync(x => x.MaDongMay, ct);
            var contract = await db.HopDong.AsNoTracking()
                .Where(x => x.MaGiuCho == hold.MaGiuCho)
                .Select(x => new { x.MaHopDong, x.TrangThai })
                .SingleOrDefaultAsync(ct);

            return Results.Ok(new
            {
                hold.MaGiuCho,
                hold.MaGioHang,
                hold.MaKhachThue,
                hold.MaCuaHang,
                hold.NgayTao,
                hold.HetHanLuc,
                hold.TrangThai,
                conHieuLuc = hold.TrangThai == "DANG_GIU" && hold.HetHanLuc > DateTime.UtcNow,
                khachHang = customer,
                chiNhanh = store,
                hopDong = contract,
                chiTiet = hold.ChiTiet.Select(x => new
                {
                    x.MaChiTietGiuCho,
                    x.MaChiTietGioHang,
                    x.MaDongMay,
                    TenDongMay = models.GetValueOrDefault(x.MaDongMay)?.TenDongMay,
                    x.SoLuong,
                    x.NgayBatDau,
                    x.NgayKetThuc
                })
            });
        });

        var managedContracts = app.MapGroup("/api/hop-dong/quan-ly")
            .RequireAuthorization("Staff");

        managedContracts.MapGet("", async (
            string? maCuaHang,
            string? trangThai,
            string? maHopDong,
            DateTime? tuNgay,
            DateTime? denNgay,
            int? trang,
            int? kichThuocTrang,
            ClaimsPrincipal principal,
            RentalCameraContext db,
            CancellationToken ct) =>
        {
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            if (!ValidatePaging(trang, kichThuocTrang, out var page, out var pageSize, out var pagingError))
                return Results.BadRequest(new { loi = pagingError });
            if (!string.IsNullOrWhiteSpace(trangThai) &&
                !ContractStatuses.Contains(trangThai.Trim()))
                return Results.BadRequest(new { loi = "Trạng thái hợp đồng không hợp lệ." });
            if (tuNgay.HasValue && denNgay.HasValue && tuNgay > denNgay)
                return Results.BadRequest(new { loi = "Từ ngày phải nhỏ hơn hoặc bằng đến ngày." });
            if (!scope.IsAdmin && !string.IsNullOrWhiteSpace(maCuaHang) &&
                !string.Equals(scope.StoreId, maCuaHang.Trim(), StringComparison.OrdinalIgnoreCase))
                return Results.Forbid();

            var query = db.HopDong.AsNoTracking().AsQueryable();
            if (!scope.IsAdmin)
                query = query.Where(x => x.MaCuaHang == scope.StoreId);
            else if (!string.IsNullOrWhiteSpace(maCuaHang))
                query = query.Where(x => x.MaCuaHang == maCuaHang.Trim());

            if (!string.IsNullOrWhiteSpace(trangThai))
            {
                var normalizedStatus = trangThai.Trim().ToUpperInvariant();
                query = query.Where(x => x.TrangThai == normalizedStatus);
            }
            if (!string.IsNullOrWhiteSpace(maHopDong))
            {
                var keyword = maHopDong.Trim();
                query = query.Where(x => x.MaHopDong.Contains(keyword));
            }
            if (tuNgay.HasValue) query = query.Where(x => x.NgayTaoHopDong >= tuNgay.Value);
            if (denNgay.HasValue) query = query.Where(x => x.NgayTaoHopDong <= denNgay.Value);

            var total = await query.CountAsync(ct);
            var data = await query
                .OrderByDescending(x => x.NgayTaoHopDong)
                .ThenByDescending(x => x.MaHopDong)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(x => new
                {
                    x.MaHopDong,
                    x.MaGiuCho,
                    x.MaKhachThue,
                    TenKhachHang = db.KhachThue.Where(k => k.MaKhachThue == x.MaKhachThue)
                        .Select(k => k.HoTen).FirstOrDefault(),
                    x.MaNhanVien,
                    x.MaCuaHang,
                    TenCuaHang = db.CuaHang.Where(c => c.MaCuaHang == x.MaCuaHang)
                        .Select(c => c.TenCuaHang).FirstOrDefault(),
                    x.NgayTaoHopDong,
                    x.NgayKy,
                    x.ThoiGianBanGiao,
                    x.ThoiGianTraDuKien,
                    x.TongTien,
                    x.TongTienCoc,
                    x.TrangThai,
                    SoLuongThietBi = db.ChiTietGiuCho.Where(c => c.MaGiuCho == x.MaGiuCho)
                        .Sum(c => (int?)c.SoLuong) ?? 0
                })
                .ToListAsync(ct);

            return Results.Ok(new
            {
                duLieu = data,
                trang = page,
                kichThuocTrang = pageSize,
                tongSoBanGhi = total,
                tongSoTrang = (int)Math.Ceiling(total / (double)pageSize)
            });
        });

        app.MapGet("/api/hop-dong/{id}/lich-su-trang-thai", async (
            string id,
            ClaimsPrincipal principal,
            RentalCameraContext db,
            CancellationToken ct) =>
        {
            if (!await ApiAccess.CanAccessContractAsync(id, principal, db, ct))
                return Results.Forbid();
            if (!await db.HopDong.AsNoTracking().AnyAsync(x => x.MaHopDong == id, ct))
                return Results.NotFound();

            var rows = await db.LichSuTrangThaiHopDong.AsNoTracking()
                .Where(x => x.MaHopDong == id)
                .OrderByDescending(x => x.ThoiGian)
                .ThenByDescending(x => x.MaLichSu)
                .Select(x => new
                {
                    x.MaLichSu,
                    x.MaHopDong,
                    x.TrangThaiCu,
                    x.TrangThaiMoi,
                    x.NguoiThaoTac,
                    x.VaiTroNguoiThaoTac,
                    x.LyDo,
                    x.ThoiGian
                }).ToListAsync(ct);
            return Results.Ok(rows);
        }).RequireAuthorization();
    }

    private static bool ValidatePaging(
        int? requestedPage,
        int? requestedPageSize,
        out int page,
        out int pageSize,
        out string? error)
    {
        page = requestedPage ?? 1;
        pageSize = requestedPageSize ?? 20;
        error = null;
        if (page < 1)
        {
            error = "Trang phải lớn hơn hoặc bằng 1.";
            return false;
        }
        if (pageSize is < 1 or > 100)
        {
            error = "Kích thước trang phải từ 1 đến 100.";
            return false;
        }
        return true;
    }
}
