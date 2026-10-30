using System.Reflection;
using System.Text.Json;
using RentalCamera.Api.Contracts;
using RentalCamera.Api.Data;

// Pure DTO tests: no API startup, database, gateway or real account information.
var method = typeof(ContractEndpoints).GetMethod("ToPaymentDto", BindingFlags.NonPublic | BindingFlags.Static)
    ?? throw new Exception("Payment DTO mapper was not found.");
var bank = new BankTransferOptions
{
    NganHang = "TEST_BANK", MaBin = "TEST_BIN",
    SoTaiKhoan = "TEST_ACCOUNT", ChuTaiKhoan = "TEST_RECIPIENT"
};
var payment = new ThanhToan
{
    MaThanhToan = "PAYMENT_FIXTURE", MaHopDong = "CONTRACT_FIXTURE",
    PhuongThuc = "CHUYEN_KHOAN", LoaiThanhToan = "TIEN_COC",
    TrangThai = "CHO_THANH_TOAN", SoTien = 250000
};
JsonElement Map() => JsonSerializer.SerializeToElement(
    method.Invoke(null, [payment, bank, null]), new JsonSerializerOptions(JsonSerializerDefaults.Web));
void Check(bool condition, string name)
{
    if (!condition) throw new Exception(name);
    Console.WriteLine("PASS " + name);
}
Check(!new BankTransferOptions().IsValid && bank.IsValid, "bank configuration requires all receiver fields");
var dto = Map();
Check(dto.GetProperty("soTaiKhoan").GetString() == "TEST_ACCOUNT", "legacy transfer falls back to configured receiver");
Check(dto.GetProperty("soTien").GetDecimal() == 250000 && dto.GetProperty("trangThai").GetString() == "CHO_THANH_TOAN",
    "mapping preserves the payment amount and pending status");
payment.DuongDanThanhToan = "{\"nganHang\":\"SNAPSHOT_BANK\",\"maBin\":\"SNAPSHOT_BIN\",\"soTaiKhoan\":\"SNAPSHOT_ACCOUNT\",\"chuTaiKhoan\":\"SNAPSHOT_RECIPIENT\"}";
dto = Map();
Check(dto.GetProperty("soTaiKhoan").GetString() == "SNAPSHOT_ACCOUNT"
    && dto.GetProperty("chuTaiKhoan").GetString() == "SNAPSHOT_RECIPIENT", "issued transfer retains its receiver snapshot");
payment.DuongDanThanhToan = "{invalid";
Check(Map().GetProperty("soTaiKhoan").GetString() == "TEST_ACCOUNT", "invalid legacy snapshot falls back without throwing");
payment.PhuongThuc = "VI_DIEN_TU";
dto = Map();
Check(dto.GetProperty("nganHang").ValueKind == JsonValueKind.Null
    && dto.GetProperty("soTaiKhoan").ValueKind == JsonValueKind.Null, "electronic payment does not acquire transfer receiver fields");
payment.PhuongThuc = "TIEN_MAT";
payment.DuongDanThanhToan = null;
dto = Map();
Check(dto.GetProperty("phuongThuc").GetString() == "TIEN_MAT"
    && dto.GetProperty("trangThai").GetString() == "CHO_THANH_TOAN"
    && dto.GetProperty("soTien").GetDecimal() == 250000,
    "cash selection preserves server amount and pending status");
Check(dto.GetProperty("nganHang").ValueKind == JsonValueKind.Null
    && dto.GetProperty("soTaiKhoan").ValueKind == JsonValueKind.Null,
    "cash does not acquire bank transfer instructions");
payment.TrangThai = "THANH_CONG";
Check(Map().GetProperty("trangThai").GetString() == "THANH_CONG",
    "cash mapper reports the recorded status without inventing a transition");
