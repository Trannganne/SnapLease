using System.Data;
using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;
using RentalCamera.Api.Settlement;

namespace RentalCamera.Api.Contracts;

public static class NoShowEndpoints
{
    public static string? Version(XacMinhKhachKhongDen? row) => row == null ? null : SettlementJson.Hash(SettlementJson.Write(new {
        row.MaHopDong, row.NguoiXacMinh,
        xacMinhLucUtc = DateTime.SpecifyKind(row.XacMinhLucUtc, DateTimeKind.Utc),
        gioHen = DateTime.SpecifyKind(row.GioHenKhiXacMinhKhongDen, DateTimeKind.Unspecified),
        row.KhongCoLichHenMoi, row.CuaHangSanSangBanGiao, row.KhachChuaCheckIn, row.DaThuLienHe,
        lienHeLucUtc = DateTime.SpecifyKind(row.LienHeLucUtc, DateTimeKind.Utc),
        row.KenhLienHe, row.KetQuaLienHe, row.CoTranhChapKhongDen, row.GhiChuKhongDen }));
    public static void MapNoShowEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/hop-dong/can-kiem-tra-nhan", async (ClaimsPrincipal p, RentalCameraContext db, CancellationToken ct) => {
            var scope = await ApiAccess.StaffScopeAsync(p, db, ct); if (scope == null) return Results.Forbid();
            var cutoff = RentalPolicy.LocalNow.AddHours(-2);
            return Results.Ok(await db.HopDong.AsNoTracking().Where(h => (h.TrangThai == "DA_KY" || h.TrangThai == "CHO_BAN_GIAO") && h.ThoiGianBanGiao <= cutoff &&
                (scope.IsAdmin || scope.StoreId == h.MaCuaHang) && !db.ChiTietHopDong.Any(d => d.MaHopDong == h.MaHopDong && d.NgayGiaoThucTe != null))
                .Select(h => new { h.MaHopDong, h.MaCuaHang, h.ThoiGianBanGiao, canKiemTra = true, tuDongHuy = false }).ToListAsync(ct));
        }).RequireAuthorization("Staff");
        app.MapGet("/api/hop-dong/{id}/xac-minh-khong-den", async (string id, ClaimsPrincipal p, RentalCameraContext db, CancellationToken ct) => {
            var scope = await ApiAccess.StaffScopeAsync(p, db, ct); if (scope == null || !await ApiAccess.CanAccessContractAsync(id, p, db, ct)) return Results.Forbid();
            var row = await db.XacMinhKhachKhongDen.AsNoTracking().SingleOrDefaultAsync(x => x.MaHopDong == id, ct);
            return Results.Ok(new { xacMinh = row, phienBanXacMinh = Version(row) });
        }).RequireAuthorization("Staff");
        app.MapPost("/api/hop-dong/{id}/xac-nhan-khong-den", async (string id, NoShowEvidence r, ClaimsPrincipal p, RentalCameraContext db, BranchWorkingHours hours, CancellationToken ct) => {
            var scope = await ApiAccess.StaffScopeAsync(p, db, ct); if (scope == null) return Results.Forbid();
            if (!ContractOperation.Valid(r.OperationId) || string.IsNullOrWhiteSpace(r.GhiChu) || r.GhiChu.Length > 500 ||
                string.IsNullOrWhiteSpace(r.KenhLienHe) || r.KenhLienHe.Length > 100 || string.IsNullOrWhiteSpace(r.KetQuaLienHe) || r.KetQuaLienHe.Length > 500 ||
                r.LienHeLucUtc == default || r.LienHeLucUtc.Kind != DateTimeKind.Utc || r.LienHeLucUtc > DateTime.UtcNow || r.TaiLieuUrl?.Length > 500) return Results.BadRequest();
            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
            await TransactionLock.AcquireAsync(db, "contract:" + id, ct);
            var h = await db.HopDong.SingleOrDefaultAsync(x => x.MaHopDong == id, ct); if (h == null) return Results.NotFound();
            if (!scope.IsAdmin && scope.StoreId != h.MaCuaHang) return Results.Forbid();
            var row = await db.XacMinhKhachKhongDen.SingleOrDefaultAsync(x => x.MaHopDong == id, ct);
            var actor = ApiAccess.AccountId(p)!; var hash = ContractOperation.Hash(id, actor, r);
            try {
                if (await ContractOperation.ReplayAsync(db, h, "NO_SHOW_VERIFY", r.OperationId!, hash, ct))
                    return Results.Ok(new { daHuy = h.TrangThai == "DA_HUY", doiSoat = true, xacMinh = row, phienBanXacMinh = Version(row) });
                if (!await CancellationEndpoints.EligibleAsync(h, db, ct) || RentalPolicy.LocalNow < h.ThoiGianBanGiao.AddHours(2)) return Results.Conflict(new { code = "NO_SHOW_NOT_ELIGIBLE" });
                if (r.GioHenDaXacNhan != h.ThoiGianBanGiao || r.GioHenDaXacNhan.Kind != DateTimeKind.Unspecified)
                    return Results.Conflict(new { code = "APPOINTMENT_CHANGED" });
                if (Version(row) != r.PhienBanXacMinhDaXem) return Results.Conflict(new { code = "NO_SHOW_VERSION_CONFLICT" });
                if (!scope.IsAdmin && row?.CoTranhChapKhongDen == true && !r.CoTranhChap) return Results.Forbid();
                if (row == null) { row = new() { MaHopDong = id }; db.XacMinhKhachKhongDen.Add(row); }
                row.NguoiXacMinh = actor; row.XacMinhLucUtc = DateTime.UtcNow; row.GioHenKhiXacMinhKhongDen = h.ThoiGianBanGiao;
                row.KhongCoLichHenMoi = r.KhongCoLichHenMoi; row.CuaHangSanSangBanGiao = r.CuaHangSanSang; row.KhachChuaCheckIn = r.KhachChuaDen;
                row.DaThuLienHe = r.DaThuLienHe; row.LienHeLucUtc = r.LienHeLucUtc; row.KenhLienHe = r.KenhLienHe.Trim();
                row.KetQuaLienHe = r.KetQuaLienHe.Trim(); row.CoTranhChapKhongDen = r.CoTranhChap; row.GhiChuKhongDen = r.GhiChu.Trim();
                var ready = r.KhongCoLichHenMoi && r.CuaHangSanSang && r.KhachChuaDen && r.DaThuLienHe && !r.CoTranhChap &&
                    !r.DeNghiNgoaiLe && string.IsNullOrWhiteSpace(r.TaiLieuUrl) && await hours.IsOpenAsync(h.MaCuaHang, DateTime.UtcNow, ct) &&
                    await hours.IsOpenAsync(h.MaCuaHang, RentalPolicy.Utc(h.ThoiGianBanGiao), ct);
                if (ready) await CancellationEndpoints.CancelAsync(h, actor, scope.IsAdmin ? "ADMIN" : "NHAN_VIEN", "KHONG_DEN",
                    "Khách không đến nhận bàn giao thiết bị", null, null, null, db, ct);
                ContractOperation.Record(db, h, "NO_SHOW_VERIFY", r.OperationId!, hash);
                await db.SaveChangesAsync(ct); await tx.CommitAsync(ct);
                return Results.Ok(new { daHuy = ready, xacMinh = row, phienBanXacMinh = Version(row),
                    lyDoChan = ready ? null : "Chưa đủ điều kiện hoặc có tranh chấp/đề nghị ngoại lệ; người có quyền cần xác minh và xử lý trực tiếp." });
            } catch (InvalidOperationException e) { return Results.Conflict(new { code = "NO_SHOW_CONFLICT", loi = e.Message }); }
        }).RequireAuthorization("Staff");
        app.MapPost("/api/yeu-cau-huy/{id}/de-nghi-ngoai-le", () => Results.Json(new { code = "USE_ADMIN_DIRECT_CANCELLATION" }, statusCode: 410)).RequireAuthorization("Staff");
    }
}
public sealed record NoShowEvidence(DateTime GioHenDaXacNhan, bool KhongCoLichHenMoi, bool CuaHangSanSang, bool KhachChuaDen, bool DaThuLienHe,
    DateTime LienHeLucUtc, string KenhLienHe, string KetQuaLienHe, string GhiChu, string? TaiLieuUrl, bool CoTranhChap, bool DeNghiNgoaiLe,
    string? OperationId = null, string? PhienBanXacMinhDaXem = null);
