namespace RentalCamera.ViewModels;

public class BranchReviewVM
{
    public string MaDanhGia { get; set; } = "";
    public string HoTen { get; set; } = "";
    public string TenDongMay { get; set; } = "";
    public string SoSerial { get; set; } = "";
    public int SoSao { get; set; }
    public string? NhanXet { get; set; }
    public DateTime NgayDanhGia { get; set; }

    public string TrangThaiKiemDuyet { get; set; } = "";
}