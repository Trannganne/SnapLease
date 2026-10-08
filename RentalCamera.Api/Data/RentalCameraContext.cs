using Microsoft.EntityFrameworkCore;

namespace RentalCamera.Api.Data;

public sealed class RentalCameraContext(DbContextOptions<RentalCameraContext> options) : DbContext(options)
{
    public DbSet<DanhMuc> DanhMuc => Set<DanhMuc>();
    public DbSet<ThuongHieu> ThuongHieu => Set<ThuongHieu>();
    public DbSet<DongMay> DongMay => Set<DongMay>();
    public DbSet<AnhThietBi> AnhThietBi => Set<AnhThietBi>();
    public DbSet<CuaHang> CuaHang => Set<CuaHang>();
    public DbSet<ThietBi> ThietBi => Set<ThietBi>();
    public DbSet<TaiKhoan> TaiKhoan => Set<TaiKhoan>();
    public DbSet<KhachThue> KhachThue => Set<KhachThue>();
    public DbSet<NhanVien> NhanVien => Set<NhanVien>();
    public DbSet<GioHang> GioHang => Set<GioHang>();
    public DbSet<ChiTietGioHang> ChiTietGioHang => Set<ChiTietGioHang>();
    public DbSet<GiuCho> GiuCho => Set<GiuCho>();
    public DbSet<ChiTietGiuCho> ChiTietGiuCho => Set<ChiTietGiuCho>();
    public DbSet<HopDong> HopDong => Set<HopDong>();
    public DbSet<ChiTietHopDong> ChiTietHopDong => Set<ChiTietHopDong>();
    public DbSet<PhuLuc> PhuLuc => Set<PhuLuc>();
    public DbSet<GiayToTuyThan> GiayToTuyThan => Set<GiayToTuyThan>();
    public DbSet<ThanhToan> ThanhToan => Set<ThanhToan>();
    public DbSet<PhieuPhat> PhieuPhat => Set<PhieuPhat>();
    public DbSet<AnhBienBan> AnhBienBan => Set<AnhBienBan>();
    public DbSet<DanhGia> DanhGia => Set<DanhGia>();
    public DbSet<ThongBao> ThongBao => Set<ThongBao>();
    public DbSet<IdempotencyKeyRecord> IdempotencyKey => Set<IdempotencyKeyRecord>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<DanhMuc>(entity =>
        {
            entity.ToTable("DanhMuc");
            entity.HasKey(x => x.MaDanhMuc);
            entity.Property(x => x.MaDanhMuc).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.TenDanhMuc).HasMaxLength(150);
            entity.Property(x => x.TrangThai).HasMaxLength(20).IsUnicode(false);
        });

        modelBuilder.Entity<ThuongHieu>(entity =>
        {
            entity.ToTable("ThuongHieu");
            entity.HasKey(x => x.MaThuongHieu);
            entity.Property(x => x.MaThuongHieu).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.TenThuongHieu).HasMaxLength(150);
        });

        modelBuilder.Entity<DongMay>(entity =>
        {
            entity.ToTable("DongMay");
            entity.HasKey(x => x.MaDongMay);
            entity.Property(x => x.MaDongMay).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaDanhMuc).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaThuongHieu).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.TenDongMay).HasMaxLength(200);
            entity.Property(x => x.GiaThueNgay).HasPrecision(18, 2);
            entity.Property(x => x.TienCoc).HasPrecision(18, 2);
            entity.Property(x => x.PhanTramGiamGia).HasPrecision(5, 2);
            entity.HasOne(x => x.DanhMuc).WithMany().HasForeignKey(x => x.MaDanhMuc);
            entity.HasOne(x => x.ThuongHieu).WithMany().HasForeignKey(x => x.MaThuongHieu);
        });

        modelBuilder.Entity<AnhThietBi>(entity =>
        {
            entity.ToTable("AnhThietBi");
            entity.HasKey(x => x.MaAnh);
            entity.Property(x => x.MaAnh).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaDongMay).HasMaxLength(20).IsUnicode(false);
            entity.HasOne(x => x.DongMay).WithMany(x => x.AnhThietBi).HasForeignKey(x => x.MaDongMay);
        });

        modelBuilder.Entity<CuaHang>(entity =>
        {
            entity.ToTable("CuaHang");
            entity.HasKey(x => x.MaCuaHang);
            entity.Property(x => x.MaCuaHang).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.TrangThai).HasMaxLength(20).IsUnicode(false);
        });

        modelBuilder.Entity<ThietBi>(entity =>
        {
            entity.ToTable("ThietBi");
            entity.HasKey(x => x.MaThietBi);
            entity.Property(x => x.MaThietBi).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaDongMay).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaCuaHang).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.TrangThai).HasMaxLength(20).IsUnicode(false);
            entity.HasOne(x => x.DongMay).WithMany().HasForeignKey(x => x.MaDongMay);
            entity.HasOne(x => x.CuaHang).WithMany().HasForeignKey(x => x.MaCuaHang);
            entity.Property(x => x.RowVersion).IsRowVersion();
        });

        modelBuilder.Entity<TaiKhoan>(entity =>
        {
            entity.ToTable("TaiKhoan");
            entity.HasKey(x => x.MaTaiKhoan);
            entity.Property(x => x.MaTaiKhoan).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.TenDangNhap).HasMaxLength(100).IsUnicode(false);
            entity.Property(x => x.MatKhauHash).HasMaxLength(500).IsUnicode(false);
            entity.Property(x => x.VaiTro).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.TrangThai).HasMaxLength(20).IsUnicode(false);
        });

        modelBuilder.Entity<KhachThue>(entity =>
        {
            entity.ToTable("KhachThue");
            entity.HasKey(x => x.MaKhachThue);
            entity.Property(x => x.MaKhachThue).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaTaiKhoan).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.CCCD).HasMaxLength(20).IsUnicode(false).IsRequired(false);
            entity.Property(x => x.GioiTinh).HasMaxLength(10);
            entity.Property(x => x.QuocTich).HasMaxLength(100);
            entity.Property(x => x.NoiCap).HasMaxLength(200);
            entity.HasIndex(x => x.CCCD).IsUnique().HasFilter("[CCCD] IS NOT NULL");
            entity.HasOne<TaiKhoan>().WithOne()
                .HasForeignKey<KhachThue>(x => x.MaTaiKhoan)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<GiayToTuyThan>(entity =>
        {
            entity.ToTable("GiayToTuyThan");
            entity.HasKey(x => x.MaGiayTo);
            entity.Property(x => x.MaGiayTo).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaKhachThue).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.LoaiGiayTo).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.SoGiayTo).HasMaxLength(30).IsUnicode(false);
            entity.Property(x => x.TrangThaiXacMinh).HasMaxLength(20).IsUnicode(false);
            entity.HasOne<KhachThue>().WithMany()
                .HasForeignKey(x => x.MaKhachThue).OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<NhanVien>(entity =>
        {
            entity.ToTable("NhanVien");
            entity.HasKey(x => x.MaNhanVien);
            entity.Property(x => x.MaNhanVien).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaTaiKhoan).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaCuaHang).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.TrangThai).HasMaxLength(20).IsUnicode(false);
            entity.HasOne<TaiKhoan>().WithOne()
                .HasForeignKey<NhanVien>(x => x.MaTaiKhoan)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<CuaHang>().WithMany()
                .HasForeignKey(x => x.MaCuaHang).OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<GioHang>(entity =>
        {
            entity.ToTable("GioHang");
            entity.HasKey(x => x.MaGioHang);
            entity.HasAlternateKey(x => new { x.MaGioHang, x.MaKhachThue }); // for FK binding
            entity.Property(x => x.MaGioHang).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaKhachThue).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.TrangThai).HasMaxLength(25).IsUnicode(false);
            entity.HasOne<KhachThue>().WithMany()
                .HasForeignKey(x => x.MaKhachThue).OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<ChiTietGioHang>(entity =>
        {
            entity.ToTable("ChiTietGioHang");
            entity.HasKey(x => x.MaChiTietGioHang);
            entity.Property(x => x.MaChiTietGioHang).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaGioHang).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaCuaHang).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.NguonTao).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaDongMay).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.DonGia).HasPrecision(18, 2);
            entity.Property(x => x.TienCoc).HasPrecision(18, 2);
            entity.Property(x => x.ThanhTien).HasPrecision(18, 2);
            entity.HasOne(x => x.GioHang).WithMany(x => x.ChiTiet).HasForeignKey(x => x.MaGioHang);
            entity.HasOne<DongMay>().WithMany()
                .HasForeignKey(x => x.MaDongMay).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<CuaHang>().WithMany()
                .HasForeignKey(x => x.MaCuaHang).OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<GiuCho>(entity =>
        {
            entity.ToTable("GiuCho");
            entity.HasKey(x => x.MaGiuCho);
            entity.Property(x => x.MaGiuCho).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaGioHang).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaKhachThue).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaCuaHang).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.TrangThai).HasMaxLength(30).IsUnicode(false);
            entity.HasOne<GioHang>().WithMany()
                .HasForeignKey(x => new { x.MaGioHang, x.MaKhachThue })
                .HasPrincipalKey(x => new { x.MaGioHang, x.MaKhachThue })
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<CuaHang>().WithMany()
                .HasForeignKey(x => x.MaCuaHang).OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<ChiTietGiuCho>(entity =>
        {
            entity.ToTable("ChiTietGiuCho");
            entity.HasKey(x => x.MaChiTietGiuCho);
            entity.Property(x => x.MaChiTietGiuCho).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaGiuCho).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaDongMay).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaChiTietGioHang).HasMaxLength(20).IsUnicode(false);
            entity.HasOne(x => x.GiuCho).WithMany(x => x.ChiTiet)
                .HasForeignKey(x => x.MaGiuCho).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<DongMay>().WithMany()
                .HasForeignKey(x => x.MaDongMay).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<ChiTietGioHang>().WithMany()
                .HasForeignKey(x => x.MaChiTietGioHang).OnDelete(DeleteBehavior.SetNull);
        });

        modelBuilder.Entity<HopDong>(entity =>
        {
            entity.ToTable("HopDong");
            entity.HasKey(x => x.MaHopDong);
            entity.Property(x => x.MaHopDong).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaGioHang).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaGiuCho).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaKhachThue).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaNhanVien).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaCuaHang).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.HinhThucKy).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.TrangThai).HasMaxLength(30).IsUnicode(false);
            entity.Property(x => x.TongTien).HasPrecision(18, 2);
            entity.Property(x => x.TongTienCoc).HasPrecision(18, 2);
            entity.HasOne<GioHang>().WithMany()
                .HasForeignKey(x => new { x.MaGioHang, x.MaKhachThue })
                .HasPrincipalKey(x => new { x.MaGioHang, x.MaKhachThue })
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<GiuCho>().WithOne()
                .HasForeignKey<HopDong>(x => x.MaGiuCho).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<NhanVien>().WithMany()
                .HasForeignKey(x => x.MaNhanVien).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<CuaHang>().WithMany()
                .HasForeignKey(x => x.MaCuaHang).OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<ChiTietHopDong>(entity =>
        {
            entity.ToTable("ChiTietHopDong");
            entity.HasKey(x => x.MaChiTietHopDong);
            entity.Property(x => x.MaChiTietHopDong).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaHopDong).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaThietBi).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.DonGia).HasPrecision(18, 2);
            entity.HasOne<HopDong>().WithMany()
                .HasForeignKey(x => x.MaHopDong).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<ThietBi>().WithMany()
                .HasForeignKey(x => x.MaThietBi).OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<PhuLuc>(entity =>
        {
            entity.ToTable("PhuLuc");
            entity.HasKey(x => x.MaPhuLuc);
            entity.Property(x => x.MaPhuLuc).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaHopDong).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.TrangThai).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.ChiPhiPhatSinh).HasPrecision(18, 2);
            entity.Property(x => x.TienCocBoSung).HasPrecision(18, 2);
            entity.HasOne<HopDong>().WithMany()
                .HasForeignKey(x => x.MaHopDong).OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<ThanhToan>(entity =>
        {
            entity.ToTable("ThanhToan");
            entity.HasKey(x => x.MaThanhToan);
            entity.Property(x => x.MaThanhToan).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaHopDong).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.SoTien).HasPrecision(18, 2);
            entity.Property(x => x.LoaiThanhToan).HasMaxLength(30).IsUnicode(false);
            entity.Property(x => x.PhuongThuc).HasMaxLength(30).IsUnicode(false);
            entity.Property(x => x.MaGiaoDich).HasMaxLength(100).IsUnicode(false);
            entity.Property(x => x.TrangThai).HasMaxLength(20).IsUnicode(false);
            entity.HasOne<HopDong>().WithMany()
                .HasForeignKey(x => x.MaHopDong).OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<PhieuPhat>(entity =>
        {
            entity.ToTable("PhieuPhat");
            entity.HasKey(x => x.MaPhieuPhat);
            entity.Property(x => x.MaPhieuPhat).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaChiTietHopDong).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.LoaiViPham).HasMaxLength(30).IsUnicode(false);
            entity.Property(x => x.SoTien).HasPrecision(18, 2);
            entity.Property(x => x.TrangThai).HasMaxLength(20).IsUnicode(false);
            entity.HasOne<ChiTietHopDong>().WithMany()
                .HasForeignKey(x => x.MaChiTietHopDong).OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<AnhBienBan>(entity =>
        {
            entity.ToTable("AnhBienBan");
            entity.HasKey(x => x.MaAnhBienBan);
            entity.Property(x => x.MaAnhBienBan).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaChiTietHopDong).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.Loai).HasMaxLength(20).IsUnicode(false);
            entity.HasOne<ChiTietHopDong>().WithMany()
                .HasForeignKey(x => x.MaChiTietHopDong).OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<DanhGia>(entity =>
        {
            entity.ToTable("DanhGia");
            entity.HasKey(x => x.MaDanhGia);
            entity.Property(x => x.MaDanhGia).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaChiTietHopDong).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaKhachThue).HasMaxLength(20).IsUnicode(false);
            entity.HasOne<ChiTietHopDong>().WithOne()
                .HasForeignKey<DanhGia>(x => x.MaChiTietHopDong).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<KhachThue>().WithMany()
                .HasForeignKey(x => x.MaKhachThue).OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<ThongBao>(entity =>
        {
            entity.ToTable("ThongBao");
            entity.HasKey(x => x.MaThongBao);
            entity.Property(x => x.MaThongBao).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaTaiKhoan).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.Loai).HasMaxLength(30).IsUnicode(false);
            entity.HasOne<TaiKhoan>().WithMany()
                .HasForeignKey(x => x.MaTaiKhoan).OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<IdempotencyKeyRecord>(entity =>
        {
            entity.ToTable("IdempotencyKey");
            entity.HasKey(x => new { x.IdempotencyKey, x.MaKhachThue, x.LoaiThaoTac });
            entity.Property(x => x.IdempotencyKey).HasMaxLength(100).IsUnicode(false);
            entity.Property(x => x.MaKhachThue).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.LoaiThaoTac).HasMaxLength(50).IsUnicode(false);
            entity.Property(x => x.PayloadHash).HasMaxLength(64).IsUnicode(false);
            entity.Property(x => x.MaThucThe).HasMaxLength(50).IsUnicode(false);
            entity.HasOne<KhachThue>().WithMany()
                .HasForeignKey(x => x.MaKhachThue).OnDelete(DeleteBehavior.Restrict);
        });
    }
}

public sealed class DanhMuc
{
    public string MaDanhMuc { get; set; } = "";
    public string TenDanhMuc { get; set; } = "";
    public string? MoTa { get; set; }
    public string TrangThai { get; set; } = "";
}

public sealed class ThuongHieu
{
    public string MaThuongHieu { get; set; } = "";
    public string TenThuongHieu { get; set; } = "";
    public string? QuocGia { get; set; }
}

public sealed class DongMay
{
    public string MaDongMay { get; set; } = "";
    public string MaDanhMuc { get; set; } = "";
    public string MaThuongHieu { get; set; } = "";
    public string TenDongMay { get; set; } = "";
    public string? MoTa { get; set; }
    public decimal GiaThueNgay { get; set; }
    public decimal TienCoc { get; set; }
    public decimal PhanTramGiamGia { get; set; }
    public DanhMuc DanhMuc { get; set; } = null!;
    public ThuongHieu ThuongHieu { get; set; } = null!;
    public ICollection<AnhThietBi> AnhThietBi { get; set; } = new List<AnhThietBi>();
}

public sealed class AnhThietBi
{
    public string MaAnh { get; set; } = "";
    public string MaDongMay { get; set; } = "";
    public string DuongDanAnh { get; set; } = "";
    public bool LaAnhDaiDien { get; set; }
    public int ThuTuHienThi { get; set; }
    public DongMay DongMay { get; set; } = null!;
}

public sealed class CuaHang
{
    public string MaCuaHang { get; set; } = "";
    public string TenCuaHang { get; set; } = "";
    public string DiaChi { get; set; } = "";
    public string SoDienThoai { get; set; } = "";
    public string? Email { get; set; }
    public string? MoTa { get; set; }
    public string TrangThai { get; set; } = "";
}

public sealed class ThietBi
{
    public string MaThietBi { get; set; } = "";
    public string MaDongMay { get; set; } = "";
    public string MaCuaHang { get; set; } = "";
    public string SoSerial { get; set; } = "";
    public string TinhTrang { get; set; } = "";
    public string TrangThai { get; set; } = "";
    public DateOnly? NgayNhap { get; set; }
    public byte[] RowVersion { get; set; } = [];
    public DongMay DongMay { get; set; } = null!;
    public CuaHang CuaHang { get; set; } = null!;
}
