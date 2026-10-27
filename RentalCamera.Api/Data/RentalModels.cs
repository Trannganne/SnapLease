namespace RentalCamera.Api.Data;
// Schema33: retained source keys and navigation properties; no removed-table aliases.
public sealed class TaiKhoan
{
    public string MaTaiKhoan { get; set; } = "";
    public string TenDangNhap { get; set; } = "";
    [System.Text.Json.Serialization.JsonIgnore] public string MatKhauHash { get; set; } = "";
    public string VaiTro { get; set; } = "";
    public string TrangThai { get; set; } = "HOAT_DONG";
    public DateTime NgayTao { get; set; }
    public int PhienBanBaoMat { get; set; } = 0;
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
    public bool DaXacNhanThongTin { get; set; } = false;
    public DateTime? EmailXacMinhLucUtc { get; set; }
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
    public decimal PhanTramGiamGia { get; set; } = 0;
    public ICollection<AnhThietBi> AnhThietBi { get; set; } = new List<AnhThietBi>();
    public DanhMuc DanhMuc { get; set; } = null!;
    public ThuongHieu ThuongHieu { get; set; } = null!;
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

public sealed class AnhThietBi
{
    public string MaAnh { get; set; } = "";
    public string MaDongMay { get; set; } = "";
    public string DuongDanAnh { get; set; } = "";
    public bool LaAnhDaiDien { get; set; } = false;
    public int ThuTuHienThi { get; set; } = 0;
    public DongMay DongMay { get; set; } = null!;
}

public sealed class CuaHang
{
    public string MaCuaHang { get; set; } = "";
    public string TenCuaHang { get; set; } = "";
    public decimal? ViDo { get; set; }
    public decimal? KinhDo { get; set; }
    public string DiaChi { get; set; } = "";
    public string SoDienThoai { get; set; } = "";
    public string? Email { get; set; }
    public string? MoTa { get; set; }
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
    public bool DaChuyenHopDong { get; set; } = false;
    public string MaDongMay { get; set; } = "";
    public int SoLuong { get; set; } = 1;
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
    public Guid PhienBanGioHang { get; set; } = Guid.NewGuid();
    public string MaChiTietGiuCho { get; set; } = "";
    public string MaGiuCho { get; set; } = "";
    public string MaChiTietGioHang { get; set; } = "";
    public string MaDongMay { get; set; } = "";
    public int SoLuong { get; set; }
    public DateTime NgayBatDau { get; set; }
    public DateTime NgayKetThuc { get; set; }
    public string? MaChiTietGioHangHopDong { get; set; }
    public GiuCho GiuCho { get; set; } = null!;
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
    public bool DaDongYDieuKhoan { get; set; } = false;
    public string? PhienBanDieuKhoan { get; set; }
    public string? MaBamNoiDung { get; set; }
    public string? MaBamTepPdf { get; set; }
    public string? NoiDungHopDongJson { get; set; }
    public string? TrangThaiNhanTra { get; set; }
}

public sealed class ChiTietHopDong
{
    public string? MaBienBanNhanTra { get; set; }
    public string? KetQuaKiemTra { get; set; }
    public bool? ThieuPhuKien { get; set; }
    public string? TinhTrangPhuKien { get; set; }
    public string? LoaiNgoaiLeNhanTra { get; set; }
    public string? LyDoNgoaiLeNhanTra { get; set; }
    public string MaChiTietHopDong { get; set; } = "";
    public string MaHopDong { get; set; } = "";
    public string MaThietBi { get; set; } = "";
    public decimal DonGia { get; set; }
    public string? TinhTrangLucGiao { get; set; }
    public DateTime? NgayGiaoThucTe { get; set; }
    public string? TinhTrangLucNhan { get; set; }
    public DateTime? NgayNhanThucTe { get; set; }
    public bool CoHuHong { get; set; } = false;
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
    public int SoLanThuOtp { get; set; } = 0;
    public int SoLanGuiOtp { get; set; } = 0;
    public string? MaXacNhanKy { get; set; }
    public string? DiaChiIpKy { get; set; }
    public string MaPhuLuc { get; set; } = "";
    public string MaHopDong { get; set; } = "";
    public DateTime NgayLap { get; set; }
    public string TrangThai { get; set; } = "";
    public DateTime ThoiHanTraMoi { get; set; }
    public decimal ChiPhiPhatSinh { get; set; }
    public decimal TienCocBoSung { get; set; } = 0;
    public string? GhiChu { get; set; }
    public string? LyDoGiaHan { get; set; }
}

public sealed class XacNhanKyHopDong
{
    public string MaXacNhan { get; set; } = "";
    public string MaHopDong { get; set; } = "";
    [System.Text.Json.Serialization.JsonIgnore] public string MaOtpHash { get; set; } = "";
    [System.Text.Json.Serialization.JsonIgnore] public string MuoiOtp { get; set; } = "";
    public DateTime TaoLuc { get; set; }
    public DateTime HetHanLuc { get; set; }
    public int SoLanThu { get; set; } = 0;
    public string TrangThai { get; set; } = "";
    public DateTime? XacNhanLuc { get; set; }
    public string? DiaChiIp { get; set; }
    public string? ThietBiKy { get; set; }
    public string PhienBanDieuKhoan { get; set; } = "";
    public string MaBamNoiDung { get; set; } = "";
    public string? MaBamTepPdf { get; set; }
    public string NoiDungHopDongJson { get; set; } = "";
}

public sealed class ThanhToan
{
    public string? MaQuyetToan { get; set; }
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
    public string? NguoiXacNhanHoan { get; set; }
    public DateTime? XacNhanHoanLucUtc { get; set; }
    public string? NguoiXacNhanNhanHoan { get; set; }
    public DateTime? KhachXacNhanNhanHoanLucUtc { get; set; }
    public string? MaDoiSoatHuyHopDong { get; set; }
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
    public DateTime ThoiGianTao { get; set; }
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
    public string NguoiLap { get; set; } = "";
    public string? NguoiXuLy { get; set; }
    public DateTime? XuLyLucUtc { get; set; }
}

public sealed class QuyetToanHopDong
{
    public string Id { get; set; } = "";
    public string MaHopDong { get; set; } = "";
    public string MaBienBan { get; set; } = "";
    public int PhienBan { get; set; } = 1;
    public string MaBam { get; set; } = "";
    public string NguoiChot { get; set; } = "";
    public DateTime ChotLucUtc { get; set; }
    public DateTime HanTraHieuLuc { get; set; }
    public decimal TienThue { get; set; }
    public decimal PhiGiaHan { get; set; }
    public decimal PhiTraTre { get; set; }
    public decimal BoiThuong { get; set; }
    public decimal TongNghiaVu { get; set; }
    public decimal ThuePhiDaThu { get; set; }
    public decimal CocDaThu { get; set; }
    public decimal CocKhauTru { get; set; }
    public decimal ConPhaiThuBanDau { get; set; }
    public decimal HoanCocBanDau { get; set; }
    public decimal HoanKhacBanDau { get; set; }
    public DateTime? HoanThanhLucUtc { get; set; }
    public DateTime? KhachXacNhanHoanTatLucUtc { get; set; }
    public string? NguoiXacNhanHoanTat { get; set; }
}

public sealed class PhanBoQuyetToan
{
    public string Id { get; set; } = "";
    public string MaHopDong { get; set; } = "";
    public string MaQuyetToan { get; set; } = "";
    public string LoaiDong { get; set; } = "NGHIA_VU";
    public string LoaiNghiaVu { get; set; } = "";
    public string MoTa { get; set; } = "";
    public decimal SoTien { get; set; }
    public string? MaNghiaVu { get; set; }
    public string? MaThanhToan { get; set; }
    public string? MaChiTietHopDong { get; set; }
    public string? MaPhuLuc { get; set; }
    public string? MaPhieuPhat { get; set; }
    public decimal? DonGia { get; set; }
    public int? SoNgay { get; set; }
    public DateTime TaoLucUtc { get; set; }
}

public sealed class DanhGia
{
    public string MaDanhGia { get; set; } = "";
    public string MaChiTietHopDong { get; set; } = "";
    public string MaKhachThue { get; set; } = "";
    public string? NhanXet { get; set; }
    public byte SoSao { get; set; }
    public DateTime NgayDanhGia { get; set; }
    public string? TrangThaiKiemDuyet { get; set; }
    public string? GhiChuKiemDuyet { get; set; }
    public DateTime? NgayKiemDuyet { get; set; }
    public string? NguoiCapNhatHienThi { get; set; }
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

public sealed class AnhBienBan
{
    public string MaAnhBienBan { get; set; } = "";
    public string MaChiTietHopDong { get; set; } = "";
    public string Loai { get; set; } = "";
    public string DuongDanAnh { get; set; } = "";
    public string? MoTa { get; set; }
    public DateTime ThoiGianChup { get; set; }
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
    public bool DaDoc { get; set; } = false;
    public string? EventCode { get; set; }
    public string? TargetType { get; set; }
    public string? TargetId { get; set; }
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

public sealed class NotificationDelivery
{
    public string Id { get; set; } = "";
    public string MaThongBao { get; set; } = "";
    public string DeviceTokenId { get; set; } = "";
    public string State { get; set; } = "PENDING";
    public int Attempts { get; set; } = 0;
    public DateTime NextAttemptUtc { get; set; }
    public DateTime? LeaseUntilUtc { get; set; }
    public string? LastErrorCode { get; set; }
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

public sealed class BienBanNhanTra
{
    public string Id { get; set; } = "";
    public string MaHopDong { get; set; } = "";
    public DateTime? ThucNhanLuc { get; set; }
    public string NguoiGhiNhan { get; set; } = "";
    public DateTime GhiNhanLucUtc { get; set; }
    public string? LyDoGhiNhanMuon { get; set; }
    public DateTime? KiemTraLucUtc { get; set; }
    public string? NguoiKiemTra { get; set; }
    public DateTime? ThucNhanLucTruocSua { get; set; }
    public string? NguoiSuaThucNhan { get; set; }
    public DateTime? SuaThucNhanLucUtc { get; set; }
    public string? LyDoSuaThucNhan { get; set; }
}

public sealed class DoiSoatHuyHopDong
{
    public string MaHopDong { get; set; } = "";
    public DateTime HuyLucUtc { get; set; }
    public string? NguoiHuy { get; set; }
    public string LoaiTacNhanHuy { get; set; } = "";
    public string LoaiHuy { get; set; } = "";
    public string LyDoHuy { get; set; } = "";
    public decimal TyLeKhauTruHuy { get; set; }
    public decimal TienCocDaThuKhiHuy { get; set; }
    public decimal TienThueDaThuKhiHuy { get; set; }
    public decimal TienThuThuaDaThuKhiHuy { get; set; }
    public decimal TienKhauTruHuy { get; set; }
    public decimal TienCocPhaiHoanKhiHuy { get; set; }
    public decimal TienThuePhaiHoanKhiHuy { get; set; }
    public decimal TienThuThuaPhaiHoanKhiHuy { get; set; }
    public DateTime DoiSoatHuyLucUtc { get; set; }
    public string? CanCuNgoaiLeHuy { get; set; }
    public string? LyDoNgoaiLeHuy { get; set; }
    public string? TaiLieuNgoaiLeHuyUrl { get; set; }
}

public sealed class XacMinhKhachKhongDen
{
    public string MaHopDong { get; set; } = "";
    public string NguoiXacMinh { get; set; } = "";
    public DateTime XacMinhLucUtc { get; set; }
    public DateTime GioHenKhiXacMinhKhongDen { get; set; }
    public bool KhongCoLichHenMoi { get; set; }
    public bool CuaHangSanSangBanGiao { get; set; }
    public bool KhachChuaCheckIn { get; set; }
    public bool DaThuLienHe { get; set; }
    public DateTime LienHeLucUtc { get; set; }
    public string KenhLienHe { get; set; } = "";
    public string KetQuaLienHe { get; set; } = "";
    public bool CoTranhChapKhongDen { get; set; }
    public string GhiChuKhongDen { get; set; } = "";
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
