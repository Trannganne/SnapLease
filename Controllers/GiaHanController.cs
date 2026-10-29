using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Data;
using RentalCamera.Models;
namespace RentalCamera.Controllers;
public class GiaHanController:BaseController {
private readonly RentalCameraDbContext db;public GiaHanController(RentalCameraDbContext db)=>this.db=db;
public async Task<IActionResult> Index(){var rows=await db.PhuLuc.AsNoTracking().OrderByDescending(x=>x.NgayLap).ToListAsync();return View(rows);}
public async Task<IActionResult> Details(string id){var x=await db.PhuLuc.AsNoTracking().FirstOrDefaultAsync(x=>x.MaPhuLuc==id);if(x==null)return NotFound();var h=await db.HopDong.AsNoTracking().FirstOrDefaultAsync(z=>z.MaHopDong==x.MaHopDong);if(h==null)return NotFound();ViewBag.HopDong=h;
var devices=await db.ChiTietHopDong.AsNoTracking().Where(z=>z.MaHopDong==h.MaHopDong).Select(z=>z.MaThietBi).ToListAsync();ViewBag.Devices=await db.ThietBi.AsNoTracking().Where(z=>devices.Contains(z.MaThietBi)).ToListAsync();
ViewBag.Conflicts=await (from c in db.ChiTietHopDong join other in db.HopDong on c.MaHopDong equals other.MaHopDong where devices.Contains(c.MaThietBi) && other.MaHopDong!=h.MaHopDong && other.TrangThai!="HUY" && other.ThoiGianBanGiao<x.ThoiHanTraMoi && other.ThoiGianTraDuKien>h.ThoiGianTraDuKien select other.MaHopDong).Distinct().ToListAsync();return View(x);}
[HttpPost,ValidateAntiForgeryToken]public async Task<IActionResult> Review(string id,string decision,string? reason){if(HttpContext.Session.GetString("Role") is not ("ADMIN" or "NHAN_VIEN"))return Forbid();
var x=await db.PhuLuc.FindAsync(id);if(x==null)return NotFound();if(x.TrangThai!="CHO_DUYET"){TempData["Error"]="Yêu cầu đã được xử lý.";return RedirectToAction("Details",new{id});}
if(decision=="TU_CHOI"){if(string.IsNullOrWhiteSpace(reason)){TempData["Error"]="Cần nhập lý do từ chối.";return RedirectToAction("Details",new{id});}x.TrangThai="TU_CHOI";x.GhiChu=(x.GhiChu??"")+" | Từ chối: "+reason.Trim();await db.SaveChangesAsync();return RedirectToAction("Details",new{id});}
if(decision!="DA_DUYET")return BadRequest();
var h=await db.HopDong.FindAsync(x.MaHopDong);if(h==null)return NotFound();if(x.ThoiHanTraMoi<=h.ThoiGianTraDuKien){TempData["Error"]="Ngày trả mới phải sau ngày trả hiện tại.";return RedirectToAction("Details",new{id});}
var ids=await db.ChiTietHopDong.Where(z=>z.MaHopDong==h.MaHopDong).Select(z=>z.MaThietBi).ToListAsync();
var maintenance=await db.ThietBi.AnyAsync(z=>ids.Contains(z.MaThietBi)&&z.TrangThai=="BAO_TRI");
var conflict=await (from c in db.ChiTietHopDong join other in db.HopDong on c.MaHopDong equals other.MaHopDong where ids.Contains(c.MaThietBi)&&other.MaHopDong!=h.MaHopDong&&other.TrangThai!="HUY"&&other.ThoiGianBanGiao<x.ThoiHanTraMoi&&other.ThoiGianTraDuKien>h.ThoiGianTraDuKien select c.MaChiTietHopDong).AnyAsync();
if(maintenance||conflict){TempData["Error"]="Không thể duyệt: thiết bị đang bảo trì hoặc trùng lịch thuê. Cần xử lý lịch bảo trì tại hệ thống quản lý lịch trước khi duyệt.";return RedirectToAction("Details",new{id});}
await using var tx=await db.Database.BeginTransactionAsync();h.ThoiGianTraDuKien=x.ThoiHanTraMoi;h.TongTien+=x.ChiPhiPhatSinh;h.TongTienCoc+=x.TienCocBoSung;x.TrangThai="DA_DUYET";await db.SaveChangesAsync();await tx.CommitAsync();TempData["Ok"]="Đã duyệt gia hạn.";return RedirectToAction("Details",new{id});}
}
