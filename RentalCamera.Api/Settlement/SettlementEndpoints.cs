using System.Data;
using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using RentalCamera.Api.Contracts;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;
using RentalCamera.Api.Payments;

namespace RentalCamera.Api.Settlement;

public static class SettlementEndpoints
{
    public static void MapSettlementEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/hop-dong").RequireAuthorization();
        group.MapGet("/{id}/quyet-toan/thao-tac/{operationId}", async (string id, string operationId, string loai,
            ClaimsPrincipal p, RentalCameraContext db, CancellationToken ct) => {
            if (loai is not ("QT_KHACH" or "QT_THU") || operationId.Length > 100) return Results.BadRequest();
            if (!await ApiAccess.CanAccessContractAsync(id, p, db, ct)) return Results.Forbid();
            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
            await TransactionLock.AcquireAsync(db, "contract:" + id, ct);
            var h = await db.HopDong.SingleOrDefaultAsync(x=>x.MaHopDong==id,ct);
            if(h is null)return Results.NotFound();
            var row = await db.IdempotencyKey.SingleOrDefaultAsync(k=>k.IdempotencyKey==operationId&&k.MaKhachThue==h.MaKhachThue&&k.LoaiThaoTac==loai,ct);
            var matches = row != null && (row.MaThucThe==id || await db.ThanhToan.AnyAsync(t=>t.MaThanhToan==row.MaThucThe&&t.MaHopDong==id,ct));
            return Results.Ok(new {maHopDong=id, daGhiNhan=matches, maThanhToan=matches&&loai=="QT_THU"?row!.MaThucThe:null});
        });
        group.MapGet("/{id}/quyet-toan", async (string id, ClaimsPrincipal p, RentalCameraContext db,
            VnpayService gateway, IOptions<VnpayOptions> options, CancellationToken ct) => {
            if (!await ApiAccess.CanAccessContractAsync(id, p, db, ct)) return Results.Forbid();
            var s = await SettlementWorkflow.LoadAsync(id, db, ct);
            return s is null ? Results.NotFound() : Results.Ok(await SettlementViewService.ViewAsync(s, p,
                SettlementViewService.SandboxReady(gateway, options.Value), db, ct));
        });
        group.MapPost("/{id}/quyet-toan/chot", (string id, SettlementRequest r, ClaimsPrincipal p, RentalCameraContext db, CancellationToken ct) =>
            Write(id, r, "QT_CHOT", false, p, db, ct, async (s, actor) => {
                await SettlementWorkflow.FinalizeAsync(s, actor, db, ct); return null;
            })).RequireAuthorization("Staff");

        group.MapPost("/{id}/quyet-toan/thu-them", async (string id, SettlementCollectionRequest r, ClaimsPrincipal p,
            RentalCameraContext db, VnpayService gateway, IOptions<VnpayOptions> options, CancellationToken ct) => {
            if (r.PhuongThuc != "VI_DIEN_TU") return Results.BadRequest(new{loi="Khoản cần trả thêm dùng một lượt VNPAY Sandbox; không đổi sang tiền mặt."});
            if (!SettlementViewService.SandboxReady(gateway, options.Value))
                return Results.Problem(title: "VNPAY Sandbox chưa sẵn sàng.", statusCode: 503);
            return await Write(id, r, "QT_THU", true, p, db, ct, (s, actor) => {
                var q = NeedFinal(s, r.MaBamQuyetToan);
                var existing = s.Payments.FirstOrDefault(x => x.MaQuyetToan == q.Id && x.LoaiThanhToan == "THU_QUYET_TOAN" && x.TrangThai == "CHO_THANH_TOAN");
                if (existing != null) {
                    if (existing.PhuongThuc != r.PhuongThuc) throw new InvalidOperationException("Đã có khoản thu chờ theo phương thức khác; cần đối soát trước.");
                    return Task.FromResult<object?>(existing);
                }
                var amount = q.ConPhaiThuBanDau - SettlementWorkflow.Collected(s);
                if (amount <= 0) throw new InvalidOperationException("Không còn khoản cần thu thêm.");
                var row = new ThanhToan { MaThanhToan = ApiAccess.NewId("TT"), MaHopDong = id, MaQuyetToan = q.Id,
                    LoaiThanhToan = "THU_QUYET_TOAN", SoTien = amount, PhuongThuc = r.PhuongThuc,
                    TrangThai = "CHO_THANH_TOAN", NhaCungCap = "VNPAY" };
                db.ThanhToan.Add(row); return Task.FromResult<object?>(row);
            });
        }).RequireAuthorization("Customer");

        group.MapPost("/{id}/hoan-coc", (string id, SettlementRefundRequest r, ClaimsPrincipal p, RentalCameraContext db, CancellationToken ct) =>
            Write(id, r, "QT_TAO_HOAN", false, p, db, ct, (s, actor) => {
                var q = NeedFinal(s, r.MaBamQuyetToan);
                if (r.LoaiThanhToan is not ("HOAN_COC" or "HOAN_TIEN_THUE") || r.PhuongThuc is not ("TIEN_MAT" or "CHUYEN_KHOAN"))
                    throw new InvalidOperationException("Loại hoặc phương thức hoàn không hợp lệ; không hoàn tự động qua VNPAY.");
                if (q.ConPhaiThuBanDau - SettlementWorkflow.Collected(s) > 0) throw new InvalidOperationException("Còn khoản phải thu, chưa tạo hoàn.");
                var existing = s.Payments.FirstOrDefault(x => x.MaQuyetToan == q.Id && x.LoaiThanhToan == r.LoaiThanhToan && x.TrangThai == "CHO_THANH_TOAN");
                if (existing != null) return Task.FromResult<object?>(existing);
                var amount = (r.LoaiThanhToan == "HOAN_COC" ? q.HoanCocBanDau : q.HoanKhacBanDau) - SettlementWorkflow.Refunded(s, r.LoaiThanhToan);
                if (amount <= 0) throw new InvalidOperationException("Không còn khoản phải hoàn; không tạo hoàn bằng 0.");
                var payment = new ThanhToan { MaThanhToan = ApiAccess.NewId("TT"), MaHopDong = id, MaQuyetToan = q.Id,
                    SoTien = amount, LoaiThanhToan = r.LoaiThanhToan, PhuongThuc = r.PhuongThuc, TrangThai = "CHO_THANH_TOAN" };
                db.ThanhToan.Add(payment); return Task.FromResult<object?>(payment);
            })).RequireAuthorization("Staff");

        group.MapPost("/{id}/quyet-toan/xac-nhan-hoan-tat", (string id, SettlementRequest r, ClaimsPrincipal p, RentalCameraContext db, CancellationToken ct) =>
            Write(id, r, "QT_KHACH", true, p, db, ct, (s, actor) => {
                ConfirmNoRefund(s, r.MaBamQuyetToan, actor); return Task.FromResult<object?>(null);
            })).RequireAuthorization("Customer");
        // Compatibility adapter for the two retained customer actions. Feedback itself is removed.
        group.MapPost("/{id}/quyet-toan/phan-hoi", (string id, CustomerSettlementRequest r, ClaimsPrincipal p, RentalCameraContext db, CancellationToken ct) =>
            Write(id, r, "QT_KHACH", true, p, db, ct, (s, actor) => {
                var q = NeedFinal(s, r.MaBamQuyetToan);
                if (r.Loai == "DONG_Y_QUYET_TOAN") ConfirmNoRefund(s, r.MaBamQuyetToan, actor);
                else if (r.Loai == "DA_NHAN_HOAN") {
                    var row = s.Payments.SingleOrDefault(x=>x.MaThanhToan==r.MaThanhToan && x.MaQuyetToan==q.Id);
                    if (row == null || !RentalCamera.Api.Payments.RefundWorkflow.IsRefund(row.LoaiThanhToan) || row.TrangThai!="DA_HOAN" ||
                        row.XacNhanHoanLucUtc==null || r.SoTienXacNhan!=row.SoTien) throw new InvalidOperationException("Khoản hoàn hoặc số tiền đã xem không khớp.");
                    row.NguoiXacNhanNhanHoan ??= actor; row.KhachXacNhanNhanHoanLucUtc ??= DateTime.UtcNow;
                } else throw new InvalidOperationException("Phản hồi quyết toán đã bỏ; liên hệ cửa hàng. Chỉ giữ xác nhận khoản hoàn hoặc hoàn tất.");
                return Task.FromResult<object?>(null);
            })).RequireAuthorization("Customer");
        group.MapPut("/{id}/quyet-toan/phan-hoi/{feedbackId}/xu-ly", () => Results.Json(new { code="SETTLEMENT_FEEDBACK_REMOVED" },statusCode:410)).RequireAuthorization("Staff");
    }

    private static void ConfirmNoRefund(SettlementWorkflow.State s, string? hash, string actor)
    {
        var q = NeedFinal(s, hash);
        if (q.HoanCocBanDau+q.HoanKhacBanDau!=0 || q.ConPhaiThuBanDau-SettlementWorkflow.Collected(s)>0 ||
            SettlementWorkflow.Blockers(s).Count!=0 || s.Receipt?.ThucNhanLuc==null || s.Receipt.KiemTraLucUtc==null ||
            s.Payments.Any(x=>x.TrangThai=="CHO_THANH_TOAN")) throw new InvalidOperationException("Chưa đủ điều kiện khách xác nhận hoàn tất.");
        q.KhachXacNhanHoanTatLucUtc ??= DateTime.UtcNow; q.NguoiXacNhanHoanTat ??= actor;
    }

    private static QuyetToanHopDong NeedFinal(SettlementWorkflow.State s, string? hash)
    {
        if (s.Final is null || hash != s.Final.MaBam || s.Contract.TrangThai is not ("CHO_HOAN_TRA" or "HOAN_THANH") || SettlementWorkflow.FinancialMismatch(s))
            throw new InvalidOperationException("Quyết toán chưa sẵn sàng, đã hoàn tất hoặc dữ liệu không khớp; tải lại để đối soát.");
        return s.Final;
    }

    private static async Task<IResult> Write(string id, ISettlementRequest request, string operation, bool customer,
        ClaimsPrincipal p, RentalCameraContext db, CancellationToken ct, Func<SettlementWorkflow.State, string, Task<object?>> action, string? targetId = null)
    {
        var actor = ApiAccess.AccountId(p);
        if (actor is null) return Results.Forbid();
        if (string.IsNullOrWhiteSpace(request.OperationId) || request.OperationId.Length > 100 || RentalPolicy.ProtectedContracts.Contains(id)) return Results.Conflict();
        var staff = customer ? null : await ApiAccess.StaffScopeAsync(p, db, ct);
        if (customer ? !p.IsInRole("KHACH_HANG") : staff is null) return Results.Forbid();
        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        await TransactionLock.AcquireAsync(db, "contract:" + id, ct);
        var s = await SettlementWorkflow.LoadAsync(id, db, ct);
        if (s is null) return Results.NotFound();
        if (customer ? await ApiAccess.CustomerIdAsync(p, db, ct) != s.Contract.MaKhachThue : !staff!.IsAdmin && staff.StoreId != s.Contract.MaCuaHang) return Results.Forbid();
        var payload = SettlementJson.Hash(SettlementJson.Write(new { id, targetId, actor, request = System.Text.Json.JsonSerializer.Serialize(request, request.GetType(), SettlementJson.Options) }));
        var previous = await db.IdempotencyKey.SingleOrDefaultAsync(k => k.IdempotencyKey == request.OperationId && k.MaKhachThue == s.Contract.MaKhachThue && k.LoaiThaoTac == operation, ct);
        if (previous != null) {
            if (previous.PayloadHash != payload) return Results.Conflict(new { loi = "Mã thao tác đã dùng cho nội dung hoặc người thực hiện khác." });
            if (operation == "QT_THU" && previous.MaThucThe.StartsWith("TT")) return Results.Ok(s.Payments.Single(p => p.MaThanhToan == previous.MaThucThe));
            return Results.Ok(new { doiSoat = true, s.Contract.MaHopDong });
        }
        try {
            var result = await action(s, actor);
            await db.SaveChangesAsync(ct);
            db.IdempotencyKey.Add(new() { IdempotencyKey = request.OperationId, MaKhachThue = s.Contract.MaKhachThue,
                LoaiThaoTac = operation, PayloadHash = payload, MaThucThe = result is ThanhToan payment ? payment.MaThanhToan : id, NgayTao = RentalPolicy.LocalNow });

            await db.SaveChangesAsync(ct);
            await SettlementWorkflow.ReconcileAsync(id, db, ct);
            await tx.CommitAsync(ct);
            return Results.Ok(result ?? new { s.Contract.MaHopDong, doiSoat = true });
        } catch (InvalidOperationException ex) { return Results.Conflict(new { loi = ex.Message }); }
    }
}

public interface ISettlementRequest { string OperationId { get; } string? MaBamQuyetToan { get; } }
public sealed record SettlementRequest(string OperationId, string? MaBamQuyetToan = null) : ISettlementRequest;
public sealed record SettlementCollectionRequest(string OperationId, string? MaBamQuyetToan, string PhuongThuc = "VI_DIEN_TU") : ISettlementRequest;
public sealed record SettlementRefundRequest(string OperationId, string? MaBamQuyetToan, string PhuongThuc, string LoaiThanhToan = "HOAN_COC") : ISettlementRequest;
public sealed record RecordSettlementRefundRequest(string OperationId, string? MaBamQuyetToan, string? ChungTu = null, string? MaGiaoDich = null) : ISettlementRequest;
public sealed record CustomerSettlementRequest(string OperationId, string? MaBamQuyetToan, string Loai,
    string? MaThanhToan = null, string? LyDo = null, string? PhanHoiId = null, decimal? SoTienXacNhan = null, DateTime? TraLoiLucUtcDaXem = null) : ISettlementRequest;
public sealed record SettlementReplyRequest(string OperationId, string? MaBamQuyetToan, string TraLoi) : ISettlementRequest;
