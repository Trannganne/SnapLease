using Microsoft.AspNetCore.Mvc;using Microsoft.EntityFrameworkCore;using RentalCamera.Data;using RentalCamera.ViewModels;
namespace RentalCamera.Controllers;
public class DonThueController:BaseController {
 private readonly RentalCameraDbContext _db; public DonThueController(RentalCameraDbContext db)=>_db=db;
 public async Task<IActionResult> Index(string? chiNhanh, string? trangThai, DateTime? tuNgay, DateTime? denNgay) {
  var contracts=_db.HopDong.Include(x=>x.KhachThue).AsQueryable();
  var carts=_db.GioHang.Include(x=>x.KhachThue).AsQueryable();
  if(!string.IsNullOrWhiteSpace(chiNhanh)){contracts=contracts.Where(x=>x.MaCuaHang==chiNhanh);carts=carts.Where(x=>x.MaCuaHang==chiNhanh);}
  if(!string.IsNullOrWhiteSpace(trangThai)){contracts=contracts.Where(x=>x.TrangThai==trangThai);carts=carts.Where(x=>x.TrangThai==trangThai);}
  if(tuNgay.HasValue){var start=tuNgay.Value.Date;contracts=contracts.Where(x=>x.ThoiGianBanGiao>=start);carts=carts.Where(x=>x.NgayTao>=start);}
  if(denNgay.HasValue){var finish=denNgay.Value.Date.AddDays(1);contracts=contracts.Where(x=>x.ThoiGianBanGiao<finish);carts=carts.Where(x=>x.NgayTao<finish);}
  ViewBag.ChiNhanh=await _db.CuaHang.OrderBy(x=>x.TenCuaHang).ToListAsync();
  ViewBag.ChiNhanhDaChon=chiNhanh;
  ViewBag.TrangThaiDaChon=trangThai;
  ViewBag.TuNgay=tuNgay?.ToString("yyyy-MM-dd");
  ViewBag.DenNgay=denNgay?.ToString("yyyy-MM-dd");
  return View(new OrderVM{GioHang=await carts.OrderByDescending(x=>x.NgayTao).ToListAsync(),HopDong=await contracts.OrderByDescending(x=>x.NgayKy).ToListAsync()});
 }
 public async Task<IActionResult> Details(string id){var h=await _db.HopDong.Include(x=>x.KhachThue).FirstOrDefaultAsync(x=>x.MaHopDong==id);if(h==null)return NotFound();var ids=await _db.ChiTietHopDong.Where(x=>x.MaHopDong==id).Select(x=>x.MaChiTietHopDong).ToListAsync();ViewBag.PhiPhat=await _db.PhieuPhat.Where(x=>ids.Contains(x.MaChiTietHopDong)).OrderByDescending(x=>x.NgayLap).ToListAsync();var ct = await _db.ChiTietHopDong.Where(x=>x.MaHopDong==id).ToListAsync();
 ViewBag.ChiTiet=ct;
 var tbIds=ct.Select(x=>x.MaThietBi).ToList();
 ViewBag.ThietBi=await _db.ThietBi.Include(x=>x.DongMay).Where(x=>tbIds.Contains(x.MaThietBi)).ToListAsync();
 ViewBag.ThanhToan=await _db.ThanhToan.Where(x=>x.MaHopDong==id).ToListAsync();
 return View(h);}
}
