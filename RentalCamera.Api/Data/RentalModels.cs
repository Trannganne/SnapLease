namespace RentalCamera.Api.Data;

public sealed class TaiKhoan
{
    public string MaTaiKhoan { get; set; } = "";
    public string TenDangNhap { get; set; } = "";
    public string MatKhauHash { get; set; } = "";
    public string VaiTro { get; set; } = "";
    public string TrangThai { get; set; } = "HOAT_DONG";
    public DateTime NgayTao { get; set; }
}

public sealed class KhachThue
{
    public string MaKhachThue { get; set; } = "";
    public string MaTaiKhoan { get; set; } = "";
    public string? HoTen { get; set; }
    public string SoDienThoai { get; set; } = "";
    public string? Email { get; set; }
    public string? CCCD { get; set; }
    public string? DiaChi { get; set; }
    public DateOnly? NgaySinh { get; set; }
    public string? GioiTinh { get; set; }
    public string? QuocTich { get; set; }
    public DateOnly? NgayCap { get; set; }
    public string? NoiCap { get; set; }
    public bool DaXacNhanThongTin { get; set; }
}

public sealed class GiayToTuyThan
{
    public string MaGiayTo { get; set; } = "";
    public string MaKhachThue { get; set; } = "";
    public string LoaiGiayTo { get; set; } = "";
    public string SoGiayTo { get; set; } = "";
    public string MatTruocUrl { get; set; } = "";
    public string? MatSauUrl { get; set; }
    public DateTime NgayTaiLen { get; set; }
    public string TrangThaiXacMinh { get; set; } = "";
    public string? GhiChu { get; set; }
}

public sealed class NhanVien
{
    public string MaNhanVien { get; set; } = "";
    public string MaTaiKhoan { get; set; } = "";
    public string MaCuaHang { get; set; } = "";
    public string HoTen { get; set; } = "";
    public string? DiaChi { get; set; }
    public string SoDienThoai { get; set; } = "";
    public string ChucVu { get; set; } = "";
    public string? Email { get; set; }
    public string TrangThai { get; set; } = "";
}

public sealed class GioHang
{
    public string MaGioHang { get; set; } = "";
    public string MaKhachThue { get; set; } = "";
    public DateTime NgayTao { get; set; }
    public DateTime NgayCapNhat { get; set; }
    public string TrangThai { get; set; } = "";
    public ICollection<ChiTietGioHang> ChiTiet { get; set; } = new List<ChiTietGioHang>();
}

public sealed class ChiTietGioHang
{
    public string MaChiTietGioHang { get; set; } = "";
    public string MaGioHang { get; set; } = "";
    public string MaCuaHang { get; set; } = "";
    public string NguonTao { get; set; } = "GIO_HANG";
    public Guid PhienBan { get; set; } = Guid.NewGuid();
    public bool DaChuyenHopDong { get; set; }
    public string MaDongMay { get; set; } = "";
    public int SoLuong { get; set; }
    public DateTime NgayBatDau { get; set; }
    public DateTime NgayKetThuc { get; set; }
    public decimal DonGia { get; set; }
    public decimal TienCoc { get; set; }
    public decimal ThanhTien { get; set; }
    public GioHang GioHang { get; set; } = null!;
}

public sealed class GiuCho
{
    public string MaGiuCho { get; set; } = "";
    public string MaGioHang { get; set; } = "";
    public string MaKhachThue { get; set; } = "";
    public string MaCuaHang { get; set; } = "";
    public DateTime NgayTao { get; set; }
    public DateTime HetHanLuc { get; set; }
    public string TrangThai { get; set; } = "";
    public ICollection<ChiTietGiuCho> ChiTiet { get; set; } = new List<ChiTietGiuCho>();
}

public sealed class ChiTietGiuCho
{
    public Guid? PhienBanGioHang { get; set; }
    public string MaChiTietGiuCho { get; set; } = "";
    public string MaGiuCho { get; set; } = "";
    public string? MaChiTietGioHang { get; set; }
    public string MaDongMay { get; set; } = "";
    public int SoLuong { get; set; }
    public DateTime NgayBatDau { get; set; }
    public DateTime NgayKetThuc { get; set; }
    public GiuCho GiuCho { get; set; } = null!;
}

// One model occupies one hold line; selected cart versions are retained independently.
public sealed class LuaChonGioHangGiuCho
{
    public string MaGiuCho { get; set; } = "";
    public string MaChiTietGioHang { get; set; } = "";
    public string MaDongMay { get; set; } = "";
    public Guid PhienBanGioHang { get; set; }
    public int SoLuong { get; set; }
}

public sealed class HopDong
{
    public string MaHopDong { get; set; } = "";
    public string MaGioHang { get; set; } = "";
    public string MaGiuCho { get; set; } = "";
    public string MaKhachThue { get; set; } = "";
    public string? MaNhanVien { get; set; }
    public string MaCuaHang { get; set; } = "";
    public DateTime NgayTaoHopDong { get; set; }
    public DateTime? NgayKy { get; set; }
    public string TrangThai { get; set; } = "";
    public DateTime ThoiGianBanGiao { get; set; }
    public DateTime ThoiGianTraDuKien { get; set; }
    public decimal TongTien { get; set; }
    public decimal TongTienCoc { get; set; }
    public string? HinhThucKy { get; set; }
    public string? TepHopDongUrl { get; set; }
    public bool DaDongYDieuKhoan { get; set; }
    public string? PhienBanDieuKhoan { get; set; }
    public string? MaBamNoiDung { get; set; }
    public string? MaBamTepPdf { get; set; }
    public string? NoiDungHopDongJson { get; set; }
}

public sealed class XacNhanKyHopDong
{
    public string MaXacNhan { get; set; } = "";
    public string MaHopDong { get; set; } = "";
    public string MaOtpHash { get; set; } = "";
    public string MuoiOtp { get; set; } = "";
    public DateTime TaoLuc { get; set; }
    public DateTime HetHanLuc { get; set; }
    public int SoLanThu { get; set; }
    public string TrangThai { get; set; } = "";
    public DateTime? XacNhanLuc { get; set; }
    public string? DiaChiIp { get; set; }
    public string? ThietBiKy { get; set; }
    public string PhienBanDieuKhoan { get; set; } = "";
    public string MaBamNoiDung { get; set; } = "";
    public string? MaBamTepPdf { get; set; }
    public string NoiDungHopDongJson { get; set; } = "";
}

public sealed class ChiTietHopDong
{
    public string MaChiTietHopDong { get; set; } = "";
    public string MaHopDong { get; set; } = "";
    public string MaThietBi { get; set; } = "";
    public decimal DonGia { get; set; }
    public string? TinhTrangLucGiao { get; set; }
    public DateTime? NgayGiaoThucTe { get; set; }
    public string? TinhTrangLucNhan { get; set; }
    public DateTime? NgayNhanThucTe { get; set; }
    public bool CoHuHong { get; set; }
}

public sealed class PhuLuc
{
    public DateTime? HanXuLyUtc { get; set; }
    public DateTime? HanKyUtc { get; set; }
    public DateTime? DuyetLucUtc { get; set; }
    public DateTime? KyLucUtc { get; set; }
    public DateTime? DongLucUtc { get; set; }
    public string? LyDoDong { get; set; }
    public DateTime? HieuLucTu { get; set; }
    public string? NguoiXuLy { get; set; }
    public string? MaBamNoiDung { get; set; }
    public string? MaBamTepPdf { get; set; }
    public string? NoiDungJson { get; set; }
    public string? PhienBanDieuKhoan { get; set; }
    [System.Text.Json.Serialization.JsonIgnore] public string? MaOtpHash { get; set; }
    [System.Text.Json.Serialization.JsonIgnore] public string? MuoiOtp { get; set; }
    public DateTime? OtpHetHanUtc { get; set; }
    public DateTime? OtpGuiLucUtc { get; set; }
    public int SoLanThuOtp { get; set; }
    public int SoLanGuiOtp { get; set; }
    public string? MaXacNhanKy { get; set; }
    public string? DiaChiIpKy { get; set; }
    public string MaPhuLuc { get; set; } = "";
    public string MaHopDong { get; set; } = "";
    public DateTime NgayLap { get; set; }
    public string TrangThai { get; set; } = "";
    public DateTime ThoiHanTraMoi { get; set; }
    public decimal ChiPhiPhatSinh { get; set; }
    public decimal TienCocBoSung { get; set; }
    public string? GhiChu { get; set; }
    public string? LyDoGiaHan { get; set; }
}

public sealed class ThanhToan
{
    public string? MaYeuCauHuy { get; set; }
    public string MaThanhToan { get; set; } = "";
    public string MaHopDong { get; set; } = "";
    public decimal SoTien { get; set; }
    public string LoaiThanhToan { get; set; } = "";
    public string PhuongThuc { get; set; } = "";
    public string? MaGiaoDich { get; set; }
    public DateTime? ThoiGian { get; set; }
    public string TrangThai { get; set; } = "";
    public string? NoiDungChuyenKhoan { get; set; }
    public string? NhaCungCap { get; set; }
    public string? MaThamChieu { get; set; }
    public string? MaNganHang { get; set; }
    public string? LoaiThe { get; set; }
    public string? MaPhanHoi { get; set; }
    public string? DuongDanThanhToan { get; set; }
    public DateTime? ThoiGianHetHan { get; set; }
    public DateTime? ThoiGianCapNhat { get; set; }
}

public sealed class YeuCauHuyHopDong
{
    public string LoaiYeuCau { get; set; } = "KHACH_YEU_CAU";
    public string? BangChung { get; set; }
    public bool CanAdminXuLy { get; set; }
    public string Id { get; set; } = "";
    public string MaHopDong { get; set; } = "";
    public string TrangThai { get; set; } = "CHO_XAC_NHAN";
    public DateTime YeuCauLucUtc { get; set; }
    public string LyDo { get; set; } = "";
    public string? NguoiXuLy { get; set; }
    public DateTime? XuLyLucUtc { get; set; }
    public string? LyDoXuLy { get; set; }
    public bool MienKhauTru { get; set; }
    public decimal TyLeKhauTru { get; set; }
    public decimal TienCocDaThu { get; set; }
    public decimal TienThueDaThu { get; set; }
    public decimal TienThuThuaDaThu { get; set; }
    public decimal TienKhauTru { get; set; }
    public decimal TienCocPhaiHoan { get; set; }
    public decimal TienThuePhaiHoan { get; set; }
    public decimal TienThuThuaPhaiHoan { get; set; }
}

public sealed class LichLamViec
{
    public string MaCuaHang { get; set; } = "*";
    public int NgayTrongTuan { get; set; }
    public TimeOnly GioMoCua { get; set; }
    public TimeOnly GioDongCua { get; set; }
}
public sealed class LichLamViecDacBiet
{
    public string MaCuaHang { get; set; } = "";
    public DateOnly Ngay { get; set; }
    public TimeOnly? GioMoCua { get; set; }
    public TimeOnly? GioDongCua { get; set; }
    public string LyDo { get; set; } = "";
}
public sealed class NhatKyNghiepVu
{
    public string Id { get; set; } = "";
    public string HanhDong { get; set; } = "";
    public string DoiTuongId { get; set; } = "";
    public string MaTaiKhoan { get; set; } = "";
    public DateTime ThoiGianUtc { get; set; }
    public string LyDo { get; set; } = "";
    public string DuLieuJson { get; set; } = "";
}

public sealed class HoanTienAudit
{
    public string Id { get; set; } = "";
    public string MaThanhToan { get; set; } = "";
    public string MaTaiKhoan { get; set; } = "";
    public string ChungTu { get; set; } = "";
    public DateTime ThoiGianUtc { get; set; }
}

public sealed class YeuCauThanhToanVnpay
{
    public string MaYeuCau { get; set; } = "";
    public string MaThanhToan { get; set; } = "";
    public string MaThamChieu { get; set; } = "";
    public decimal SoTien { get; set; }
    public string TienTe { get; set; } = "VND";
    public string DuongDanThanhToan { get; set; } = "";
    public DateTime ThoiGianHetHan { get; set; }
    public string TrangThai { get; set; } = "CHO_THANH_TOAN";
    public bool LaThuThua { get; set; }
    public string? MaGiaoDich { get; set; }
    public string? MaNganHang { get; set; }
    public string? LoaiThe { get; set; }
    public string? MaPhanHoi { get; set; }
    public string? GhiChu { get; set; }
    public DateTime ThoiGianTao { get; set; } = DateTime.UtcNow;
    public DateTime? ThoiGianCapNhat { get; set; }
}

public sealed class PhieuPhat
{
    public string MaPhieuPhat { get; set; } = "";
    public string MaChiTietHopDong { get; set; } = "";
    public string LoaiViPham { get; set; } = "";
    public decimal SoTien { get; set; }
    public string MoTa { get; set; } = "";
    public DateTime NgayLap { get; set; }
    public string TrangThai { get; set; } = "";
}

public sealed class AnhBienBan
{
    public string MaAnhBienBan { get; set; } = "";
    public string MaChiTietHopDong { get; set; } = "";
    public string Loai { get; set; } = "";
    public string DuongDanAnh { get; set; } = "";
    public string? MoTa { get; set; }
    public DateTime ThoiGianChup { get; set; }
}

public sealed class DanhGia
{
    public string MaDanhGia { get; set; } = "";
    public string MaChiTietHopDong { get; set; } = "";
    public string MaKhachThue { get; set; } = "";
    public string? NhanXet { get; set; }
    public byte SoSao { get; set; }
    public DateTime NgayDanhGia { get; set; }
    // Visibility, not an endorsement or prior approval by staff.
    public string? TrangThaiKiemDuyet { get; set; } = "CONG_KHAI";
    public string? GhiChuKiemDuyet { get; set; }
    public DateTime? NgayKiemDuyet { get; set; }
}

public sealed class LichSuHienThiDanhGia
{
    public string Id { get; set; } = "";
    public string MaDanhGia { get; set; } = "";
    public string MaTaiKhoan { get; set; } = "";
    public string? TrangThaiTruoc { get; set; }
    public string TrangThaiSau { get; set; } = "";
    public string LyDo { get; set; } = "";
    public DateTime ThoiGianUtc { get; set; }
}

public sealed class DanhGiaDiemNoiBat
{
    public string MaDanhGia { get; set; } = "";
    public string MaDiemNoiBat { get; set; } = "";
}

public sealed class AnhDanhGia
{
    public string MaAnhDanhGia { get; set; } = "";
    public string MaDanhGia { get; set; } = "";
    public string DuongDanAnh { get; set; } = "";
    public string PublicId { get; set; } = "";
    public byte ThuTu { get; set; }
    public DateTime NgayTao { get; set; }
}

public sealed class ThongBao
{
    public DateTime? HanTraNhac { get; set; }
    public string? EventKey { get; set; }
    public string MaThongBao { get; set; } = "";
    public string MaTaiKhoan { get; set; } = "";
    public string Loai { get; set; } = "";
    public string TieuDe { get; set; } = "";
    public string NoiDung { get; set; } = "";
    public DateTime ThoiGianGui { get; set; }
    public bool DaDoc { get; set; }

    public string? EventCode { get; set; }
    public string? TargetType { get; set; }
    public string? TargetId { get; set; }
}

public sealed class NotificationDelivery
{
    public string Id { get; set; } = "";
    public string MaThongBao { get; set; } = "";
    public string DeviceTokenId { get; set; } = "";
    public string State { get; set; } = "PENDING";
    public int Attempts { get; set; }
    public DateTime NextAttemptUtc { get; set; }
    public DateTime? LeaseUntilUtc { get; set; }
    public string? LastErrorCode { get; set; }
}

public sealed class FcmDeviceToken
{
    public string Id { get; set; } = "";
    public string MaTaiKhoan { get; set; } = "";
    public string Token { get; set; } = "";
    public string TokenHash { get; set; } = "";
    public string Platform { get; set; } = "";
    public string? DeviceId { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public sealed class IdempotencyKeyRecord
{
    public string IdempotencyKey { get; set; } = "";
    public string MaKhachThue { get; set; } = "";
    public string LoaiThaoTac { get; set; } = "";
    public string PayloadHash { get; set; } = "";
    public string MaThucThe { get; set; } = "";
    public DateTime NgayTao { get; set; }
}

public sealed class BankTransferOptions
{
    public string NganHang { get; set; } = "";
    public string MaBin { get; set; } = "";
    public string SoTaiKhoan { get; set; } = "";
    public string ChuTaiKhoan { get; set; } = "";

    public bool IsValid =>
        !string.IsNullOrWhiteSpace(NganHang) &&
        !string.IsNullOrWhiteSpace(MaBin) &&
        !string.IsNullOrWhiteSpace(SoTaiKhoan) &&
        !string.IsNullOrWhiteSpace(ChuTaiKhoan);
}
