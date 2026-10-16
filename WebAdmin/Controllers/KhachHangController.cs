using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Data;

namespace RentalCamera.Controllers;

public class KhachHangController : BaseController
{
    private readonly RentalCameraDbContext _db;

    public KhachHangController(RentalCameraDbContext db) => _db = db;

    public async Task<IActionResult> Index(string? q)
    {
        var query = _db.KhachThue.AsQueryable();
        if (!string.IsNullOrWhiteSpace(q))
            query = query.Where(k => k.HoTen.Contains(q) || k.SoDienThoai.Contains(q));
        return View(await query.ToListAsync());
    }

    public async Task<IActionResult> Details(string id)
    {
        var customer = await _db.KhachThue.AsNoTracking()
            .FirstOrDefaultAsync(x => x.MaKhachThue == id);
        if (customer == null) return NotFound();

        ViewBag.Contracts = await _db.HopDong.AsNoTracking()
            .Where(x => x.MaKhachThue == id)
            .OrderByDescending(x => x.NgayKy)
            .ToListAsync();
        return View(customer);
    }
}
