using RentalCamera.Models;
namespace RentalCamera.ViewModels;
public class DashboardVM {
 public int DangThue {get;set;} public int TongThietBi {get;set;} public int DonHomNay {get;set;} public decimal DoanhThuThang {get;set;}
 public Dictionary<string,int> TrangThai {get;set;}=new(); public List<(string Ten,int Luot)> PhoBien {get;set;}=new();
 public List<HopDong> LichHomNay {get;set;}=new(); public List<HopDong> DonGanDay {get;set;}=new();
 public List<HopDong> LichSapToi {get;set;}=new(); public Dictionary<string,int> ViecCanXuLy {get;set;}=new();
 public List<decimal> DoanhThuTheoThang {get;set;}=new(); public int NamBaoCao {get;set;}
}
public class DeviceVM { public List<ThietBi> Items{get;set;}=new(); public List<DanhMuc> DanhMuc{get;set;}=new(); public List<ThuongHieu> ThuongHieu{get;set;}=new(); public Dictionary<string,string> Anh{get;set;}=new(); }
public class OrderVM { public List<GioHang> GioHang{get;set;}=new(); public List<HopDong> HopDong{get;set;}=new(); }
public class ReportVM { public decimal DoanhThu{get;set;} public int DonThanhCong{get;set;} public int TongThietBi{get;set;} public decimal TyLeLapDay{get;set;} public Dictionary<string,decimal> DoanhThuTheoLoai{get;set;}=new(); public Dictionary<string,int> TinhTrangThietBi{get;set;}=new(); public Dictionary<string,int> DonTheoTrangThai{get;set;}=new(); public List<(string Ten,decimal DoanhThu)> Top{get;set;}=new(); }

public class AvailabilityVM { public DateTime TuNgay{get;set;} public DateTime DenNgay{get;set;} public string? Q{get;set;} public List<HopDong> HopDong{get;set;}=new(); public List<ThietBi> ThietBi{get;set;}=new(); public HashSet<string> MaThietBiBan{get;set;}=new(); }
