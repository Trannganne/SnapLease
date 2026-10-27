using System.Data;
using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Contracts;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;
using RentalCamera.Api.Settlement;

namespace RentalCamera.Api.Payments;

public static class RefundWorkflow
{
    public static bool IsRefund(string type) => type is "HOAN_COC" or "HOAN_TIEN_THUE" or "HOAN_THU_THUA";
    public static string Hash(ThanhToan p) => SettlementJson.Hash(SettlementJson.Write(new {
        p.MaThanhToan, p.MaHopDong, p.SoTien, p.LoaiThanhToan, p.MaQuyetToan, p.MaDoiSoatHuyHopDong }));
    public static async Task<bool> ExcessResolvedAsync(string contractId, RentalCameraContext db, CancellationToken ct)
    {
        var ids = await db.ThanhToan.Where(x => x.MaHopDong == contractId).Select(x => x.MaThanhToan).ToListAsync(ct);
        var amount = await db.YeuCauThanhToanVnpay.Where(x => ids.Contains(x.MaThanhToan) && x.LaThuThua && x.TrangThai == "THANH_CONG").SumAsync(x => (decimal?)x.SoTien, ct) ?? 0;
        var refunds = await db.ThanhToan.Where(x => x.MaHopDong == contractId && x.LoaiThanhToan == "HOAN_THU_THUA" && x.TrangThai != "THAT_BAI").ToListAsync(ct);
        return refunds.All(x => x.TrangThai == "DA_HOAN" && x.KhachXacNhanNhanHoanLucUtc != null) && refunds.Sum(x => x.SoTien) == amount;
    }
    public static void MapRefundEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/hop-dong/{id}/khoan-hoan", async (string id, ClaimsPrincipal p, RentalCameraContext db, CancellationToken ct) => {
            if (!await ApiAccess.CanAccessContractAsync(id, p, db, ct)) return Results.Forbid();
            var rows = await db.ThanhToan.AsNoTracking().Where(x => x.MaHopDong == id && x.LoaiThanhToan.StartsWith("HOAN_")).ToListAsync(ct);
            return Results.Ok(rows.Select(x => new { x.MaThanhToan, x.MaHopDong, x.SoTien, x.LoaiThanhToan, x.PhuongThuc, x.TrangThai,
                x.MaQuyetToan, x.MaDoiSoatHuyHopDong, x.XacNhanHoanLucUtc, x.KhachXacNhanNhanHoanLucUtc,
                maBamKhoanHoan = Hash(x) }));
        }).RequireAuthorization();
        app.MapPut("/api/thanh-toan/{id}/xac-nhan-hoan", (string id, RefundConfirmation r, ClaimsPrincipal p, RentalCameraContext db, CancellationToken ct) =>
            ConfirmAsync(id, r, false, p, db, ct)).RequireAuthorization("Staff");
        app.MapPut("/api/thanh-toan/{id}/xac-nhan-hoan-huy", (string id, RefundConfirmation r, ClaimsPrincipal p, RentalCameraContext db, CancellationToken ct) =>
            ConfirmAsync(id, r, false, p, db, ct)).RequireAuthorization("Staff");
        app.MapPost("/api/thanh-toan/{id}/xac-nhan-nhan-hoan", (string id, RefundConfirmation r, ClaimsPrincipal p, RentalCameraContext db, CancellationToken ct) =>
            ConfirmAsync(id, r, true, p, db, ct)).RequireAuthorization("Customer");
        app.MapPost("/api/hop-dong/{id}/hoan-thu-thua", async (string id, ExcessRefundRequest r, ClaimsPrincipal p, RentalCameraContext db, CancellationToken ct) => {
            var scope = await ApiAccess.StaffScopeAsync(p, db, ct); if (scope == null) return Results.Forbid();
            if (!ContractOperation.Valid(r.OperationId) || r.PhuongThuc is not ("TIEN_MAT" or "CHUYEN_KHOAN")) return Results.BadRequest();
            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
            await TransactionLock.AcquireAsync(db, "contract:" + id, ct);
            var h = await db.HopDong.SingleOrDefaultAsync(x => x.MaHopDong == id, ct); if (h == null) return Results.NotFound();
            if (!scope.IsAdmin && scope.StoreId != h.MaCuaHang) return Results.Forbid();
            if (RentalPolicy.ProtectedContracts.Contains(id)) return Results.Conflict();
            var hash = ContractOperation.Hash(id, ApiAccess.AccountId(p)!, r);
            try {
                if (await ContractOperation.ReplayAsync(db, h, "EXCESS_REFUND", r.OperationId, hash, ct)) return Results.Ok(new { doiSoat = true });
                var payments = await db.ThanhToan.Where(x => x.MaHopDong == id).ToListAsync(ct);
                var ids = payments.Select(x => x.MaThanhToan).ToArray();
                var amount = await db.YeuCauThanhToanVnpay.Where(x => ids.Contains(x.MaThanhToan) && x.LaThuThua && x.TrangThai == "THANH_CONG").SumAsync(x => (decimal?)x.SoTien, ct) ?? 0;
                amount -= payments.Where(x => x.LoaiThanhToan == "HOAN_THU_THUA" && x.TrangThai is "CHO_THANH_TOAN" or "DA_HOAN" or "THANH_CONG").Sum(x => x.SoTien);
                var ds = await db.DoiSoatHuyHopDong.SingleOrDefaultAsync(x => x.MaHopDong == id, ct);
                if (h.TrangThai == "DA_HUY" && ds == null) return Results.Conflict(new { code = "CANCELLATION_RECONCILIATION_REQUIRED" });
                if (amount > 0) db.ThanhToan.Add(new() { MaThanhToan = ApiAccess.NewId("TT"), MaHopDong = id,
                    LoaiThanhToan = "HOAN_THU_THUA", SoTien = amount, PhuongThuc = r.PhuongThuc,
                    TrangThai = "CHO_THANH_TOAN", MaDoiSoatHuyHopDong = ds?.MaHopDong });
                ContractOperation.Record(db, h, "EXCESS_REFUND", r.OperationId, hash);
                await db.SaveChangesAsync(ct); await tx.CommitAsync(ct); return Results.Ok(new { soTienTaoMoi = Math.Max(0, amount) });
            } catch (InvalidOperationException e) { return Results.Conflict(new { loi = e.Message }); }
        }).RequireAuthorization("Staff");
    }
    private static async Task<IResult> ConfirmAsync(string id, RefundConfirmation r, bool customer, ClaimsPrincipal p, RentalCameraContext db, CancellationToken ct)
    {
        if (!ContractOperation.Valid(r.OperationId)) return Results.BadRequest();
        var scope = customer ? null : await ApiAccess.StaffScopeAsync(p, db, ct);
        if (customer ? !p.IsInRole("KHACH_HANG") : scope == null) return Results.Forbid();
        var parent = await db.ThanhToan.AsNoTracking().Where(x => x.MaThanhToan == id).Select(x => x.MaHopDong).SingleOrDefaultAsync(ct);
        if (parent == null) return Results.NotFound();
        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        await TransactionLock.AcquireAsync(db, "contract:" + parent, ct);
        var h = await db.HopDong.SingleAsync(x => x.MaHopDong == parent, ct);
        if (customer ? await ApiAccess.CustomerIdAsync(p, db, ct) != h.MaKhachThue : !scope!.IsAdmin && scope.StoreId != h.MaCuaHang) return Results.Forbid();
        if (RentalPolicy.ProtectedContracts.Contains(parent)) return Results.Conflict();
        var row = await db.ThanhToan.SingleAsync(x => x.MaThanhToan == id, ct);
        if (!IsRefund(row.LoaiThanhToan)) return Results.Conflict();
        var op = customer ? "REFUND_OWNER_ACK" : "REFUND_STAFF_CONFIRM";
        var actor = ApiAccess.AccountId(p)!; var hash = ContractOperation.Hash(parent, actor, r, id);
        try {
            if (await ContractOperation.ReplayAsync(db, h, op, r.OperationId, hash, ct)) return Results.Ok(new { row.MaThanhToan, row.TrangThai, doiSoat = true });
            if (customer) {
                if (row.TrangThai != "DA_HOAN" || row.XacNhanHoanLucUtc == null || r.SoTienXacNhan != row.SoTien || r.MaBamKhoanHoan != Hash(row))
                    return Results.Conflict(new { code = "REFUND_NOT_RECORDED_OR_CHANGED" });
                row.KhachXacNhanNhanHoanLucUtc ??= DateTime.UtcNow; row.NguoiXacNhanNhanHoan ??= actor;
            } else {
                if (row.TrangThai != "DA_HOAN") {
                    if (row.TrangThai != "CHO_THANH_TOAN" || row.PhuongThuc is not ("TIEN_MAT" or "CHUYEN_KHOAN")) return Results.Conflict();
                    if (row.MaDoiSoatHuyHopDong != null && h.TrangThai != "DA_HUY") return Results.Conflict();
                    if (row.MaQuyetToan != null) {
                        var s = await SettlementWorkflow.LoadAsync(parent, db, ct);
                        if (s?.Final == null || s.Contract.TrangThai != "CHO_HOAN_TRA" || SettlementWorkflow.FinancialMismatch(s) ||
                            s.Final.ConPhaiThuBanDau - SettlementWorkflow.Collected(s) > 0) return Results.Conflict();
                    }
                    row.TrangThai = "DA_HOAN"; row.ThoiGian = RentalPolicy.LocalNow;
                    row.NguoiXacNhanHoan = actor; row.XacNhanHoanLucUtc = DateTime.UtcNow;
                }
            }
            ContractOperation.Record(db, h, op, r.OperationId, hash);
            await db.SaveChangesAsync(ct); await SettlementWorkflow.ReconcileAsync(parent, db, ct);
            await tx.CommitAsync(ct); return Results.Ok(new { row.MaThanhToan, row.TrangThai, row.XacNhanHoanLucUtc, row.KhachXacNhanNhanHoanLucUtc });
        } catch (InvalidOperationException e) { return Results.Conflict(new { code = "REFUND_CONFLICT", loi = e.Message }); }
    }
}
public sealed record RefundConfirmation(string OperationId, decimal? SoTienXacNhan = null, string? MaBamKhoanHoan = null);
public sealed record ExcessRefundRequest(string OperationId, string PhuongThuc = "CHUYEN_KHOAN");
