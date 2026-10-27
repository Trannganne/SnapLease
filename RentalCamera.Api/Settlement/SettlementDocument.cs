using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace RentalCamera.Api.Settlement;

public sealed record SettlementCharge(string Id, string Loai, string MoTa, decimal SoTien,
    string? NguonId = null, string? MaChiTietHopDong = null, decimal? DonGia = null, int? SoNgay = null);
public sealed record SettlementSource(string MaThanhToan, string LoaiThanhToan, string PhuongThuc,
    decimal SoTien, string TrangThai, DateTime? ThoiGian = null, string? MaThamChieu = null);
public sealed record SettlementAllocation(string MaThanhToanNguon, string MaKhoan, decimal SoTien);
public sealed record SettlementDocument(int SchemaVersion, string MaHopDong, DateTime ChotLucUtc,
    string NguoiChot, DateTime HanTraHieuLuc, IReadOnlyList<SettlementCharge> NghiaVu,
    IReadOnlyList<SettlementSource> NguonThu, IReadOnlyList<SettlementAllocation> PhanBo,
    decimal ConPhaiThu, decimal TongDuocHoanCoc, decimal TongDuocHoanKhac)
{
    public decimal TongNghiaVu => NghiaVu.Sum(x => x.SoTien);
    public decimal CocDaThu => NguonThu.Where(x => x.LoaiThanhToan == "TIEN_COC").Sum(x => x.SoTien);
    public decimal ThuePhiDaThu => NguonThu.Where(x => x.LoaiThanhToan != "TIEN_COC").Sum(x => x.SoTien);
    public decimal CocKhauTru => PhanBo.Where(a => NguonThu.Any(s => s.MaThanhToan == a.MaThanhToanNguon && s.LoaiThanhToan == "TIEN_COC")).Sum(x => x.SoTien);
}

public static class SettlementJson
{
    public static readonly JsonSerializerOptions Options = new(JsonSerializerDefaults.Web);
    public static string Write<T>(T value) => JsonSerializer.Serialize(value, Options);
    public static T? Read<T>(string? value) where T : class => value is null ? null : JsonSerializer.Deserialize<T>(value, Options);
    public static string Hash(string json) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(json)));
}

public static class SettlementLedger
{
    private static readonly string[] Order = ["TIEN_THUE", "PHI_GIA_HAN", "TRA_TRE", "BOI_THUONG"];

    public static SettlementDocument Create(string contractId, string actor, DateTime nowUtc, DateTime due,
        IReadOnlyList<SettlementCharge> charges, IReadOnlyList<SettlementSource> sources)
    {
        if (charges.Any(c => c.SoTien < 0 || c.SoTien != Math.Round(c.SoTien, 2) || !Order.Contains(c.Loai) || string.IsNullOrWhiteSpace(c.Id)) ||
            sources.Any(s => s.SoTien <= 0 || s.TrangThai != "THANH_CONG" ||
                s.SoTien != Math.Round(s.SoTien, 2) || string.IsNullOrWhiteSpace(s.MaThanhToan) ||
                s.LoaiThanhToan is not ("TIEN_COC" or "TIEN_THUE" or "PHI_GIA_HAN" or "PHI_PHAT")) ||
            charges.Select(c => c.Id).Distinct().Count() != charges.Count ||
            sources.Select(s => s.MaThanhToan).Distinct().Count() != sources.Count)
            throw new InvalidOperationException("Nguồn quyết toán không hợp lệ hoặc bị trùng.");
        var ordered = charges.OrderBy(c => Array.IndexOf(Order, c.Loai)).ThenBy(c => c.Id, StringComparer.Ordinal).ToArray();
        var remaining = ordered.ToDictionary(c => c.Id, c => c.SoTien);
        var allocations = new List<SettlementAllocation>();
        decimal refundDeposit = 0, refundOther = 0;
        // Confirmed non-deposit receipts are consumed first. The deposit only
        // covers remaining obligations, in the user-approved order.
        foreach (var source in sources.OrderBy(s => s.LoaiThanhToan == "TIEN_COC")
                     .ThenBy(s => s.MaThanhToan, StringComparer.Ordinal))
        {
            var available = source.SoTien;
            foreach (var charge in ordered)
            {
                var amount = Math.Min(remaining[charge.Id], available);
                if (amount == 0) continue;
                allocations.Add(new(source.MaThanhToan, charge.Id, amount));
                remaining[charge.Id] -= amount;
                available -= amount;
            }
            if (source.LoaiThanhToan == "TIEN_COC") refundDeposit += available;
            else refundOther += available;
        }
        return new(1, contractId, nowUtc, actor, due, ordered, sources.ToArray(), allocations,
            remaining.Values.Sum(), refundDeposit, refundOther);
    }

    public static void ValidateFullReturn(IEnumerable<string> expected, IEnumerable<string> supplied)
    {
        var a = expected.ToArray(); var b = supplied.ToArray();
        if (a.Length == 0 || b.Distinct(StringComparer.Ordinal).Count() != b.Length ||
            a.Length != b.Length || !a.ToHashSet(StringComparer.Ordinal).SetEquals(b))
            throw new InvalidOperationException("Phải nhận toàn bộ thiết bị đã bàn giao đúng một lần, không thiếu/trùng/thừa serial.");
    }

    public static bool CanComplete(bool fullReturn, bool inspectionDone, bool hasException,
        decimal outstandingCollection, decimal outstandingRefund, bool allRefundsAcknowledged,
        bool pendingOrUnknown, bool openFeedback, bool noRefundPolicyConfirmed, bool customerAgreed,
        bool originallyHadRefund) => fullReturn && inspectionDone && !hasException &&
        outstandingCollection == 0 && outstandingRefund == 0 && !pendingOrUnknown && !openFeedback &&
        (originallyHadRefund ? allRefundsAcknowledged : noRefundPolicyConfirmed && customerAgreed);
}

public sealed record ReturnAccessory(string Ten, int? SoLuongBanGiao, int? SoLuongThucNhan,
    string TinhTrang, string? NguonCanCu = null);
public sealed record ReturnInspectionItem(string MaChiTietHopDong, string SoSerial, string TenDongMay,
    string TinhTrang, bool CoHuHong, bool ThieuPhuKien,
    IReadOnlyList<ReturnAccessory> PhuKien, string? AnhUrl = null, string? KetLuan = null,
    IReadOnlyList<string>? MaPhieuPhat = null);
public sealed record ReturnException(string MaChiTietHopDong, string SoSerial, string Loai,
    string LyDo, string NguoiGhiNhan, DateTime GhiNhanLucUtc);
public sealed record ReturnReceipt(int SchemaVersion, DateTime? ThucNhanLuc, DateTime GhiNhanLucUtc,
    string NguoiGhiNhan, DateTime? KiemTraLucUtc, IReadOnlyList<ReturnInspectionItem> ThietBi,
    IReadOnlyList<ReturnException> NgoaiLe);
public sealed record SettlementFeedback(string Id, string Loai, string NoiDung, string Actor,
    DateTime TaoLucUtc, string Hash, string? MaThanhToan, string TrangThai = "MO",
    string? TraLoi = null, string? NguoiTraLoi = null, DateTime? TraLoiLucUtc = null);
