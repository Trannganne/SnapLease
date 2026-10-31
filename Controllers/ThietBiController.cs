using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Data;
using RentalCamera.Models;
using RentalCamera.ViewModels;
namespace RentalCamera.Controllers;
public class ThietBiController:BaseController {
 private readonly RentalCameraDbContext _db; public ThietBiController(RentalCameraDbContext db)=>_db=db;
 public async Task<IActionResult> Index(string? q,string? status,string? category,string? brand,string? modelId, decimal? giaTu, decimal? giaDen){var x=_db.ThietBi.Include(t=>t.DongMay)!.ThenInclude(d=>d!.ThuongHieu).AsQueryable();if(!string.IsNullOrWhiteSpace(modelId))x=x.Where(t=>t.MaDongMay==modelId);if(!string.IsNullOrWhiteSpace(category))x=x.Where(t=>t.DongMay!.MaDanhMuc==category);if(!string.IsNullOrWhiteSpace(brand))x=x.Where(t=>t.DongMay!.MaThuongHieu==brand);if(!string.IsNullOrWhiteSpace(q))x=x.Where(t=>t.MaThietBi.Contains(q)||t.DongMay!.TenDongMay.Contains(q)||t.SoSerial.Contains(q));if(!string.IsNullOrWhiteSpace(status))x=x.Where(t=>t.TrangThai==status);if(giaTu.HasValue)x=x.Where(t=>t.DongMay!.GiaThueNgay>=giaTu.Value);if(giaDen.HasValue)x=x.Where(t=>t.DongMay!.GiaThueNgay<=giaDen.Value);ViewBag.GiaTu=giaTu;ViewBag.GiaDen=giaDen;var items=await x.ToListAsync();var imgs=(await _db.AnhThietBi.Where(a=>a.LaAnhDaiDien).ToListAsync()).GroupBy(a=>a.MaDongMay).ToDictionary(g=>g.Key,g=>g.First().DuongDanAnh);return View(new DeviceVM{Items=items,DanhMuc=await _db.DanhMuc.ToListAsync(),ThuongHieu=await _db.ThuongHieu.ToListAsync(),Anh=imgs});}
 public async Task<IActionResult> Details(string id){var x=await _db.ThietBi.Include(t=>t.DongMay)!.ThenInclude(d=>d!.ThuongHieu).Include(t=>t.CuaHang).FirstOrDefaultAsync(t=>t.MaThietBi==id);if(x==null)return NotFound();ViewBag.Anh=await _db.AnhThietBi.Where(a=>a.MaDongMay==x.MaDongMay).OrderByDescending(a=>a.LaAnhDaiDien).ThenBy(a=>a.ThuTuHienThi).Select(a=>a.DuongDanAnh).ToListAsync();ViewBag.Lich=await (from ct in _db.ChiTietHopDong join hd in _db.HopDong on ct.MaHopDong equals hd.MaHopDong where ct.MaThietBi==id && hd.TrangThai!="DA_HUY" orderby hd.ThoiGianBanGiao descending select hd).Take(8).ToListAsync();return View(x);}
 [HttpGet] public async Task<IActionResult> Create(){ViewBag.DongMay=await _db.DongMay.OrderBy(x=>x.TenDongMay).ToListAsync();ViewBag.CuaHang=await _db.CuaHang.Where(x=>x.TrangThai=="HOAT_DONG").ToListAsync();return View(new ThietBi{NgayNhap=DateTime.Today,TinhTrang="TOT",TrangThai="SAN_SANG"});}
 [HttpPost,ValidateAntiForgeryToken] public async Task<IActionResult> Create(ThietBi x,IFormFile? anh){if(await _db.ThietBi.AnyAsync(t=>t.MaThietBi==x.MaThietBi)){ModelState.AddModelError("MaThietBi","Mã thiết bị đã tồn tại.");}if(await _db.ThietBi.AnyAsync(t=>t.SoSerial==x.SoSerial)){ModelState.AddModelError("SoSerial","Serial đã tồn tại.");}if(!ModelState.IsValid){ViewBag.DongMay=await _db.DongMay.OrderBy(d=>d.TenDongMay).ToListAsync();ViewBag.CuaHang=await _db.CuaHang.ToListAsync();return View(x);} _db.ThietBi.Add(x);await _db.SaveChangesAsync();if(anh!=null){var error=await SaveModelImage(x.MaDongMay,anh);if(error!=null)TempData["Error"]=error;}TempData["Ok"]="Đã thêm thiết bị mới.";return RedirectToAction("Index");}
 [HttpGet]
public async Task<IActionResult> Edit(string id)
{
    var x = await _db.ThietBi
        .Include(t => t.DongMay)
            .ThenInclude(d => d!.ThuongHieu)
        .Include(t => t.CuaHang)
        .FirstOrDefaultAsync(t => t.MaThietBi == id);

    if (x == null)
        return NotFound();

    // Danh sách chi nhánh
    ViewBag.CuaHang = await _db.CuaHang
        .OrderBy(c => c.TenCuaHang)
        .ToListAsync();

    // Danh sách ảnh theo dòng máy
    ViewBag.Anh = await _db.AnhThietBi
        .Where(a => a.MaDongMay == x.MaDongMay)
        .OrderByDescending(a => a.LaAnhDaiDien)
        .ThenBy(a => a.ThuTuHienThi)
        .Select(a => a.DuongDanAnh)
        .ToListAsync();

    return View(x);
}
 [HttpPost,ValidateAntiForgeryToken]
 public async Task<IActionResult> Edit(string id,string tinhTrang,string trangThai,decimal giaThueNgay,decimal tienCoc,decimal phanTramGiamGia,string? soSerial,string? maCuaHang,IFormFile? anh)
 {
  var x=await _db.ThietBi.Include(t=>t.DongMay).FirstOrDefaultAsync(t=>t.MaThietBi==id);
  if(x==null)return NotFound();
if (giaThueNgay < 0 ||
    tienCoc < 0 ||
    phanTramGiamGia < 0 ||
    phanTramGiamGia > 100)
{
    TempData["Error"] =
        "Giá thuê, tiền cọc hoặc giảm giá không hợp lệ.";

    return RedirectToAction("Edit", new { id });
}
  if(string.IsNullOrWhiteSpace(soSerial)||string.IsNullOrWhiteSpace(maCuaHang)||!await _db.CuaHang.AnyAsync(c=>c.MaCuaHang==maCuaHang)) {TempData["Error"]="Serial hoặc chi nhánh không hợp lệ.";return RedirectToAction("Edit",new{id});}
  if(await _db.ThietBi.AnyAsync(t=>t.MaThietBi!=id&&t.SoSerial==soSerial)){TempData["Error"]="Serial đã tồn tại.";return RedirectToAction("Edit",new{id});}
  x.SoSerial=soSerial.Trim();x.MaCuaHang=maCuaHang;x.TinhTrang=tinhTrang;
  x.TrangThai=trangThai;
  if(x.DongMay!=null)
  {
   x.DongMay.GiaThueNgay=giaThueNgay;
   x.DongMay.TienCoc=tienCoc;
   x.DongMay.PhanTramGiamGia=phanTramGiamGia;
  }
  await _db.SaveChangesAsync();
  if(anh!=null){var error=await SaveModelImage(x.MaDongMay,anh);if(error!=null){TempData["Error"]=error;return RedirectToAction("Edit",new{id});}}
  TempData["Ok"]="Đã cập nhật thiết bị và giá thuê.";
  return RedirectToAction("Details",new{id});
 }
 [HttpPost,ValidateAntiForgeryToken] public async Task<IActionResult> Delete(string id){var x=await _db.ThietBi.FindAsync(id);if(x==null)return NotFound();var used=await _db.ChiTietHopDong.AnyAsync(c=>c.MaThietBi==id);if(used){TempData["Error"]="Không thể xóa thiết bị đã phát sinh hợp đồng. Hãy chuyển trạng thái sang ngừng sử dụng/hỏng.";return RedirectToAction("Details",new{id});}_db.ThietBi.Remove(x);await _db.SaveChangesAsync();TempData["Ok"]="Đã xóa thiết bị.";return RedirectToAction("Index");}
 private async Task<string?> SaveModelImage(string modelId,IFormFile image){
  var types=new[]{"image/jpeg","image/png","image/webp"};
  if(!types.Contains(image.ContentType)||image.Length==0||image.Length>5*1024*1024)return "Ảnh phải là JPG/PNG/WebP và tối đa 5 MB.";
  var ext=image.ContentType=="image/png"?".png":image.ContentType=="image/webp"?".webp":".jpg";
  var folder=Path.Combine(Directory.GetCurrentDirectory(),"wwwroot","uploads","devices");Directory.CreateDirectory(folder);
  var name=Guid.NewGuid().ToString("N")+ext;var full=Path.Combine(folder,name);
  await using(var fs=System.IO.File.Create(full))await image.CopyToAsync(fs);
  var has=await _db.AnhThietBi.AnyAsync(a=>a.MaDongMay==modelId&&a.LaAnhDaiDien);
  _db.AnhThietBi.Add(new AnhThietBi{MaAnh="A"+Guid.NewGuid().ToString("N")[..19],MaDongMay=modelId,DuongDanAnh="/uploads/devices/"+name,LaAnhDaiDien=!has,ThuTuHienThi=await _db.AnhThietBi.CountAsync(a=>a.MaDongMay==modelId)+1});
  await _db.SaveChangesAsync();return null;
 }
 [HttpPost]
[ValidateAntiForgeryToken]
public async Task<IActionResult> DeleteImage(
    string id,
    string imageUrl)
{
    var device = await _db.ThietBi
        .AsNoTracking()
        .FirstOrDefaultAsync(x => x.MaThietBi == id);

    if (device == null)
        return NotFound();

    var image = await _db.AnhThietBi
        .FirstOrDefaultAsync(x =>
            x.MaDongMay == device.MaDongMay &&
            x.DuongDanAnh == imageUrl);

    if (image == null)
    {
        TempData["Error"] = "Không tìm thấy ảnh cần xóa.";

        return RedirectToAction("Edit", new { id });
    }

    var oldPath = image.DuongDanAnh;
    var wasCover = image.LaAnhDaiDien;

    // Xóa bản ghi ảnh
    _db.AnhThietBi.Remove(image);

    // Nếu xóa ảnh đại diện, chọn ảnh còn lại làm đại diện
    if (wasCover)
    {
        var nextImage = await _db.AnhThietBi
            .Where(x =>
                x.MaDongMay == device.MaDongMay &&
                x.MaAnh != image.MaAnh)
            .OrderBy(x => x.ThuTuHienThi)
            .FirstOrDefaultAsync();

        if (nextImage != null)
        {
            nextImage.LaAnhDaiDien = true;
        }
    }

    await _db.SaveChangesAsync();

    // Chỉ xóa file nằm trong thư mục upload được quản lý
    const string uploadPrefix = "/uploads/devices/";

    if (!string.IsNullOrWhiteSpace(oldPath) &&
        oldPath.StartsWith(
            uploadPrefix,
            StringComparison.OrdinalIgnoreCase))
    {
        var fileName = Path.GetFileName(oldPath);

        var physicalPath = Path.Combine(
            Directory.GetCurrentDirectory(),
            "wwwroot",
            "uploads",
            "devices",
            fileName
        );

        // Không xóa file nếu bản ghi khác vẫn sử dụng
        var stillUsed = await _db.AnhThietBi
            .AnyAsync(x => x.DuongDanAnh == oldPath);

        if (!stillUsed && System.IO.File.Exists(physicalPath))
        {
            try
            {
                System.IO.File.Delete(physicalPath);
            }
            catch (IOException)
            {
                // Bản ghi đã xóa, file có thể dọn dẹp sau.
            }
            catch (UnauthorizedAccessException)
            {
                // Không có quyền xóa file vật lý.
            }
        }
    }

    TempData["Ok"] = "Đã xóa ảnh thiết bị thành công.";

    return RedirectToAction("Edit", new { id });
}
protected override string[] GetAllowedRoles()
{
    return new[] { "ADMIN", "NHAN_VIEN" };
}
}
