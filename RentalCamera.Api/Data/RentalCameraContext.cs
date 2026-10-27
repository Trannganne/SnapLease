using Microsoft.EntityFrameworkCore;
namespace RentalCamera.Api.Data;
public sealed class RentalCameraContext(DbContextOptions<RentalCameraContext> options) : DbContext(options)
{
    public DbSet<TaiKhoan> TaiKhoan => Set<TaiKhoan>();
    public DbSet<KhachThue> KhachThue => Set<KhachThue>();
    public DbSet<NhanVien> NhanVien => Set<NhanVien>();
    public DbSet<GiayToTuyThan> GiayToTuyThan => Set<GiayToTuyThan>();
    public DbSet<DanhMuc> DanhMuc => Set<DanhMuc>();
    public DbSet<ThuongHieu> ThuongHieu => Set<ThuongHieu>();
    public DbSet<DongMay> DongMay => Set<DongMay>();
    public DbSet<ThietBi> ThietBi => Set<ThietBi>();
    public DbSet<AnhThietBi> AnhThietBi => Set<AnhThietBi>();
    public DbSet<CuaHang> CuaHang => Set<CuaHang>();
    public DbSet<GioHang> GioHang => Set<GioHang>();
    public DbSet<ChiTietGioHang> ChiTietGioHang => Set<ChiTietGioHang>();
    public DbSet<GiuCho> GiuCho => Set<GiuCho>();
    public DbSet<ChiTietGiuCho> ChiTietGiuCho => Set<ChiTietGiuCho>();
    public DbSet<HopDong> HopDong => Set<HopDong>();
    public DbSet<ChiTietHopDong> ChiTietHopDong => Set<ChiTietHopDong>();
    public DbSet<PhuLuc> PhuLuc => Set<PhuLuc>();
    public DbSet<XacNhanKyHopDong> XacNhanKyHopDong => Set<XacNhanKyHopDong>();
    public DbSet<ThanhToan> ThanhToan => Set<ThanhToan>();
    public DbSet<YeuCauThanhToanVnpay> YeuCauThanhToanVnpay => Set<YeuCauThanhToanVnpay>();
    public DbSet<PhieuPhat> PhieuPhat => Set<PhieuPhat>();
    public DbSet<QuyetToanHopDong> QuyetToanHopDong => Set<QuyetToanHopDong>();
    public DbSet<PhanBoQuyetToan> PhanBoQuyetToan => Set<PhanBoQuyetToan>();
    public DbSet<DanhGia> DanhGia => Set<DanhGia>();
    public DbSet<AnhDanhGia> AnhDanhGia => Set<AnhDanhGia>();
    public DbSet<AnhBienBan> AnhBienBan => Set<AnhBienBan>();
    public DbSet<ThongBao> ThongBao => Set<ThongBao>();
    public DbSet<FcmDeviceToken> FcmDeviceToken => Set<FcmDeviceToken>();
    public DbSet<NotificationDelivery> NotificationDelivery => Set<NotificationDelivery>();
    public DbSet<IdempotencyKeyRecord> IdempotencyKey => Set<IdempotencyKeyRecord>();
    public DbSet<BienBanNhanTra> BienBanNhanTra => Set<BienBanNhanTra>();
    public DbSet<DoiSoatHuyHopDong> DoiSoatHuyHopDong => Set<DoiSoatHuyHopDong>();
    public DbSet<XacMinhKhachKhongDen> XacMinhKhachKhongDen => Set<XacMinhKhachKhongDen>();
    public override async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        Schema33WriteGuard.Validate(ChangeTracker);
        await RentalCamera.Api.Notifications.NotificationEvents.CollectAsync(this, cancellationToken);
        return await base.SaveChangesAsync(cancellationToken);
    }
    protected override void OnModelCreating(ModelBuilder modelBuilder) => Schema33Mapping.Configure(modelBuilder);
}
