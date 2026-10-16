using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Data;
using RentalCamera.ViewModels;

namespace RentalCamera.Controllers;

public class LichThueController : BaseController
{
    private readonly RentalCameraDbContext _db;

    public LichThueController(RentalCameraDbContext db)
    {
        _db = db;
    }

    public async Task<IActionResult> Index(
        DateTime? tuNgay,
        DateTime? denNgay,
        string? q)
    {
        // Khoảng thời gian cần kiểm tra
        var fromDate = tuNgay ?? DateTime.Today;
        var toDate = denNgay ?? DateTime.Today.AddDays(3);

        // Ngày kết thúc phải sau ngày bắt đầu
        if (toDate <= fromDate)
        {
            toDate = fromDate.AddDays(1);
        }

        // Danh sách hợp đồng gần đây
        var contracts = await _db.HopDong
            .Include(x => x.KhachThue)
            .Where(x =>
                x.ThoiGianTraDuKien >= fromDate.Date.AddDays(-7) &&
                x.ThoiGianBanGiao < fromDate.Date.AddDays(14))
            .OrderBy(x => x.ThoiGianBanGiao)
            .ToListAsync();

        // Danh sách thiết bị
        var devices = _db.ThietBi
            .Include(x => x.DongMay)
            .AsQueryable();

        // Tìm kiếm
        if (!string.IsNullOrWhiteSpace(q))
        {
            devices = devices.Where(x =>
                x.MaThietBi.Contains(q) ||
                x.SoSerial.Contains(q) ||
                (x.DongMay != null &&
                 x.DongMay.TenDongMay.Contains(q))
            );
        }

        // Kiểm tra thiết bị đã có lịch thuê trong khoảng thời gian
        var busy = await (
            from ct in _db.ChiTietHopDong
            join hd in _db.HopDong
                on ct.MaHopDong equals hd.MaHopDong
            where hd.TrangThai != "DA_HUY"
                  && hd.ThoiGianBanGiao < toDate
                  && hd.ThoiGianTraDuKien > fromDate
            select ct.MaThietBi
        )
        .Distinct()
        .ToListAsync();

        var list = await devices
            .OrderBy(x => x.MaThietBi)
            .ToListAsync();

        var viewModel = new AvailabilityVM
        {
            TuNgay = fromDate,
            DenNgay = toDate,
            Q = q,
            HopDong = contracts,
            ThietBi = list,
            MaThietBiBan = busy.ToHashSet()
        };

        return View(viewModel);
    }
}