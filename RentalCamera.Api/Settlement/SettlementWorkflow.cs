using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Contracts;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Settlement;

public static class SettlementWorkflow
{
    public sealed record State(HopDong Contract, BienBanNhanTra? Receipt, QuyetToanHopDong? Final,
        List<ChiTietHopDong> Details, List<ThanhToan> Payments, List<PhanBoQuyetToan> Lines,
        List<PhuLuc> Appendices, List<PhieuPhat> Penalties);

    public static async Task<State?> LoadAsync(string id, RentalCameraContext db, CancellationToken ct)
    {
        var h = await db.HopDong.SingleOrDefaultAsync(x => x.MaHopDong == id, ct);
        if (h is null) return null;
        var receipt = await db.BienBanNhanTra.SingleOrDefaultAsync(x => x.MaHopDong == id, ct);
        var q = await db.QuyetToanHopDong.SingleOrDefaultAsync(x => x.MaHopDong == id, ct);
        var details = await db.ChiTietHopDong.Where(x => x.MaHopDong == id).ToListAsync(ct);
        var payments = await db.ThanhToan.Where(x => x.MaHopDong == id).ToListAsync(ct);
        var lines = q is null ? [] : await db.PhanBoQuyetToan.Where(x => x.MaQuyetToan == q.Id).ToListAsync(ct);
        var extensions = await db.PhuLuc.Where(x => x.MaHopDong == id).ToListAsync(ct);
        var penalties = await db.PhieuPhat.Where(p => db.ChiTietHopDong.Any(d => d.MaHopDong == id && d.MaChiTietHopDong == p.MaChiTietHopDong)).ToListAsync(ct);
        return new(h, receipt, q, details, payments, lines, extensions, penalties);
    }

    public static List<string> Blockers(State s)
    {
        var result = new List<string>();
        if (s.Contract.PhienBanDieuKhoan != RentalPolicy.TermsVersion || !s.Contract.DaDongYDieuKhoan)
            result.Add("Điều khoản cũ cần xử lý tương thích, chưa tự áp chính sách tài chính mới.");
        if (s.Receipt?.ThucNhanLuc is null || s.Details.Count == 0 || s.Details.Any(d => d.NgayNhanThucTe is null))
            result.Add("Chưa xác nhận nhận đủ toàn bộ thiết bị.");
        if (s.Details.Any(d => d.LoaiNgoaiLeNhanTra != null)) result.Add("Còn ngoại lệ thiếu/mất thiết bị; xử lý riêng, không giả nhận trả.");
        if (s.Receipt?.KiemTraLucUtc is null) result.Add("Chưa hoàn tất kiểm tra thiết bị/phụ kiện.");
        if (s.Penalties.Any(p => p.TrangThai == "CHO_XAC_NHAN")) result.Add("Còn khoản bồi thường chờ xử lý.");
        foreach (var d in s.Details)
        {
            foreach (var kind in new[] { "HU_HONG", "THIEU_PHU_KIEN" })
                if ((kind == "HU_HONG" ? d.CoHuHong : d.ThieuPhuKien == true) &&
                    !s.Penalties.Any(p => p.MaChiTietHopDong == d.MaChiTietHopDong && p.LoaiViPham == kind && p.TrangThai is "DA_XAC_NHAN" or "DA_THANH_TOAN"))
                    result.Add($"Thiết bị {d.MaThietBi}: {kind} chưa có kết luận bồi thường được Admin duyệt.");
        }
        if (s.Appendices.Any(p => p.TrangThai is "CHO_XAC_NHAN" or "CHO_KY")) result.Add("Còn yêu cầu gia hạn chưa xử lý xong.");
        if (s.Payments.Any(p => p.TrangThai == "CHO_THANH_TOAN" && p.MaQuyetToan is null)) result.Add("Còn giao dịch trước quyết toán chưa xác định kết quả.");
        if (s.Final is null && s.Payments.Any(p => p.LoaiThanhToan.StartsWith("HOAN_") && p.LoaiThanhToan != "HOAN_THU_THUA" && p.TrangThai != "THAT_BAI"))
            result.Add("Đã có khoản hoàn theo quy trình cũ, cần đối soát riêng.");
        if (s.Penalties.Any(p => p.LoaiViPham == "KHAC" && p.TrangThai != "HUY")) result.Add("Có khoản khác chưa được phân loại trong quyết toán mới.");
        return result;
    }

    public static async Task<SettlementDocument> QuoteAsync(State s, RentalCameraContext db, CancellationToken ct)
    {
        var due = await RenewalEndpoints.EffectiveReturnAsync(s.Contract, db, ct);
        var charges = new List<SettlementCharge> { new("rent", "TIEN_THUE", "Tiền thuê gốc", s.Contract.TongTien, s.Contract.MaHopDong) };
        var effective = s.Appendices.Where(p => p.TrangThai == "DA_HIEU_LUC" || s.Contract.PhienBanDieuKhoan != RentalPolicy.TermsVersion && p.TrangThai == "DA_XAC_NHAN").ToList();
        foreach (var p in effective) charges.Add(new(p.MaPhuLuc, "PHI_GIA_HAN", "Phí gia hạn có hiệu lực", p.ChiPhiPhatSinh, p.MaPhuLuc));
        if (effective.Count == 0) charges.Add(new("extension:none", "PHI_GIA_HAN", "Phí gia hạn có hiệu lực", 0));
        foreach (var d in s.Details)
        {
            var end = d.NgayNhanThucTe ?? RentalPolicy.LocalNow;
            charges.Add(new("late:" + d.MaChiTietHopDong, "TRA_TRE", "Phí trả trễ", LateReturnService.Cost(due, end, d.DonGia),
                d.MaChiTietHopDong, d.MaChiTietHopDong, d.DonGia, RentalPolicy.LateDays(due, end)));
        }
        foreach (var p in s.Penalties.Where(p => p.LoaiViPham is "HU_HONG" or "THIEU_PHU_KIEN" && p.TrangThai is "DA_XAC_NHAN" or "DA_THANH_TOAN"))
            charges.Add(new(p.MaPhieuPhat, "BOI_THUONG", p.MoTa, p.SoTien, p.MaPhieuPhat, p.MaChiTietHopDong));
        if (!charges.Any(c => c.Loai == "BOI_THUONG")) charges.Add(new("compensation:none", "BOI_THUONG", "Bồi thường đã duyệt", 0));
        var sources = s.Payments.Where(p => p.MaQuyetToan is null && p.TrangThai == "THANH_CONG" && !p.LoaiThanhToan.StartsWith("HOAN_"))
            .Select(p => new SettlementSource(p.MaThanhToan, p.LoaiThanhToan, p.PhuongThuc, p.SoTien, p.TrangThai, p.ThoiGian, p.MaThamChieu)).ToArray();
        return SettlementLedger.Create(s.Contract.MaHopDong, "preview", DateTime.UtcNow, due, charges, sources);
    }

    public static async Task<QuyetToanHopDong> FinalizeAsync(State s, string actor, RentalCameraContext db, CancellationToken ct)
    {
        if (s.Final is not null) return s.Final;
        if (s.Contract.TrangThai != "CHO_HOAN_TRA") throw new InvalidOperationException("Chỉ chốt sau khi nhận đủ thiết bị theo quy trình mới.");
        var blockers = Blockers(s);
        if (blockers.Count != 0) throw new InvalidOperationException(string.Join(" ", blockers));
        if (!await RentalCamera.Api.Payments.RefundWorkflow.ExcessResolvedAsync(s.Contract.MaHopDong, db, ct))
            throw new InvalidOperationException("Thu thừa chưa được hoàn và khách xác nhận; cần đối soát trước khi chốt.");
        var doc = await QuoteAsync(s, db, ct);
        doc = doc with { NguoiChot = actor };
        var q = new QuyetToanHopDong { Id = ApiAccess.NewId("QT"), MaHopDong = s.Contract.MaHopDong,
            MaBienBan = s.Receipt!.Id, MaBam = SettlementJson.Hash(SettlementJson.Write(doc)), NguoiChot = actor,
            ChotLucUtc = doc.ChotLucUtc, HanTraHieuLuc = doc.HanTraHieuLuc, TongNghiaVu = doc.TongNghiaVu,
            TienThue = doc.NghiaVu.Where(c => c.Loai == "TIEN_THUE").Sum(c => c.SoTien),
            PhiGiaHan = doc.NghiaVu.Where(c => c.Loai == "PHI_GIA_HAN").Sum(c => c.SoTien),
            PhiTraTre = doc.NghiaVu.Where(c => c.Loai == "TRA_TRE").Sum(c => c.SoTien),
            BoiThuong = doc.NghiaVu.Where(c => c.Loai == "BOI_THUONG").Sum(c => c.SoTien),
            ThuePhiDaThu = doc.ThuePhiDaThu, CocDaThu = doc.CocDaThu, CocKhauTru = doc.CocKhauTru,
            ConPhaiThuBanDau = doc.ConPhaiThu, HoanCocBanDau = doc.TongDuocHoanCoc, HoanKhacBanDau = doc.TongDuocHoanKhac };
        db.QuyetToanHopDong.Add(q);
        var ids = new Dictionary<string, string>();
        foreach (var c in doc.NghiaVu)
        {
            var id = ApiAccess.NewId("NV"); ids[c.Id] = id;
            db.PhanBoQuyetToan.Add(new() { Id = id, MaHopDong=q.MaHopDong, MaQuyetToan = q.Id, LoaiDong = "NGHIA_VU", LoaiNghiaVu = c.Loai,
                MoTa = c.MoTa.Length > 500 ? c.MoTa[..500] : c.MoTa, SoTien = c.SoTien, MaChiTietHopDong = c.MaChiTietHopDong,
                MaPhuLuc = c.Loai == "PHI_GIA_HAN" ? c.NguonId : null,
                MaPhieuPhat = c.Loai == "BOI_THUONG" ? c.NguonId : null, DonGia = c.DonGia, SoNgay = c.SoNgay, TaoLucUtc = doc.ChotLucUtc });
        }
        foreach (var a in doc.PhanBo) db.PhanBoQuyetToan.Add(new() { Id = ApiAccess.NewId("PB"), MaHopDong=q.MaHopDong, MaQuyetToan = q.Id,
            LoaiDong = "PHAN_BO", LoaiNghiaVu = doc.NghiaVu.Single(c => c.Id == a.MaKhoan).Loai,
            MaNghiaVu = ids[a.MaKhoan], MaThanhToan = a.MaThanhToanNguon, SoTien = a.SoTien, TaoLucUtc = doc.ChotLucUtc });
        return q;
    }

    public static decimal Collected(State s) => s.Payments.Where(p => p.MaQuyetToan == s.Final?.Id && p.LoaiThanhToan == "THU_QUYET_TOAN" && p.TrangThai == "THANH_CONG").Sum(p => p.SoTien);
    public static decimal Refunded(State s, string? kind = null) => s.Payments.Where(p => p.MaQuyetToan == s.Final?.Id && p.LoaiThanhToan.StartsWith("HOAN_") && p.TrangThai == "DA_HOAN" && (kind == null || p.LoaiThanhToan == kind)).Sum(p => p.SoTien);
    public static bool FinancialMismatch(State s) => s.Final is { } q && (
        s.Payments.Where(p => p.MaQuyetToan == null && p.TrangThai == "THANH_CONG" && p.LoaiThanhToan == "TIEN_COC").Sum(p => p.SoTien) != q.CocDaThu ||
        s.Payments.Where(p => p.MaQuyetToan == null && p.TrangThai == "THANH_CONG" && !p.LoaiThanhToan.StartsWith("HOAN_") && p.LoaiThanhToan != "TIEN_COC").Sum(p => p.SoTien) != q.ThuePhiDaThu ||
        Collected(s) > q.ConPhaiThuBanDau || Refunded(s, "HOAN_COC") > q.HoanCocBanDau || Refunded(s, "HOAN_TIEN_THUE") > q.HoanKhacBanDau);

    // Called inside the existing contract transaction after payment state is saved.
    public static async Task ReconcileAsync(string contractId, RentalCameraContext db, CancellationToken ct)
    {
        if (!await db.QuyetToanHopDong.AnyAsync(q => q.MaHopDong == contractId, ct)) return;
        var s = (await LoadAsync(contractId, db, ct))!; var q = s.Final!;
        if (RentalPolicy.ProtectedContracts.Contains(contractId) || s.Contract.TrangThai != "CHO_HOAN_TRA" || q.HoanThanhLucUtc != null || FinancialMismatch(s)) return;
        if (!await RentalCamera.Api.Payments.RefundWorkflow.ExcessResolvedAsync(contractId, db, ct)) return;
        foreach (var payment in s.Payments.Where(p => p.MaQuyetToan == q.Id && p.LoaiThanhToan == "THU_QUYET_TOAN" && p.TrangThai == "THANH_CONG"))
        {
            if (s.Lines.Any(l => l.LoaiDong == "PHAN_BO" && l.MaThanhToan == payment.MaThanhToan)) continue;
            var available = payment.SoTien;
            foreach (var charge in s.Lines.Where(l => l.LoaiDong == "NGHIA_VU").OrderBy(l => Array.IndexOf(new[] { "TIEN_THUE", "PHI_GIA_HAN", "TRA_TRE", "BOI_THUONG" }, l.LoaiNghiaVu)).ThenBy(l => l.Id))
            {
                var balance = charge.SoTien - s.Lines.Where(l => l.LoaiDong == "PHAN_BO" && l.MaNghiaVu == charge.Id).Sum(l => l.SoTien);
                var amount = Math.Min(balance, available); if (amount <= 0) continue;
                var line = new PhanBoQuyetToan { Id = ApiAccess.NewId("PB"), MaHopDong=q.MaHopDong, MaQuyetToan = q.Id,
                    LoaiDong = "PHAN_BO", LoaiNghiaVu = charge.LoaiNghiaVu, MaNghiaVu = charge.Id,
                    MaThanhToan = payment.MaThanhToan, SoTien = amount, TaoLucUtc = DateTime.UtcNow };
                db.PhanBoQuyetToan.Add(line); s.Lines.Add(line); available -= amount;
            }
            if (available != 0) throw new InvalidOperationException("Khoản thu không khớp phần nghĩa vụ còn thiếu; cần đối soát riêng.");
        }
        var refunds = s.Payments.Where(p => p.MaQuyetToan == q.Id && p.LoaiThanhToan.StartsWith("HOAN_") && p.TrangThai == "DA_HOAN").ToList();
        var ack = refunds.All(p => p.KhachXacNhanNhanHoanLucUtc != null && p.NguoiXacNhanNhanHoan != null);
        if (SettlementLedger.CanComplete(s.Receipt?.ThucNhanLuc != null, s.Receipt?.KiemTraLucUtc != null,
            s.Details.Any(d => d.LoaiNgoaiLeNhanTra != null), Math.Max(0, q.ConPhaiThuBanDau - Collected(s)),
            Math.Max(0, q.HoanCocBanDau + q.HoanKhacBanDau - Refunded(s)), ack,
            s.Payments.Any(p => p.TrangThai == "CHO_THANH_TOAN"), false, true,
            q.KhachXacNhanHoanTatLucUtc != null && q.NguoiXacNhanHoanTat != null, q.HoanCocBanDau + q.HoanKhacBanDau > 0))
        {
            s.Contract.TrangThai = "HOAN_THANH"; q.HoanThanhLucUtc = DateTime.UtcNow;
        }
        await db.SaveChangesAsync(ct);
    }

}
