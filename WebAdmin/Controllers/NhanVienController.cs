using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Data;
namespace RentalCamera.Controllers;
public class NhanVienController : BaseController {
 private readonly RentalCameraDbContext db;
 public NhanVienController(RentalCameraDbContext db)=>this.db=db;
 public async Task<IActionResult> Index(string? chiNhanh,string? q){
  var query=db.NhanVien.AsNoTracking().AsQueryable();
  if(!string.IsNullOrWhiteSpace(chiNhanh)) query=query.Where(x=>x.MaCuaHang==chiNhanh);
  if(!string.IsNullOrWhiteSpace(q)) query=query.Where(x=>x.HoTen.Contains(q)||x.MaNhanVien.Contains(q));
  ViewBag.Branches=await db.CuaHang.AsNoTracking().OrderBy(x=>x.TenCuaHang).ToListAsync();
  ViewBag.ChiNhanh=chiNhanh; ViewBag.Q=q;
  return View(await query.OrderBy(x=>x.HoTen).ToListAsync());
 }
 public async Task<IActionResult> Details(string id){var n=await db.NhanVien.AsNoTracking().FirstOrDefaultAsync(x=>x.MaNhanVien==id);if(n==null)return NotFound();ViewBag.Branch=await db.CuaHang.AsNoTracking().FirstOrDefaultAsync(x=>x.MaCuaHang==n.MaCuaHang);ViewBag.Contracts=await db.HopDong.AsNoTracking().Where(x=>x.MaNhanVien==id).OrderByDescending(x=>x.NgayKy).Take(30).ToListAsync();return View(n);}
 [HttpGet] public async Task<IActionResult> Edit(string id){var n=await db.NhanVien.FindAsync(id);if(n==null)return NotFound();ViewBag.Branches=await db.CuaHang.AsNoTracking().OrderBy(x=>x.TenCuaHang).ToListAsync();return View(n);}
 [HttpPost,ValidateAntiForgeryToken] public async Task<IActionResult> Edit(string id,string hoTen,string soDienThoai,string? email,string? diaChi,string chucVu,string maCuaHang,string trangThai){var n=await db.NhanVien.FindAsync(id);if(n==null)return NotFound();if(string.IsNullOrWhiteSpace(hoTen)||string.IsNullOrWhiteSpace(soDienThoai)||!await db.CuaHang.AnyAsync(x=>x.MaCuaHang==maCuaHang)){TempData["Error"]="Thông tin nhân viên hoặc chi nhánh không hợp lệ.";return RedirectToAction("Edit",new{id});}n.HoTen=hoTen.Trim();n.SoDienThoai=soDienThoai.Trim();n.Email=email;n.DiaChi=diaChi;n.ChucVu=chucVu;n.MaCuaHang=maCuaHang;n.TrangThai=trangThai;await db.SaveChangesAsync();TempData["Ok"]="Đã cập nhật nhân viên.";return RedirectToAction("Details",new{id});}
 [HttpPost,ValidateAntiForgeryToken] public async Task<IActionResult> Delete(string id){var n=await db.NhanVien.FindAsync(id);if(n==null)return NotFound();if(await db.HopDong.AnyAsync(x=>x.MaNhanVien==id)){TempData["Error"]="Nhân viên đã có hợp đồng, không thể xóa. Hãy chỉnh sửa trạng thái thành ngừng hoạt động.";return RedirectToAction("Details",new{id});}db.NhanVien.Remove(n);try{await db.SaveChangesAsync();TempData["Ok"]="Đã xóa nhân viên.";return RedirectToAction("Index");}catch(DbUpdateException){TempData["Error"]="Không thể xóa vì nhân viên đang được tham chiếu bởi dữ liệu khác.";return RedirectToAction("Details",new{id});}}

}
