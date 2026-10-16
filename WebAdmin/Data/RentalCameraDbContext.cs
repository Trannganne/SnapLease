using Microsoft.EntityFrameworkCore;
using RentalCamera.Models;
namespace RentalCamera.Data;
public class RentalCameraDbContext : DbContext {
 public RentalCameraDbContext(DbContextOptions<RentalCameraDbContext> o):base(o){}
 public DbSet<DanhMuc> DanhMuc => Set<DanhMuc>(); public DbSet<ThuongHieu> ThuongHieu => Set<ThuongHieu>(); public DbSet<DongMay> DongMay => Set<DongMay>(); public DbSet<AnhThietBi> AnhThietBi => Set<AnhThietBi>(); public DbSet<CuaHang> CuaHang => Set<CuaHang>(); public DbSet<TaiKhoan> TaiKhoan => Set<TaiKhoan>(); public DbSet<KhachThue> KhachThue => Set<KhachThue>(); public DbSet<NhanVien> NhanVien => Set<NhanVien>(); public DbSet<ThietBi> ThietBi => Set<ThietBi>(); public DbSet<GioHang> GioHang => Set<GioHang>(); public DbSet<ChiTietGioHang> ChiTietGioHang => Set<ChiTietGioHang>(); public DbSet<HopDong> HopDong => Set<HopDong>(); public DbSet<ChiTietHopDong> ChiTietHopDong => Set<ChiTietHopDong>(); public DbSet<ThanhToan> ThanhToan => Set<ThanhToan>(); public DbSet<PhuLuc> PhuLuc => Set<PhuLuc>(); public DbSet<PhieuPhat> PhieuPhat => Set<PhieuPhat>(); public DbSet<DanhGia> DanhGia => Set<DanhGia>(); public DbSet<ThongBao> ThongBao => Set<ThongBao>();
 protected override void OnModelCreating(ModelBuilder b){
  b.Entity<DongMay>().HasOne(x=>x.DanhMuc).WithMany().HasForeignKey(x=>x.MaDanhMuc); b.Entity<DongMay>().HasOne(x=>x.ThuongHieu).WithMany().HasForeignKey(x=>x.MaThuongHieu);
  b.Entity<ThietBi>().HasOne(x=>x.DongMay).WithMany().HasForeignKey(x=>x.MaDongMay); b.Entity<ThietBi>().HasOne(x=>x.CuaHang).WithMany().HasForeignKey(x=>x.MaCuaHang);
  b.Entity<GioHang>().HasOne(x=>x.KhachThue).WithMany().HasForeignKey(x=>x.MaKhachThue); b.Entity<ChiTietGioHang>().HasOne(x=>x.GioHang).WithMany().HasForeignKey(x=>x.MaGioHang); b.Entity<ChiTietGioHang>().HasOne(x=>x.DongMay).WithMany().HasForeignKey(x=>x.MaDongMay); b.Entity<HopDong>().HasOne(x=>x.KhachThue).WithMany().HasForeignKey(x=>x.MaKhachThue);
 }
}
