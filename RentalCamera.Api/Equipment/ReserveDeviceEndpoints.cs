using System.Data;
using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;
using RentalCamera.Api.Rental;

namespace RentalCamera.Api.Equipment;

public static class ReserveDeviceEndpoints
{
    public static void MapReserveDeviceEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost("/api/hop-dong/{contractId}/thiet-bi/{detailId}/thay-du-phong", async (
            string contractId,
            string detailId,
            ReserveDeviceSwapRequest request,
            ClaimsPrincipal principal,
            RentalCameraContext db,
            IConfiguration configuration,
            CancellationToken ct) =>
        {
            if (!ReserveDevicePolicy.IsIncidentState(request.TrangThaiThietBiCu) ||
                string.IsNullOrWhiteSpace(request.LyDo) || request.LyDo.Trim().Length > 300 ||
                string.IsNullOrWhiteSpace(request.TinhTrangThietBiCu) || request.TinhTrangThietBiCu.Trim().Length > 200)
                return Results.BadRequest(new
                {
                    loi = "Cần trạng thái máy cũ BAO_TRI/HONG, tình trạng thực tế và lý do thay máy hợp lệ."
                });

            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();

            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
            await TransactionLock.AcquireAsync(db, $"contract:{contractId}", ct);

            var contract = await db.HopDong.SingleOrDefaultAsync(x => x.MaHopDong == contractId, ct);
            if (contract is null) return Results.NotFound(new { loi = "Không tìm thấy hợp đồng." });
            if (!scope.IsAdmin && contract.MaCuaHang != scope.StoreId) return Results.Forbid();

            var detail = await db.ChiTietHopDong.SingleOrDefaultAsync(
                x => x.MaChiTietHopDong == detailId && x.MaHopDong == contractId, ct);
            if (detail is null) return Results.NotFound(new { loi = "Không tìm thấy thiết bị đã gán trong hợp đồng." });
            if (!ReserveDevicePolicy.CanSwap(contract.TrangThai, detail.NgayGiaoThucTe))
                return Results.Conflict(new
                {
                    loi = "Chỉ được thay máy dự phòng khi hợp đồng chờ bàn giao và thiết bị chưa giao thực tế."
                });

            var oldDevice = await db.ThietBi.SingleAsync(x => x.MaThietBi == detail.MaThietBi, ct);
            if (oldDevice.TrangThai is not ("DANG_GIU" or "BAO_TRI" or "HONG"))
                return Results.Conflict(new { loi = "Máy cũ không ở trạng thái cho phép thay thế." });

            await TransactionLock.AcquireAsync(db,
                $"reserve:{contract.MaCuaHang}:{oldDevice.MaDongMay}", ct);

            var reserve = await db.ThietBi.FromSqlInterpolated($"""
                SELECT TOP (1) t.*
                FROM dbo.ThietBi t WITH (UPDLOCK, HOLDLOCK, ROWLOCK)
                WHERE t.MaCuaHang = {contract.MaCuaHang}
                  AND t.MaDongMay = {oldDevice.MaDongMay}
                  AND t.TrangThai = 'DU_PHONG'
                  AND NOT EXISTS (
                      SELECT 1
                      FROM dbo.ChiTietHopDong c
                      JOIN dbo.HopDong h ON h.MaHopDong = c.MaHopDong
                      WHERE c.MaThietBi = t.MaThietBi
                        AND c.NgayNhanThucTe IS NULL
                        AND h.TrangThai IN ('DA_KY','CHO_BAN_GIAO','DANG_THUE','CHO_HOAN_TRA')
                  )
                ORDER BY t.NgayNhap, t.MaThietBi
                """).SingleOrDefaultAsync(ct);

            if (reserve is null)
                return Results.Conflict(new
                {
                    code = "RESERVE_DEVICE_UNAVAILABLE",
                    loi = "Không còn máy dự phòng cùng dòng tại chi nhánh. Nhân viên cần đổi dòng máy hoặc lịch thuê."
                });

            var oldDeviceId = oldDevice.MaThietBi;
            var oldSerial = oldDevice.SoSerial;
            detail.MaThietBi = reserve.MaThietBi;
            oldDevice.TrangThai = request.TrangThaiThietBiCu.Trim().ToUpperInvariant();
            oldDevice.TinhTrang = request.TinhTrangThietBiCu.Trim();
            reserve.TrangThai = "DANG_GIU";

            var remaining = await db.ThietBi.CountAsync(x =>
                x.MaCuaHang == contract.MaCuaHang &&
                x.MaDongMay == oldDevice.MaDongMay &&
                x.TrangThai == "DU_PHONG" &&
                x.MaThietBi != reserve.MaThietBi, ct);
            var minimum = RentalRiskPolicy.ReserveMinimumPerModel(configuration);
            var lowStock = ReserveDevicePolicy.IsBelowMinimum(remaining, minimum);

            var recipients = await AlertRecipientsAsync(db, contract.MaCuaHang, ct);
            foreach (var accountId in recipients)
            {
                var swapNotice = ApiAccess.AddNotification(db, accountId, "THIET_BI",
                    "Đã thay thiết bị bằng máy dự phòng",
                    $"Hợp đồng {contractId}: thay serial {oldSerial} bằng {reserve.SoSerial}. Lý do: {request.LyDo.Trim()}.",
                    "RESERVE_DEVICE_SWAPPED", "HOP_DONG", contractId);
                swapNotice.EventKey = $"RESERVE_SWAP:{detailId}:{reserve.MaThietBi}:{accountId}";

                if (!lowStock) continue;
                var stockNotice = ApiAccess.AddNotification(db, accountId, "THIET_BI",
                    "Kho máy dự phòng dưới mức an toàn",
                    $"Dòng máy {oldDevice.MaDongMay} tại chi nhánh {contract.MaCuaHang} còn {remaining} máy dự phòng; mức tối thiểu là {minimum}.",
                    "RESERVE_STOCK_LOW", "DONG_MAY", oldDevice.MaDongMay);
                stockNotice.EventKey = $"RESERVE_LOW:{detailId}:{reserve.MaThietBi}:{accountId}";
            }

            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            return Results.Ok(new
            {
                contract.MaHopDong,
                detail.MaChiTietHopDong,
                thietBiCu = new { maThietBi = oldDeviceId, soSerial = oldSerial, oldDevice.TrangThai },
                thietBiMoi = new { reserve.MaThietBi, reserve.SoSerial, reserve.TrangThai },
                soLuongDuPhongConLai = remaining,
                nguongDuPhongToiThieu = minimum,
                daPhatCanhBao = lowStock
            });
        }).RequireAuthorization("Staff");
    }

    private static async Task<string[]> AlertRecipientsAsync(
        RentalCameraContext db, string storeId, CancellationToken ct)
    {
        var branchAccounts = await db.NhanVien.AsNoTracking()
            .Where(x => x.MaCuaHang == storeId && x.TrangThai == "HOAT_DONG")
            .Select(x => x.MaTaiKhoan)
            .ToListAsync(ct);
        var adminAccounts = await db.TaiKhoan.AsNoTracking()
            .Where(x => x.VaiTro == "ADMIN" && x.TrangThai == "HOAT_DONG")
            .Select(x => x.MaTaiKhoan)
            .ToListAsync(ct);
        return branchAccounts.Concat(adminAccounts).Distinct(StringComparer.Ordinal).ToArray();
    }
}

public static class ReserveDevicePolicy
{
    public static bool CanSwap(string contractStatus, DateTime? actualHandover) =>
        contractStatus == "CHO_BAN_GIAO" && actualHandover is null;

    public static bool IsIncidentState(string? state) =>
        state?.Trim().ToUpperInvariant() is "BAO_TRI" or "HONG";

    public static bool IsBelowMinimum(int remaining, int minimum) => remaining < minimum;
}

public sealed record ReserveDeviceSwapRequest(
    string TrangThaiThietBiCu,
    string TinhTrangThietBiCu,
    string LyDo);
