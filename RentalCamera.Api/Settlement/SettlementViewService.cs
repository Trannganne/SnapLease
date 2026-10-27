using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Contracts;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;
using RentalCamera.Api.Payments;

namespace RentalCamera.Api.Settlement;

public static class SettlementViewService
{
    public static bool SandboxReady(VnpayService service, VnpayOptions options) => service.SettlementSandboxReady;

    public static async Task<object> ViewAsync(SettlementWorkflow.State s, ClaimsPrincipal principal,
        bool gatewayReady, RentalCameraContext db, CancellationToken ct)
    {
        var q = s.Final;
        var blockers = SettlementWorkflow.Blockers(s);
        var mismatch = SettlementWorkflow.FinancialMismatch(s);
        if (mismatch) blockers.Add("Dữ liệu tiền đã thay đổi ngoài quyết toán đã chốt; cần đối soát riêng, không sửa lịch sử.");
        SettlementDocument? quote = null;
        if (q is null && s.Contract.PhienBanDieuKhoan == RentalPolicy.TermsVersion && s.Contract.DaDongYDieuKhoan)
        {
            try { quote = await SettlementWorkflow.QuoteAsync(s, db, ct); }
            catch (InvalidOperationException) { blockers.Add("Chưa đủ căn cứ tính tiền; cần cửa hàng đối soát nguồn thu."); }
        }
        var paymentIds = s.Payments.Select(p => p.MaThanhToan).ToArray();
        if (!await RefundWorkflow.ExcessResolvedAsync(s.Contract.MaHopDong,db,ct)) {
            mismatch = true; blockers.Add("Thu thừa chưa được hoàn đủ và khách xác nhận.");
        }
        var customer = principal.IsInRole("KHACH_HANG") && await ApiAccess.CustomerIdAsync(principal, db, ct) == s.Contract.MaKhachThue;
        var refundable = q is null ? null : (decimal?)(q.HoanCocBanDau + q.HoanKhacBanDau);
        var recorded = q is null ? null : (decimal?)SettlementWorkflow.Refunded(s);
        var collected = q is null ? 0 : SettlementWorkflow.Collected(s);
        var remaining = q is null ? quote?.ConPhaiThu : Math.Max(0, q.ConPhaiThuBanDau - collected);
        var refunds = q is null ? [] : s.Payments.Where(p => p.MaQuyetToan == q.Id && p.LoaiThanhToan.StartsWith("HOAN_")).ToList();
        var ackIds = refunds.Where(p => p.TrangThai == "DA_HOAN" && p.KhachXacNhanNhanHoanLucUtc == null).Select(p => p.MaThanhToan).ToArray();
        var canAct = customer && q is not null && !mismatch && s.Contract.TrangThai == "CHO_HOAN_TRA";
        var devices = await db.ChiTietHopDong.Where(d => d.MaHopDong == s.Contract.MaHopDong)
            .Join(db.ThietBi, d => d.MaThietBi, t => t.MaThietBi, (d, t) => new { d, t })
            .Join(db.DongMay, x => x.t.MaDongMay, m => m.MaDongMay, (x, m) => new { x.d, x.t.SoSerial, m.TenDongMay }).ToListAsync(ct);
        var detailIds = s.Details.Select(d => d.MaChiTietHopDong).ToArray();
        var reviewedIds = customer && s.Contract.TrangThai=="HOAN_THANH"
            ? await db.DanhGia.Where(r=>detailIds.Contains(r.MaChiTietHopDong)).Select(r=>r.MaChiTietHopDong).ToListAsync(ct) : [];
        var images = await db.AnhBienBan.Where(a => detailIds.Contains(a.MaChiTietHopDong) && a.Loai == "NHAN_LAI").ToListAsync(ct);
        object? receipt = s.Receipt is null ? null : new ReturnReceipt(1, s.Receipt.ThucNhanLuc, s.Receipt.GhiNhanLucUtc,
            s.Receipt.NguoiGhiNhan, s.Receipt.KiemTraLucUtc, devices.Select(x => new ReturnInspectionItem(
                x.d.MaChiTietHopDong, x.SoSerial, x.TenDongMay, x.d.TinhTrangLucNhan ?? "Chưa ghi nhận tình trạng",
                x.d.CoHuHong, x.d.ThieuPhuKien == true, x.d.TinhTrangPhuKien is null ? [] :
                [new ReturnAccessory("Phụ kiện đã đối chiếu", null, null, x.d.TinhTrangPhuKien)],
                images.FirstOrDefault(a => a.MaChiTietHopDong == x.d.MaChiTietHopDong)?.DuongDanAnh, x.d.KetQuaKiemTra)).ToArray(),
            devices.Where(x => x.d.LoaiNgoaiLeNhanTra != null).Select(x => new ReturnException(x.d.MaChiTietHopDong,
                x.SoSerial, x.d.LoaiNgoaiLeNhanTra!, x.d.LyDoNgoaiLeNhanTra ?? "", s.Receipt.NguoiGhiNhan, s.Receipt.GhiNhanLucUtc)).ToArray());
        var chargeRows = s.Lines.Where(l => l.LoaiDong == "NGHIA_VU").ToList();
        object[] charges = q is null ? (quote?.NghiaVu.Cast<object>().ToArray() ?? []) : chargeRows.Select(l => (object)new {
            l.Id, loai = l.LoaiNghiaVu, l.MoTa, l.SoTien, nguonId = l.MaPhuLuc ?? l.MaPhieuPhat ?? l.MaChiTietHopDong ?? s.Contract.MaHopDong,
            l.MaChiTietHopDong, l.DonGia, l.SoNgay, q.HanTraHieuLuc, thucNhanLuc = s.Receipt?.ThucNhanLuc }).ToArray();
        object[] allocations = q is null ? (quote?.PhanBo.Cast<object>().ToArray() ?? []) : s.Lines.Where(l => l.LoaiDong == "PHAN_BO")
            .Select(l => (object)new { maThanhToanNguon = l.MaThanhToan, maKhoan = l.MaNghiaVu, l.SoTien }).ToArray();
        var sources = s.Payments.Where(p => p.TrangThai == "THANH_CONG" && !p.LoaiThanhToan.StartsWith("HOAN_")).ToList();
        return new {
            schemaVersion = 3, s.Contract.MaHopDong, trangThaiHopDong = s.Contract.TrangThai,
            trangThaiQuyetToan = q is null ? "DU_KIEN" : "DA_CHOT", maQuyetToan = q?.Id, phienBan = q?.PhienBan,
            maBamQuyetToan = q?.MaBam, maBienBan = s.Receipt?.Id, trangThaiNhanTra = s.Contract.TrangThaiNhanTra, nhanTra = receipt, nghiaVu = charges, phanBo = allocations,
            hanTraHieuLuc = q?.HanTraHieuLuc ?? quote?.HanTraHieuLuc,
            nguonThu = sources.Select(p => new { p.MaThanhToan, p.LoaiThanhToan, p.PhuongThuc, p.NhaCungCap, p.SoTien, p.TrangThai, p.ThoiGian, p.MaThamChieu, p.MaGiaoDich }),
            thanhToan = s.Payments.Where(p => q != null && p.MaQuyetToan == q.Id).Select(p => new {
                p.MaThanhToan, p.MaHopDong, p.LoaiThanhToan, p.PhuongThuc, p.NhaCungCap, p.SoTien, p.TrangThai, p.ThoiGian, p.MaThamChieu, p.MaGiaoDich,
                khachNhanHoanLucUtc = p.KhachXacNhanNhanHoanLucUtc, p.XacNhanHoanLucUtc, maBamKhoanHoan = RefundWorkflow.Hash(p) }),
            phanHoi = Array.Empty<object>(), phanHoiDuocHoTro = false,
            anhNhanTra = images.Select(a => new { a.MaAnhBienBan, a.MaChiTietHopDong, a.DuongDanAnh, a.MoTa, a.ThoiGianChup }),
            khachXacNhanHoanTatLucUtc = q?.KhachXacNhanHoanTatLucUtc,
            tongNghiaVu = q?.TongNghiaVu ?? quote?.TongNghiaVu, thuePhiDaThu = q is null ? quote?.ThuePhiDaThu : q.ThuePhiDaThu + collected,
            cocDaThu = q?.CocDaThu ?? quote?.CocDaThu, cocKhauTru = q?.CocKhauTru ?? quote?.CocKhauTru,
            conPhaiThu = remaining, tongDuocHoan = refundable ?? (quote is null ? null : (decimal?)(quote.TongDuocHoanCoc + quote.TongDuocHoanKhac)),
            daGhiHoan = recorded, conPhaiHoan = refundable is null ? (decimal?)null : Math.Max(0, refundable.Value - recorded!.Value),
            duLieuCanDoiSoat = mismatch, lyDoChan = blockers.Distinct().ToArray(), vnpaySanSang = gatewayReady,
            hanhDong = new { phanHoi = false, thanhToan = canAct && remaining > 0 && gatewayReady,
                dongYQuyetToan = canAct && refundable == 0 && q!.KhachXacNhanHoanTatLucUtc == null && remaining == 0 && blockers.Count == 0 && !s.Payments.Any(p=>p.TrangThai=="CHO_THANH_TOAN"),
                khoanHoanDuocXacNhan = canAct ? ackIds : [] },
            // Existing aggregate names remain available to older read-only clients.
            tienThue = q?.TienThue ?? s.Contract.TongTien, phiGiaHan = q?.PhiGiaHan,
            tienPhat = q is null ? null : (decimal?)(q.PhiTraTre + q.BoiThuong), tienCocDaThu = q?.CocDaThu,
            khoanKhacDaThu = q is null ? null : (decimal?)(q.ThuePhiDaThu + collected), tongPhaiTra = q?.TongNghiaVu,
            tienConPhaiThu = remaining, tienHoanCoc = q?.HoanCocBanDau, phiTraTre = q?.PhiTraTre,
            laDuKien = q is null, hoanThanhLucUtc = q?.HoanThanhLucUtc,
            thietBiDuocDanhGia = customer && s.Contract.TrangThai=="HOAN_THANH"
                ? detailIds.Except(reviewedIds).ToArray() : Array.Empty<string>()
        };
    }
}
