using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Data;
namespace RentalCamera.Controllers;
public class ChiNhanhController : BaseController {
 private readonly RentalCameraDbContext db;
 public ChiNhanhController(RentalCameraDbContext db) => this.db=db;
 public async Task<IActionResult> Index(string? q) {
  var query=db.CuaHang.AsNoTracking().AsQueryable();
  if(!string.IsNullOrWhiteSpace(q)) query=query.Where(x=>x.TenCuaHang.Contains(q)||x.MaCuaHang.Contains(q)||x.DiaChi.Contains(q));
  var stores=await query.OrderBy(x=>x.TenCuaHang).ToListAsync();
  var ids=stores.Select(x=>x.MaCuaHang).ToList();
  ViewBag.DeviceCounts=await db.ThietBi.AsNoTracking().Where(x=>ids.Contains(x.MaCuaHang)).GroupBy(x=>x.MaCuaHang).Select(x=>new {Id=x.Key,Count=x.Count()}).ToDictionaryAsync(x=>x.Id,x=>x.Count);
  ViewBag.StaffCounts=await db.NhanVien.AsNoTracking().Where(x=>ids.Contains(x.MaCuaHang)).GroupBy(x=>x.MaCuaHang).Select(x=>new {Id=x.Key,Count=x.Count()}).ToDictionaryAsync(x=>x.Id,x=>x.Count);
  ViewBag.Q=q;
  return View(stores);
 }
 public async Task<IActionResult> Details(string id){var branch=await db.CuaHang.AsNoTracking().FirstOrDefaultAsync(x=>x.MaCuaHang==id);if(branch==null)return NotFound();ViewBag.Devices=await db.ThietBi.AsNoTracking().Include(x=>x.DongMay).Where(x=>x.MaCuaHang==id).OrderBy(x=>x.MaThietBi).ToListAsync();return View(branch);}

}
