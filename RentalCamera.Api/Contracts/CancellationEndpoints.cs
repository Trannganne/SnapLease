using System.Data;
using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Contracts;

public static class CancellationEndpoints
{
    public static void MapCancellationEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/hop-dong/{id}/huy-truoc-ban-giao", async (string id, ClaimsPrincipal p, RentalCameraContext db, CancellationToken ct) => {
            if (!await ApiAccess.CanAccessContractAsync(id, p, db, ct)) return Results.Forbid();
            return Results.Ok(new { doiSoatHuy = await db.DoiSoatHuyHopDong.AsNoTracking().SingleOrDefaultAsync(x => x.MaHopDong == id, ct),
                hoanTien = await db.ThanhToan.AsNoTracking().Where(x => x.MaHopDong == id && x.MaDoiSoatHuyHopDong != null).ToListAsync(ct) });
        }).RequireAuthorization();
        app.MapPost("/api/hop-dong/{id}/huy-truoc-ban-giao", (string id, CancellationRequest r, ClaimsPrincipal p, RentalCameraContext db, CancellationToken ct) =>
            DirectAsync(id, r, false, p, db, ct)).RequireAuthorization("Customer");
        app.MapPost("/api/hop-dong/{id}/huy-truc-tiep", (string id, CancellationRequest r, ClaimsPrincipal p, RentalCameraContext db, CancellationToken ct) =>
            DirectAsync(id, r, true, p, db, ct)).RequireAuthorization("Staff");
        app.MapPost("/api/hop-dong/{id}/doi-soat-huy", async (string id, ClaimsPrincipal p, RentalCameraContext db, CancellationToken ct) => {
            var scope = await ApiAccess.StaffScopeAsync(p, db, ct); if (scope == null) return Results.Forbid();
            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
            await TransactionLock.AcquireAsync(db, "contract:" + id, ct);
            var h = await db.HopDong.SingleOrDefaultAsync(x => x.MaHopDong == id, ct); if (h == null) return Results.NotFound();
            if (!scope.IsAdmin && scope.StoreId != h.MaCuaHang) return Results.Forbid();
            var row = await db.DoiSoatHuyHopDong.SingleOrDefaultAsync(x => x.MaHopDong == id, ct);
            if (row == null || h.TrangThai != "DA_HUY" || RentalPolicy.ProtectedContracts.Contains(id)) return Results.Conflict();
            await ReconcileAsync(row, db, ct, true); await db.SaveChangesAsync(ct); await tx.CommitAsync(ct); return Results.Ok(row);
        }).RequireAuthorization("Staff");
        app.MapGet("/api/yeu-cau-huy/cho-duyet", () => Results.Json(new { code = "CANCELLATION_QUEUE_REMOVED" }, statusCode: 410)).RequireAuthorization("Staff");
        app.MapPut("/api/yeu-cau-huy/{id}/xu-ly", () => Results.Json(new { code = "USE_DIRECT_CANCELLATION" }, statusCode: 410)).RequireAuthorization("Staff");
    }
    private static async Task<IResult> DirectAsync(string id, CancellationRequest r, bool staff, ClaimsPrincipal p, RentalCameraContext db, CancellationToken ct)
    {
        if (!ContractOperation.Valid(r.OperationId) || string.IsNullOrWhiteSpace(r.LyDo) || r.LyDo.Length > 500 ||
            r.LyDoNgoaiLe?.Length > 500 || r.TaiLieuUrl?.Length > 500) return Results.BadRequest();
        var scope = staff ? await ApiAccess.StaffScopeAsync(p, db, ct) : null;
        if (staff ? scope == null : !p.IsInRole("KHACH_HANG")) return Results.Forbid();
        var actor = ApiAccess.AccountId(p)!;
        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        await TransactionLock.AcquireAsync(db, "contract:" + id, ct);
        var h = await db.HopDong.SingleOrDefaultAsync(x => x.MaHopDong == id, ct); if (h == null) return Results.NotFound();
        if (staff ? !scope!.IsAdmin && scope.StoreId != h.MaCuaHang : await ApiAccess.CustomerIdAsync(p, db, ct) != h.MaKhachThue) return Results.Forbid();
        if (!staff && (r.CanCuNgoaiLe != null || r.LyDoNgoaiLe != null || r.TaiLieuUrl != null)) return Results.BadRequest();
        if (staff && r.CanCuNgoaiLe is not ("BAT_KHA_KHANG" or "LOI_CUA_HANG")) return Results.BadRequest(new { code = "EXCEPTION_BASIS_REQUIRED" });
        if (r.CanCuNgoaiLe == "BAT_KHA_KHANG" && !scope!.IsAdmin) return Results.Forbid();
        if (staff && string.IsNullOrWhiteSpace(r.LyDoNgoaiLe)) return Results.BadRequest();
        var hash = ContractOperation.Hash(id, actor, r);
        try {
            if (await ContractOperation.ReplayAsync(db, h, "CANCEL_DIRECT", r.OperationId!, hash, ct))
                return Results.Ok(new { h.MaHopDong, h.TrangThai, doiSoat = true });
            if (!await EligibleAsync(h, db, ct)) return Results.Conflict(new { code = "CANCELLATION_NOT_ELIGIBLE" });
            var row = await CancelAsync(h, actor, staff ? scope!.IsAdmin ? "ADMIN" : "NHAN_VIEN" : "KHACH_HANG",
                staff && r.CanCuNgoaiLe == "LOI_CUA_HANG" ? "CUA_HANG_HUY" : "KHACH_HUY", r.LyDo.Trim(),
                r.CanCuNgoaiLe, r.LyDoNgoaiLe, r.TaiLieuUrl, db, ct);
            ContractOperation.Record(db, h, "CANCEL_DIRECT", r.OperationId!, hash);
            await db.SaveChangesAsync(ct); await tx.CommitAsync(ct); return Results.Ok(new { h.MaHopDong, h.TrangThai, doiSoatHuy = row });
        } catch (InvalidOperationException e) { return Results.Conflict(new { code = "CANCELLATION_CONFLICT", loi = e.Message }); }
    }
    internal static async Task<bool> EligibleAsync(HopDong h, RentalCameraContext db, CancellationToken ct) =>
        !RentalPolicy.ProtectedContracts.Contains(h.MaHopDong) && h.TrangThai is "DA_KY" or "CHO_BAN_GIAO" &&
        h.DaDongYDieuKhoan && h.PhienBanDieuKhoan == RentalPolicy.TermsVersion &&
        !await db.ChiTietHopDong.AnyAsync(d => d.MaHopDong == h.MaHopDong && d.NgayGiaoThucTe != null, ct);

    // Caller holds the contract transaction/lock and has checked scope and current eligibility.
    internal static async Task<DoiSoatHuyHopDong> CancelAsync(HopDong h, string actor, string actorType, string cause, string reason,
        string? basis, string? exceptionReason, string? evidence, RentalCameraContext db, CancellationToken ct)
    {
        if (await db.DoiSoatHuyHopDong.AnyAsync(x => x.MaHopDong == h.MaHopDong, ct)) throw new InvalidOperationException("Đã có hồ sơ hủy.");
        var now = DateTime.UtcNow;
        var row = new DoiSoatHuyHopDong { MaHopDong = h.MaHopDong, HuyLucUtc = now, DoiSoatHuyLucUtc = now,
            NguoiHuy = actor, LoaiTacNhanHuy = actorType, LoaiHuy = cause, LyDoHuy = reason,
            TyLeKhauTruHuy = basis != null ? 0 : RentalPolicy.CancellationRate(h.ThoiGianBanGiao, RentalPolicy.LocalNow),
            CanCuNgoaiLeHuy = basis, LyDoNgoaiLeHuy = exceptionReason?.Trim(), TaiLieuNgoaiLeHuyUrl = evidence };
        db.DoiSoatHuyHopDong.Add(row); h.TrangThai = "DA_HUY";
        var ids = await db.ChiTietHopDong.Where(x => x.MaHopDong == h.MaHopDong).Select(x => x.MaThietBi).ToListAsync(ct);
        var devices = await db.ThietBi.Where(x => ids.Contains(x.MaThietBi) && x.TrangThai == "DANG_GIU").ToListAsync(ct);
        foreach (var d in devices) d.TrangThai = "SAN_SANG";
        await ReconcileAsync(row, db, ct, true); return row;
    }
    public static async Task ReconcileAsync(DoiSoatHuyHopDong row, RentalCameraContext db, CancellationToken ct, bool createRefund)
    {
        var payments = await db.ThanhToan.Where(x => x.MaHopDong == row.MaHopDong).ToListAsync(ct);
        payments.AddRange(db.ThanhToan.Local.Where(x => x.MaHopDong == row.MaHopDong && !payments.Contains(x)));
        var ids = payments.Where(p => !p.LoaiThanhToan.StartsWith("HOAN_")).Select(p => p.MaThanhToan).ToArray();
        var attempts = await db.YeuCauThanhToanVnpay.Where(a => ids.Contains(a.MaThanhToan)).ToListAsync(ct);
        var deposit = payments.Where(p => p.LoaiThanhToan == "TIEN_COC" && p.TrangThai == "THANH_CONG").Sum(p => p.SoTien);
        var rent = payments.Where(p => p.LoaiThanhToan == "TIEN_THUE" && p.TrangThai == "THANH_CONG").Sum(p => p.SoTien);
        var excess = attempts.Where(a => a.LaThuThua && a.TrangThai == "THANH_CONG").Sum(a => a.SoTien);
        if (row.LoaiHuy == "HET_HAN_KY" && deposit + rent + excess != 0) throw new InvalidOperationException("Hợp đồng chưa ký có tiền bất thường; cần đối soát riêng.");
        var a = Amounts(deposit, rent, excess, row.TyLeKhauTruHuy, false);
        row.TienCocDaThuKhiHuy = deposit; row.TienThueDaThuKhiHuy = rent; row.TienThuThuaDaThuKhiHuy = excess;
        row.TienKhauTruHuy = a.Deduction; row.TienCocPhaiHoanKhiHuy = a.DepositRefund;
        row.TienThuePhaiHoanKhiHuy = a.RentRefund; row.TienThuThuaPhaiHoanKhiHuy = a.ExcessRefund; row.DoiSoatHuyLucUtc = DateTime.UtcNow;
        if (!createRefund) return;
        foreach (var part in new[] { (Type: "HOAN_COC", Amount: a.DepositRefund), (Type: "HOAN_TIEN_THUE", Amount: a.RentRefund), (Type: "HOAN_THU_THUA", Amount: a.ExcessRefund) }) {
            var reserved = payments.Where(p => p.LoaiThanhToan == part.Type && p.TrangThai is "CHO_THANH_TOAN" or "DA_HOAN" or "THANH_CONG").Sum(p => p.SoTien);
            var amount = Math.Max(0, part.Amount - reserved); if (amount == 0) continue;
            db.ThanhToan.Add(new() { MaThanhToan = ApiAccess.NewId("TT"), MaHopDong = row.MaHopDong,
                MaDoiSoatHuyHopDong = row.MaHopDong, LoaiThanhToan = part.Type, SoTien = amount,
                PhuongThuc = "CHUYEN_KHOAN", TrangThai = "CHO_THANH_TOAN" });
        }
    }
    public static (decimal Deduction, decimal DepositRefund, decimal RentRefund, decimal ExcessRefund) Amounts(
        decimal validDeposit, decimal prepaidRent, decimal excess, decimal rate, bool exception)
    {
        var deduction = Math.Round(validDeposit * (exception ? 0 : rate), 2);
        return (deduction, validDeposit - deduction, prepaidRent, excess);
    }
}
public sealed record CancellationRequest(string LyDo, string? OperationId = null, string? CanCuNgoaiLe = null, string? LyDoNgoaiLe = null, string? TaiLieuUrl = null);
