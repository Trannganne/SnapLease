using Microsoft.AspNetCore.Mvc;using Microsoft.EntityFrameworkCore;using RentalCamera.Data;using RentalCamera.ViewModels;
namespace RentalCamera.Controllers;
public class DonThueController:BaseController {
 private readonly RentalCameraDbContext _db; public DonThueController(RentalCameraDbContext db)=>_db=db;
 public async Task<IActionResult> Index(string? chiNhanh, string? trangThai, DateTime? tuNgay, DateTime? denNgay, string? maHopDong, bool quaHan = false, string? giuCho = null) {
  var contracts=_db.HopDong.TagWith("DonThue.Index.HopDong").AsNoTracking().Include(x=>x.KhachThue).AsQueryable();
  var carts=_db.GioHang.TagWith("DonThue.Index.GioHang").AsNoTracking().Include(x=>x.KhachThue).AsQueryable();
  if(!string.IsNullOrWhiteSpace(chiNhanh)){contracts=contracts.Where(x=>x.MaCuaHang==chiNhanh);carts=carts.Where(x=>_db.ChiTietGioHang.Any(ct=>ct.MaGioHang==x.MaGioHang && ct.MaCuaHang==chiNhanh));}
  if(!string.IsNullOrWhiteSpace(trangThai)){contracts=contracts.Where(x=>x.TrangThai==trangThai);carts=carts.Where(x=>x.TrangThai==trangThai);}
  if(tuNgay.HasValue){var start=tuNgay.Value.Date;contracts=contracts.Where(x=>x.ThoiGianBanGiao>=start);carts=carts.Where(x=>x.NgayTao>=start);}
  if(denNgay.HasValue){var finish=denNgay.Value.Date.AddDays(1);contracts=contracts.Where(x=>x.ThoiGianBanGiao<finish);carts=carts.Where(x=>x.NgayTao<finish);}
  if(!string.IsNullOrWhiteSpace(maHopDong)) contracts=contracts.Where(x=>x.MaHopDong.Contains(maHopDong.Trim()));
  if(quaHan) contracts=contracts.Where(x=>x.TrangThai=="DANG_THUE" && x.ThoiGianTraDuKien<DateTime.Now);
  if(!string.IsNullOrWhiteSpace(giuCho)) {
    if(giuCho=="CON_HAN") carts=carts.Where(x=>x.TrangThai=="DANG_GIU" && x.NgayTao>DateTime.Now.AddMinutes(-20));
    else if(giuCho=="HET_HAN") carts=carts.Where(x=>x.TrangThai=="DANG_GIU" && x.NgayTao<=DateTime.Now.AddMinutes(-20));
    else carts=carts.Where(x=>x.TrangThai==giuCho);
  }
  ViewBag.MaHopDong=maHopDong; ViewBag.QuaHan=quaHan; ViewBag.GiuCho=giuCho;
  ViewBag.ChiNhanh=await _db.CuaHang.TagWith("DonThue.Index.CuaHang").AsNoTracking().OrderBy(x=>x.TenCuaHang).ToListAsync();
  ViewBag.ChiNhanhDaChon=chiNhanh;
  ViewBag.TrangThaiDaChon=trangThai;
  ViewBag.TuNgay=tuNgay?.ToString("yyyy-MM-dd");
  ViewBag.DenNgay=denNgay?.ToString("yyyy-MM-dd");
  var danhSachGioHang = await carts.OrderByDescending(x=>x.NgayTao).ToListAsync();
  var cartIds = danhSachGioHang.Select(x=>x.MaGioHang).ToList();
  var cartBranches = await _db.ChiTietGioHang.AsNoTracking()
    .Where(x=>cartIds.Contains(x.MaGioHang))
    .Select(x=>new {x.MaGioHang,x.MaCuaHang}).ToListAsync();
  var branchByCart = cartBranches.GroupBy(x=>x.MaGioHang)
    .ToDictionary(g=>g.Key, g=>g.First().MaCuaHang);
  foreach(var cart in danhSachGioHang)
    cart.MaCuaHang=branchByCart.TryGetValue(cart.MaGioHang, out var branch) ? branch : "";
  var danhSachHopDong = await contracts.OrderByDescending(x=>x.NgayKy).ToListAsync();
  return View(new OrderVM { GioHang = danhSachGioHang, HopDong = danhSachHopDong });
 }
 public async Task<IActionResult> GiuChoDetails(string id) {
   var cart=await _db.GioHang.AsNoTracking().Include(x=>x.KhachThue).FirstOrDefaultAsync(x=>x.MaGioHang==id);
   if(cart==null)return NotFound();
   ViewBag.Items=await _db.ChiTietGioHang.AsNoTracking().Include(x=>x.DongMay).Where(x=>x.MaGioHang==id).ToListAsync();
   var maCuaHang=await _db.ChiTietGioHang.AsNoTracking().Where(x=>x.MaGioHang==id).Select(x=>x.MaCuaHang).FirstOrDefaultAsync();
   cart.MaCuaHang=maCuaHang ?? "";
   ViewBag.Branch=await _db.CuaHang.AsNoTracking().FirstOrDefaultAsync(x=>x.MaCuaHang==maCuaHang);
   return View(cart);
 }
 public async Task<IActionResult> Details(string id){var h=await _db.HopDong.Include(x=>x.KhachThue).FirstOrDefaultAsync(x=>x.MaHopDong==id);if(h==null)return NotFound();var ids=await _db.ChiTietHopDong.Where(x=>x.MaHopDong==id).Select(x=>x.MaChiTietHopDong).ToListAsync();ViewBag.PhiPhat=await _db.PhieuPhat.Where(x=>ids.Contains(x.MaChiTietHopDong)).OrderByDescending(x=>x.NgayLap).ToListAsync();var ct = await _db.ChiTietHopDong.Where(x=>x.MaHopDong==id).ToListAsync();
 ViewBag.ChiTiet=ct;
 var tbIds=ct.Select(x=>x.MaThietBi).ToList();
 ViewBag.ThietBi=await _db.ThietBi.Include(x=>x.DongMay).Where(x=>tbIds.Contains(x.MaThietBi)).ToListAsync();
 ViewBag.ThanhToan=await _db.ThanhToan.Where(x=>x.MaHopDong==id).ToListAsync();
 return View(h);}
}
