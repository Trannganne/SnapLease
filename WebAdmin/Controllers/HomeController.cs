using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Data;
using RentalCamera.ViewModels;

namespace RentalCamera.Controllers;

public class HomeController : BaseController
{
    private readonly RentalCameraDbContext _db;
    public HomeController(RentalCameraDbContext db) => _db = db;

    public async Task<IActionResult> Index(int? nam)
    {
        var now = DateTime.Now;
        var reportYear = nam.HasValue && nam.Value >= 2000 && nam.Value <= now.Year ? nam.Value : now.Year;
        var start = new DateTime(now.Year, now.Month, 1);
        var end = start.AddMonths(1);

        var vm = new DashboardVM
        {
            NamBaoCao = reportYear,
            DangThue = await _db.ThietBi.CountAsync(x => x.TrangThai == "DANG_THUE"),
            TongThietBi = await _db.ThietBi.CountAsync(),
            DonHomNay = await _db.HopDong.CountAsync(x => x.NgayKy.Date == now.Date),
            DoanhThuThang = await _db.ThanhToan
                .Where(x => x.TrangThai == "THANH_CONG" && x.ThoiGian >= start && x.ThoiGian < end &&
                            new[] { "TIEN_THUE", "PHI_GIA_HAN", "PHI_PHAT" }.Contains(x.LoaiThanhToan))
                .SumAsync(x => (decimal?)x.SoTien) ?? 0
        };

        vm.TrangThai = await _db.ThietBi
            .GroupBy(x => x.TrangThai)
            .ToDictionaryAsync(g => g.Key, g => g.Count());

        vm.PhoBien = await (
            from ct in _db.ChiTietHopDong
            join tb in _db.ThietBi on ct.MaThietBi equals tb.MaThietBi
            join dm in _db.DongMay on tb.MaDongMay equals dm.MaDongMay
            group ct by dm.TenDongMay into g
            orderby g.Count() descending
            select new { Ten = g.Key, Luot = g.Count() }
        ).Take(5).Select(x => ValueTuple.Create(x.Ten, x.Luot)).ToListAsync();

        vm.LichHomNay = await _db.HopDong
            .Include(x => x.KhachThue)
            .Where(x => x.TrangThai != "DA_HUY" && x.ThoiGianBanGiao.Date == now.Date)
            .OrderBy(x => x.ThoiGianBanGiao)
            .Take(5)
            .ToListAsync();

        vm.DonGanDay = await _db.HopDong.AsNoTracking().Include(x => x.KhachThue)
            .OrderByDescending(x => x.NgayKy).Take(5).ToListAsync();
        vm.LichSapToi = await _db.HopDong.AsNoTracking().Include(x => x.KhachThue)
            .Where(x => x.TrangThai != "DA_HUY" && x.TrangThai != "DA_HOAN_THANH" &&
                   (x.ThoiGianBanGiao >= now || x.ThoiGianTraDuKien >= now))
            .OrderBy(x => x.ThoiGianBanGiao >= now ? x.ThoiGianBanGiao : x.ThoiGianTraDuKien)
            .Take(5).ToListAsync();
        var contractStates = await _db.HopDong.AsNoTracking()
            .GroupBy(x => x.TrangThai).Select(g => new { Status = g.Key, Count = g.Count() }).ToListAsync();
        var statusCounts = contractStates.ToDictionary(x => x.Status, x => x.Count);
        int CountStatus(params string[] codes) => codes.Sum(code => statusCounts.GetValueOrDefault(code));
        vm.ViecCanXuLy["coc"] = CountStatus("CHO_THANH_TOAN_COC", "CHO_COC");
        vm.ViecCanXuLy["phanbo"] = CountStatus("CHO_PHAN_BO", "CHO_PHAN_BO_THIET_BI");
        vm.ViecCanXuLy["bangiao"] = CountStatus("CHO_BAN_GIAO");
        vm.ViecCanXuLy["quahan"] = await _db.HopDong.AsNoTracking()
            .CountAsync(x => x.TrangThai == "DANG_THUE" && x.ThoiGianTraDuKien < now);
        var yearStart = new DateTime(reportYear, 1, 1);
        var yearEnd = yearStart.AddYears(1);
        var revenues = await _db.ThanhToan.AsNoTracking()
            .Where(x => x.TrangThai == "THANH_CONG" && x.ThoiGian >= yearStart && x.ThoiGian < yearEnd &&
                new[] { "TIEN_THUE", "PHI_GIA_HAN", "PHI_PHAT" }.Contains(x.LoaiThanhToan))
            .GroupBy(x => x.ThoiGian!.Value.Month)
            .Select(g => new { Month = g.Key, Amount = g.Sum(x => x.SoTien) }).ToListAsync();
        var monthly = revenues.ToDictionary(x => x.Month, x => x.Amount);
        vm.DoanhThuTheoThang = Enumerable.Range(1, 12)
            .Select(month => monthly.GetValueOrDefault(month)).ToList();
        return View(vm);
    }
}
