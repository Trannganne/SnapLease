using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Reports;

public static class ReportEndpoints
{
    public static void MapReportEndpoints(this IEndpointRouteBuilder app)
    {
        var reports = app.MapGroup("/api/bao-cao").RequireAuthorization("Staff");

        reports.MapGet("/tong-quan", async (
            string? maCuaHang, DateTime? tuNgay, DateTime? denNgay,
            ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var filter = await ResolveFilter(maCuaHang, tuNgay, denNgay, principal, db, ct);
            if (filter is null) return Results.Forbid();
            var contracts = ContractQuery(db, filter);
            var totalContracts = await contracts.CountAsync(ct);
            var completedContracts = contracts.Where(x => x.TrangThai == "HOAN_THANH");
            var completedIds = completedContracts.Select(x => x.MaHopDong);
            var rentalRevenue = await completedContracts.SumAsync(x => (decimal?)x.TongTien, ct) ?? 0;
            var extensionRevenue = await db.PhuLuc
                .Where(x => completedIds.Contains(x.MaHopDong) && x.TrangThai == "DA_XAC_NHAN")
                .SumAsync(x => (decimal?)x.ChiPhiPhatSinh, ct) ?? 0;
            var penaltyRevenue = await db.PhieuPhat
                .Where(x => (x.TrangThai == "DA_XAC_NHAN" || x.TrangThai == "DA_THANH_TOAN") &&
                    db.ChiTietHopDong.Any(d => d.MaChiTietHopDong == x.MaChiTietHopDong && completedIds.Contains(d.MaHopDong)))
                .SumAsync(x => (decimal?)x.SoTien, ct) ?? 0;
            var revenue = rentalRevenue + extensionRevenue + penaltyRevenue;
            var available = await db.ThietBi.CountAsync(x => x.MaCuaHang == filter.StoreId && x.TrangThai == "SAN_SANG", ct);
            var rented = await db.ThietBi.CountAsync(x => x.MaCuaHang == filter.StoreId && x.TrangThai == "DANG_THUE", ct);
            return Results.Ok(new { filter.StoreId, filter.From, filter.To, tongHopDong = totalContracts, doanhThu = revenue, thietBiSanSang = available, thietBiDangThue = rented });
        });

        reports.MapGet("/doanh-thu", async (
            string? maCuaHang, DateTime? tuNgay, DateTime? denNgay,
            ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var filter = await ResolveFilter(maCuaHang, tuNgay, denNgay, principal, db, ct);
            if (filter is null) return Results.Forbid();
            var completedContracts = ContractQuery(db, filter).Where(x => x.TrangThai == "HOAN_THANH");
            var completedIds = completedContracts.Select(x => x.MaHopDong);

            var rentalRows = await completedContracts
                .GroupBy(x => new
                {
                    Nam = (x.NgayKy ?? x.NgayTaoHopDong).Year,
                    Thang = (x.NgayKy ?? x.NgayTaoHopDong).Month
                })
                .Select(x => new { x.Key.Nam, x.Key.Thang, SoGiaoDich = x.Count(), TongTien = x.Sum(y => y.TongTien) })
                .ToListAsync(ct);
            var extensionRows = await db.PhuLuc.AsNoTracking()
                .Where(x => completedIds.Contains(x.MaHopDong) && x.TrangThai == "DA_XAC_NHAN")
                .GroupBy(x => new { Nam = x.NgayLap.Year, Thang = x.NgayLap.Month })
                .Select(x => new { x.Key.Nam, x.Key.Thang, SoGiaoDich = x.Count(), TongTien = x.Sum(y => y.ChiPhiPhatSinh) })
                .ToListAsync(ct);
            var penaltyRows = await db.PhieuPhat.AsNoTracking()
                .Where(x => (x.TrangThai == "DA_XAC_NHAN" || x.TrangThai == "DA_THANH_TOAN") &&
                    db.ChiTietHopDong.Any(d => d.MaChiTietHopDong == x.MaChiTietHopDong && completedIds.Contains(d.MaHopDong)))
                .GroupBy(x => new { Nam = x.NgayLap.Year, Thang = x.NgayLap.Month })
                .Select(x => new { x.Key.Nam, x.Key.Thang, SoGiaoDich = x.Count(), TongTien = x.Sum(y => y.SoTien) })
                .ToListAsync(ct);

            var data = rentalRows.Select(x => new RevenueItem(x.Nam, x.Thang, "TIEN_THUE", x.SoGiaoDich, x.TongTien))
                .Concat(extensionRows.Select(x => new RevenueItem(x.Nam, x.Thang, "PHI_GIA_HAN", x.SoGiaoDich, x.TongTien)))
                .Concat(penaltyRows.Select(x => new RevenueItem(x.Nam, x.Thang, "PHI_PHAT", x.SoGiaoDich, x.TongTien)))
                .Where(x => x.TongTien > 0)
                .OrderBy(x => x.Nam).ThenBy(x => x.Thang).ThenBy(x => x.LoaiThanhToan)
                .ToList();
            return Results.Ok(new { filter.StoreId, filter.From, filter.To, duLieu = data });
        });

        reports.MapGet("/don-thue", async (
            string? maCuaHang, DateTime? tuNgay, DateTime? denNgay,
            ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var filter = await ResolveFilter(maCuaHang, tuNgay, denNgay, principal, db, ct);
            if (filter is null) return Results.Forbid();
            var data = await ContractQuery(db, filter).GroupBy(x => x.TrangThai)
                .Select(x => new { TrangThai = x.Key, SoLuong = x.Count(), TongTien = x.Sum(y => y.TongTien) })
                .OrderBy(x => x.TrangThai).ToListAsync(ct);
            return Results.Ok(new { filter.StoreId, filter.From, filter.To, duLieu = data });
        });

        reports.MapGet("/tinh-trang-thiet-bi", async (
            string? maCuaHang, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var filter = await ResolveFilter(maCuaHang, null, null, principal, db, ct);
            if (filter is null) return Results.Forbid();
            var data = await db.ThietBi.AsNoTracking().Where(x => x.MaCuaHang == filter.StoreId)
                .GroupBy(x => new { x.TrangThai, x.TinhTrang })
                .Select(x => new { x.Key.TrangThai, x.Key.TinhTrang, SoLuong = x.Count() })
                .OrderBy(x => x.TrangThai).ThenBy(x => x.TinhTrang).ToListAsync(ct);
            return Results.Ok(new { filter.StoreId, duLieu = data });
        });
    }

    private static IQueryable<HopDong> ContractQuery(RentalCameraContext db, ReportFilter filter) =>
        db.HopDong.AsNoTracking().Where(x =>
            x.MaCuaHang == filter.StoreId &&
            x.NgayTaoHopDong >= filter.From && x.NgayTaoHopDong < filter.To);

    private static async Task<ReportFilter?> ResolveFilter(
        string? requestedStore, DateTime? from, DateTime? to, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct)
    {
        var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
        if (scope is null) return null;
        var store = scope.IsAdmin ? requestedStore : scope.StoreId;
        if (string.IsNullOrWhiteSpace(store)) return null;
        if (!scope.IsAdmin && requestedStore is not null && requestedStore != scope.StoreId) return null;
        var start = from?.Date ?? DateTime.Today.AddMonths(-1);
        var end = (to?.Date ?? DateTime.Today).AddDays(1);
        if (end <= start) return null;
        return new ReportFilter(store, start, end);
    }

    private sealed record ReportFilter(string StoreId, DateTime From, DateTime To);
    private sealed record RevenueItem(int Nam, int Thang, string LoaiThanhToan, int SoGiaoDich, decimal TongTien);
}
