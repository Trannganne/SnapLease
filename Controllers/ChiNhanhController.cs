using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Data;
namespace RentalCamera.Controllers;
using RentalCamera.ViewModels;
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
 public async Task<IActionResult> Details(string id,string? q,string? status,string? dongMay){var branch=await db.CuaHang.AsNoTracking().FirstOrDefaultAsync(x=>x.MaCuaHang==id);if(branch==null)return NotFound();var query=db.ThietBi.AsNoTracking().Include(x=>x.DongMay).Where(x=>x.MaCuaHang==id);
 if(!string.IsNullOrWhiteSpace(q))query=query.Where(x=>x.MaThietBi.Contains(q)||x.SoSerial.Contains(q)||x.DongMay!.TenDongMay.Contains(q));
 if(!string.IsNullOrWhiteSpace(status))query=query.Where(x=>x.TrangThai==status);
 if(!string.IsNullOrWhiteSpace(dongMay))query=query.Where(x=>x.MaDongMay==dongMay);
 ViewBag.Devices=await query.OrderBy(x=>x.MaThietBi).ToListAsync();
 ViewBag.Models=await (from tb in db.ThietBi join dm in db.DongMay on tb.MaDongMay equals dm.MaDongMay where tb.MaCuaHang==id select dm).Distinct().OrderBy(x=>x.TenDongMay).ToListAsync();
 ViewBag.Images=(await db.AnhThietBi.Where(x=>x.LaAnhDaiDien).ToListAsync()).GroupBy(x=>x.MaDongMay).ToDictionary(g=>g.Key,g=>g.First().DuongDanAnh);
 ViewBag.Q=q;ViewBag.Status=status;ViewBag.DongMay=dongMay;
 // Đánh giá thuộc chi nhánh thực hiện hợp đồng
var reviews = await (
    from dg in db.DanhGia.AsNoTracking()

    join ct in db.ChiTietHopDong.AsNoTracking()
        on dg.MaChiTietHopDong equals ct.MaChiTietHopDong

    join hd in db.HopDong.AsNoTracking()
        on ct.MaHopDong equals hd.MaHopDong

    join tb in db.ThietBi.AsNoTracking()
        on ct.MaThietBi equals tb.MaThietBi

    join dm in db.DongMay.AsNoTracking()
        on tb.MaDongMay equals dm.MaDongMay

    join kh in db.KhachThue.AsNoTracking()
        on dg.MaKhachThue equals kh.MaKhachThue

    where hd.MaCuaHang == id

    orderby dg.NgayDanhGia descending

    select new BranchReviewVM
    {
        MaDanhGia = dg.MaDanhGia,
        HoTen = kh.HoTen,
        TenDongMay = dm.TenDongMay,
        SoSerial = tb.SoSerial,
        SoSao = dg.SoSao,
        NhanXet = dg.NhanXet,
        NgayDanhGia = dg.NgayDanhGia,
        TrangThaiKiemDuyet = dg.TrangThaiKiemDuyet
    }
).ToListAsync();

ViewBag.Reviews = reviews;
 return View(branch);}

 [HttpGet] public async Task<IActionResult> Edit(string id){var x=await db.CuaHang.FindAsync(id);return x==null?NotFound():View(x);}
 [HttpPost,ValidateAntiForgeryToken] public async Task<IActionResult> Edit(string id,string tenCuaHang,string diaChi,string soDienThoai,string? email,string? moTa,string trangThai){
 var x=await db.CuaHang.FindAsync(id);if(x==null)return NotFound();if(string.IsNullOrWhiteSpace(tenCuaHang)||string.IsNullOrWhiteSpace(diaChi)){TempData["Error"]="Thiếu tên hoặc địa chỉ.";return RedirectToAction("Edit",new{id});}
 x.TenCuaHang=tenCuaHang.Trim();x.DiaChi=diaChi.Trim();x.SoDienThoai=soDienThoai?.Trim()??"";x.Email=email;x.MoTa=moTa;x.TrangThai=trangThai;await db.SaveChangesAsync();TempData["Ok"]="Đã cập nhật chi nhánh.";return RedirectToAction("Details",new{id});
 }
 [HttpGet] public IActionResult Create()=>View(new RentalCamera.Models.CuaHang());
 [HttpPost,ValidateAntiForgeryToken] public async Task<IActionResult> Create(RentalCamera.Models.CuaHang input){
 if(string.IsNullOrWhiteSpace(input.MaCuaHang)||string.IsNullOrWhiteSpace(input.TenCuaHang)||string.IsNullOrWhiteSpace(input.DiaChi)){ModelState.AddModelError("","Cần mã, tên và địa chỉ chi nhánh.");return View(input);}
 if(await db.CuaHang.AnyAsync(x=>x.MaCuaHang==input.MaCuaHang)){ModelState.AddModelError("","Mã chi nhánh đã tồn tại.");return View(input);}
 db.CuaHang.Add(input);await db.SaveChangesAsync();return RedirectToAction("Index");
 }
}
