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
    public string HoTen { get; set; } = "";
    public string SoDienThoai { get; set; } = "";
    public string? Email { get; set; }
    public string? CCCD { get; set; }
    public string? DiaChi { get; set; }
    public DateOnly? NgaySinh { get; set; }
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
    public string MaCuaHang { get; set; } = "";
    public DateTime NgayTao { get; set; }
    public DateTime NgayCapNhat { get; set; }
    public string TrangThai { get; set; } = "";
    public ICollection<ChiTietGioHang> ChiTiet { get; set; } = new List<ChiTietGioHang>();
}

public sealed class ChiTietGioHang
{
    public string MaChiTietGioHang { get; set; } = "";
    public string MaGioHang { get; set; } = "";
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
    public string MaChiTietGiuCho { get; set; } = "";
    public string MaGiuCho { get; set; } = "";
    public string MaDongMay { get; set; } = "";
    public int SoLuong { get; set; }
    public DateTime NgayBatDau { get; set; }
    public DateTime NgayKetThuc { get; set; }
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
    public bool DaDongYDieuKhoan { get; set; }
    public string? PhienBanDieuKhoan { get; set; }
    public string? MaBamNoiDung { get; set; }
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
    public string MaThanhToan { get; set; } = "";
    public string MaHopDong { get; set; } = "";
    public decimal SoTien { get; set; }
    public string LoaiThanhToan { get; set; } = "";
    public string PhuongThuc { get; set; } = "";
    public string? MaGiaoDich { get; set; }
    public DateTime? ThoiGian { get; set; }
    public string TrangThai { get; set; } = "";
    public string? NoiDungChuyenKhoan { get; set; }
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
}

public sealed class ThongBao
{
    public string MaThongBao { get; set; } = "";
    public string MaTaiKhoan { get; set; } = "";
    public string Loai { get; set; } = "";
    public string TieuDe { get; set; } = "";
    public string NoiDung { get; set; } = "";
    public DateTime ThoiGianGui { get; set; }
    public bool DaDoc { get; set; }
}
