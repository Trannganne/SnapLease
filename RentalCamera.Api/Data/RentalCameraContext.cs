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
    public DbSet<LuaChonGioHangGiuCho> LuaChonGioHangGiuCho => Set<LuaChonGioHangGiuCho>();
    public DbSet<HopDong> HopDong => Set<HopDong>();
    public DbSet<XacNhanKyHopDong> XacNhanKyHopDong => Set<XacNhanKyHopDong>();
    public DbSet<ChiTietHopDong> ChiTietHopDong => Set<ChiTietHopDong>();
    public DbSet<PhuLuc> PhuLuc => Set<PhuLuc>();
    public DbSet<GiayToTuyThan> GiayToTuyThan => Set<GiayToTuyThan>();
    public DbSet<ThanhToan> ThanhToan => Set<ThanhToan>();
    public DbSet<YeuCauThanhToanVnpay> YeuCauThanhToanVnpay => Set<YeuCauThanhToanVnpay>();
    public DbSet<PhieuPhat> PhieuPhat => Set<PhieuPhat>();
    public DbSet<AnhBienBan> AnhBienBan => Set<AnhBienBan>();
    public DbSet<DanhGia> DanhGia => Set<DanhGia>();
    public DbSet<LichSuHienThiDanhGia> LichSuHienThiDanhGia => Set<LichSuHienThiDanhGia>();
    public DbSet<DanhGiaDiemNoiBat> DanhGiaDiemNoiBat => Set<DanhGiaDiemNoiBat>();
    public DbSet<AnhDanhGia> AnhDanhGia => Set<AnhDanhGia>();
    public DbSet<ThongBao> ThongBao => Set<ThongBao>();
    public DbSet<NotificationDelivery> NotificationDelivery => Set<NotificationDelivery>();
    public DbSet<YeuCauHuyHopDong> YeuCauHuyHopDong => Set<YeuCauHuyHopDong>();
    public DbSet<HoanTienAudit> HoanTienAudit => Set<HoanTienAudit>();
    public DbSet<LichLamViec> LichLamViec => Set<LichLamViec>();
    public DbSet<LichLamViecDacBiet> LichLamViecDacBiet => Set<LichLamViecDacBiet>();
    public DbSet<NhatKyNghiepVu> NhatKyNghiepVu => Set<NhatKyNghiepVu>();
    public DbSet<FcmDeviceToken> FcmDeviceToken => Set<FcmDeviceToken>();
    public DbSet<IdempotencyKeyRecord> IdempotencyKey => Set<IdempotencyKeyRecord>();

    public override async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        await RentalCamera.Api.Notifications.NotificationEvents.CollectAsync(this, cancellationToken);
        return await base.SaveChangesAsync(cancellationToken);
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<LuaChonGioHangGiuCho>(e=>{
            e.ToTable("LuaChonGioHangGiuCho");e.HasKey(x=>new{x.MaGiuCho,x.MaChiTietGioHang});
            e.Property(x=>x.MaGiuCho).HasMaxLength(20).IsUnicode(false);
            e.Property(x=>x.MaChiTietGioHang).HasMaxLength(20).IsUnicode(false);
            e.Property(x=>x.MaDongMay).HasMaxLength(20).IsUnicode(false);
            e.HasOne<GiuCho>().WithMany().HasForeignKey(x=>x.MaGiuCho).OnDelete(DeleteBehavior.Restrict);
            e.HasOne<ChiTietGioHang>().WithMany().HasForeignKey(x=>x.MaChiTietGioHang).OnDelete(DeleteBehavior.Restrict);
            e.HasOne<DongMay>().WithMany().HasForeignKey(x=>x.MaDongMay).OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<LichLamViec>(e=>{e.ToTable("LichLamViec");e.HasKey(x=>new{x.MaCuaHang,x.NgayTrongTuan});e.Property(x=>x.MaCuaHang).HasMaxLength(20).IsUnicode(false);});
        modelBuilder.Entity<LichLamViecDacBiet>(e=>{e.ToTable("LichLamViecDacBiet");e.HasKey(x=>new{x.MaCuaHang,x.Ngay});e.Property(x=>x.MaCuaHang).HasMaxLength(20).IsUnicode(false);e.Property(x=>x.LyDo).HasMaxLength(500);
            e.HasOne<CuaHang>().WithMany().HasForeignKey(x=>x.MaCuaHang).OnDelete(DeleteBehavior.Restrict);});
        modelBuilder.Entity<NhatKyNghiepVu>(e=>{e.ToTable("NhatKyNghiepVu");e.HasKey(x=>x.Id);
            e.Property(x=>x.Id).HasMaxLength(20).IsUnicode(false);e.Property(x=>x.HanhDong).HasMaxLength(50).IsUnicode(false);
            e.Property(x=>x.DoiTuongId).HasMaxLength(50).IsUnicode(false);e.Property(x=>x.MaTaiKhoan).HasMaxLength(20).IsUnicode(false);e.Property(x=>x.LyDo).HasMaxLength(500);
            e.HasOne<TaiKhoan>().WithMany().HasForeignKey(x=>x.MaTaiKhoan).OnDelete(DeleteBehavior.Restrict);});
        modelBuilder.Entity<YeuCauHuyHopDong>(e=>{
            e.ToTable("YeuCauHuyHopDong");e.HasKey(x=>x.Id);
            e.Property(x=>x.Id).HasMaxLength(20).IsUnicode(false);
            e.Property(x=>x.MaHopDong).HasMaxLength(20).IsUnicode(false);
            e.Property(x=>x.TrangThai).HasMaxLength(20).IsUnicode(false);
            e.Property(x=>x.LoaiYeuCau).HasMaxLength(20).IsUnicode(false);
            e.Property(x=>x.LyDo).HasMaxLength(500);e.Property(x=>x.LyDoXuLy).HasMaxLength(500);
            e.Property(x=>x.NguoiXuLy).HasMaxLength(20).IsUnicode(false);
            e.Property(x=>x.TyLeKhauTru).HasPrecision(5,2);
            foreach(var name in new[]{"TienCocDaThu","TienThueDaThu","TienThuThuaDaThu","TienKhauTru","TienCocPhaiHoan","TienThuePhaiHoan","TienThuThuaPhaiHoan"})e.Property<decimal>(name).HasPrecision(18,2);
            e.HasIndex(x=>x.MaHopDong).IsUnique().HasFilter("[TrangThai]='CHO_XAC_NHAN'");
            e.HasOne<HopDong>().WithMany().HasForeignKey(x=>x.MaHopDong).OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<HoanTienAudit>(e=>{
            e.ToTable("HoanTienAudit");e.HasKey(x=>x.Id);
            e.Property(x=>x.Id).HasMaxLength(20).IsUnicode(false);e.Property(x=>x.MaThanhToan).HasMaxLength(20).IsUnicode(false);
            e.Property(x=>x.MaTaiKhoan).HasMaxLength(20).IsUnicode(false);e.Property(x=>x.ChungTu).HasMaxLength(500);
            e.HasOne<ThanhToan>().WithMany().HasForeignKey(x=>x.MaThanhToan).OnDelete(DeleteBehavior.Restrict);
            e.HasOne<TaiKhoan>().WithMany().HasForeignKey(x=>x.MaTaiKhoan).OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<ThanhToan>().Property(x=>x.MaYeuCauHuy).HasMaxLength(20).IsUnicode(false);
        modelBuilder.Entity<ThanhToan>().HasOne<YeuCauHuyHopDong>().WithMany().HasForeignKey(x=>x.MaYeuCauHuy).OnDelete(DeleteBehavior.Restrict);
        modelBuilder.Entity<PhuLuc>(e=>{
            e.Property(x=>x.LyDoDong).HasMaxLength(500);
            e.Property(x=>x.NguoiXuLy).HasMaxLength(20).IsUnicode(false);
            e.Property(x=>x.MaBamNoiDung).HasMaxLength(64).IsUnicode(false);e.Property(x=>x.MaBamTepPdf).HasMaxLength(64).IsUnicode(false);
            e.Property(x=>x.PhienBanDieuKhoan).HasMaxLength(20).IsUnicode(false);
            e.Property(x=>x.MaOtpHash).HasMaxLength(64).IsUnicode(false);e.Property(x=>x.MuoiOtp).HasMaxLength(32).IsUnicode(false);
            e.Property(x=>x.MaXacNhanKy).HasMaxLength(20).IsUnicode(false);e.Property(x=>x.DiaChiIpKy).HasMaxLength(45).IsUnicode(false);
            e.HasIndex(x=>x.MaHopDong).IsUnique().HasFilter("[TrangThai] IN ('CHO_XAC_NHAN','CHO_KY')");
        });
        modelBuilder.Entity<NotificationDelivery>(e => {
            e.ToTable("NotificationDelivery"); e.HasKey(x => x.Id);
            e.Property(x => x.Id).HasMaxLength(36).IsUnicode(false);
            e.Property(x => x.MaThongBao).HasMaxLength(20).IsUnicode(false);
            e.Property(x => x.DeviceTokenId).HasMaxLength(36).IsUnicode(false);
            e.Property(x => x.State).HasMaxLength(20).IsUnicode(false);
            e.Property(x => x.LastErrorCode).HasMaxLength(100).IsUnicode(false);
            e.HasIndex(x => new { x.MaThongBao, x.DeviceTokenId }).IsUnique();
            e.HasOne<ThongBao>().WithMany().HasForeignKey(x => x.MaThongBao).OnDelete(DeleteBehavior.Restrict);
            e.HasOne<FcmDeviceToken>().WithMany().HasForeignKey(x => x.DeviceTokenId).OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<ThongBao>().Property(x => x.EventKey).HasMaxLength(200).IsUnicode(false);
        modelBuilder.Entity<ThongBao>().HasIndex(x => x.EventKey).IsUnique().HasFilter("[EventKey] IS NOT NULL");
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
            entity.HasIndex(x=>new{x.MaGiuCho,x.MaDongMay}).IsUnique().HasDatabaseName("UQ_ChiTietGiuCho");
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
            entity.Property(x => x.PhienBanDieuKhoan).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaBamNoiDung).HasMaxLength(64).IsUnicode(false);
            entity.Property(x => x.MaBamTepPdf).HasMaxLength(64).IsUnicode(false);
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

        modelBuilder.Entity<XacNhanKyHopDong>(entity =>
        {
            entity.ToTable("XacNhanKyHopDong");
            entity.HasKey(x => x.MaXacNhan);
            entity.Property(x => x.MaXacNhan).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaHopDong).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaOtpHash).HasMaxLength(64).IsUnicode(false);
            entity.Property(x => x.MuoiOtp).HasMaxLength(32).IsUnicode(false);
            entity.Property(x => x.TrangThai).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.DiaChiIp).HasMaxLength(45).IsUnicode(false);
            entity.Property(x => x.ThietBiKy).HasMaxLength(500);
            entity.Property(x => x.PhienBanDieuKhoan).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaBamNoiDung).HasMaxLength(64).IsUnicode(false);
            entity.Property(x => x.MaBamTepPdf).HasMaxLength(64).IsUnicode(false);
            entity.HasIndex(x => new { x.MaHopDong, x.TrangThai });
            entity.HasOne<HopDong>().WithMany()
                .HasForeignKey(x => x.MaHopDong).OnDelete(DeleteBehavior.Restrict);
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
            entity.Property(x => x.NhaCungCap).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaThamChieu).HasMaxLength(100).IsUnicode(false);
            entity.Property(x => x.MaNganHang).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.LoaiThe).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaPhanHoi).HasMaxLength(10).IsUnicode(false);
            entity.Property(x => x.DuongDanThanhToan).HasMaxLength(2000).IsUnicode(false);
            entity.HasIndex(x => x.MaThamChieu).IsUnique().HasFilter("[MaThamChieu] IS NOT NULL");
            entity.HasOne<HopDong>().WithMany()
                .HasForeignKey(x => x.MaHopDong).OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<YeuCauThanhToanVnpay>(entity =>
        {
            entity.ToTable("YeuCauThanhToanVnpay");
            entity.HasKey(x => x.MaYeuCau);
            entity.Property(x => x.MaYeuCau).HasMaxLength(50).IsUnicode(false);
            entity.Property(x => x.MaThanhToan).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaThamChieu).HasMaxLength(100).IsUnicode(false);
            entity.Property(x => x.SoTien).HasPrecision(18, 2);
            entity.Property(x => x.TienTe).HasMaxLength(10).IsUnicode(false);
            entity.Property(x => x.DuongDanThanhToan).HasMaxLength(2000).IsUnicode(false);
            entity.Property(x => x.TrangThai).HasMaxLength(30).IsUnicode(false);
            entity.Property(x => x.MaGiaoDich).HasMaxLength(100).IsUnicode(false);
            entity.Property(x => x.MaNganHang).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.LoaiThe).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaPhanHoi).HasMaxLength(10).IsUnicode(false);
            entity.Property(x => x.GhiChu).HasMaxLength(500);
            entity.HasIndex(x => x.MaThamChieu).IsUnique();
            entity.HasIndex(x => x.MaThanhToan);
            entity.HasOne<ThanhToan>().WithMany()
                .HasForeignKey(x => x.MaThanhToan).OnDelete(DeleteBehavior.Restrict);
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
            // Preserve historical comments; POST validation still caps new input at 500.
            entity.Property(x => x.NhanXet).HasMaxLength(1000);
            entity.Property(x => x.TrangThaiKiemDuyet).HasMaxLength(20).IsUnicode(false).IsRequired(false);
            entity.Property(x => x.GhiChuKiemDuyet).HasMaxLength(500);
            entity.HasOne<ChiTietHopDong>().WithOne()
                .HasForeignKey<DanhGia>(x => x.MaChiTietHopDong).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<KhachThue>().WithMany()
                .HasForeignKey(x => x.MaKhachThue).OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<LichSuHienThiDanhGia>(entity =>
        {
            entity.ToTable("LichSuHienThiDanhGia");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Id).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaDanhGia).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaTaiKhoan).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.TrangThaiTruoc).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.TrangThaiSau).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.LyDo).HasMaxLength(500).IsRequired();
            entity.HasOne<DanhGia>().WithMany().HasForeignKey(x => x.MaDanhGia).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<TaiKhoan>().WithMany().HasForeignKey(x => x.MaTaiKhoan).OnDelete(DeleteBehavior.Restrict);
            entity.HasIndex(x => new { x.MaDanhGia, x.ThoiGianUtc });
        });

        modelBuilder.Entity<DanhGiaDiemNoiBat>(entity =>
        {
            entity.ToTable("DanhGiaDiemNoiBat");
            entity.HasKey(x => new { x.MaDanhGia, x.MaDiemNoiBat });
            entity.Property(x => x.MaDanhGia).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaDiemNoiBat).HasMaxLength(50).IsUnicode(false);
            entity.HasOne<DanhGia>().WithMany()
                .HasForeignKey(x => x.MaDanhGia).OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<AnhDanhGia>(entity =>
        {
            entity.ToTable("AnhDanhGia");
            entity.HasKey(x => x.MaAnhDanhGia);
            entity.Property(x => x.MaAnhDanhGia).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaDanhGia).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.DuongDanAnh).HasMaxLength(500);
            entity.Property(x => x.PublicId).HasMaxLength(200);
            entity.HasIndex(x => new { x.MaDanhGia, x.ThuTu }).IsUnique();
            entity.HasOne<DanhGia>().WithMany()
                .HasForeignKey(x => x.MaDanhGia).OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<ThongBao>(entity =>
        {
            entity.ToTable("ThongBao");
            entity.HasKey(x => x.MaThongBao);
            entity.Property(x => x.MaThongBao).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.MaTaiKhoan).HasMaxLength(20).IsUnicode(false);
            entity.Property(x => x.Loai).HasMaxLength(30).IsUnicode(false);
            entity.Property(x => x.EventCode).HasMaxLength(50).IsUnicode(false);
            entity.Property(x => x.TargetType).HasMaxLength(30).IsUnicode(false);
            entity.Property(x => x.TargetId).HasMaxLength(50).IsUnicode(false);
            entity.HasOne<TaiKhoan>().WithMany()
                .HasForeignKey(x => x.MaTaiKhoan).OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<FcmDeviceToken>(entity =>
        {
            entity.ToTable("FcmDeviceToken");
            entity.HasKey(x => x.Id);

            entity.Property(x => x.Id)
                .HasMaxLength(36)
                .IsUnicode(false);

            entity.Property(x => x.MaTaiKhoan)
                .HasMaxLength(20)
                .IsUnicode(false);

            entity.Property(x => x.Token)
                .HasMaxLength(2048);

            entity.Property(x => x.TokenHash)
                .HasMaxLength(64)
                .IsUnicode(false);

            entity.Property(x => x.Platform)
                .HasMaxLength(20)
                .IsUnicode(false);

            entity.Property(x => x.DeviceId)
                .HasMaxLength(200);

            entity.HasIndex(x => x.TokenHash)
                .IsUnique();

            entity.HasIndex(x => new { x.MaTaiKhoan, x.IsActive });

            entity.HasOne<TaiKhoan>().WithMany()
                .HasForeignKey(x => x.MaTaiKhoan)
                .OnDelete(DeleteBehavior.Restrict);
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
