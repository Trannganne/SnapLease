using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Handover;

public static class HandoverEndpoints
{
    public static void MapHandoverEndpoints(this IEndpointRouteBuilder app)
    {
        var contracts = app.MapGroup("/api/hop-dong").RequireAuthorization();

        contracts.MapGet("/{id}/ban-giao", async (string id, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            if (!await ApiAccess.CanAccessContractAsync(id, principal, db, ct)) return Results.Forbid();
            var contract = await db.HopDong.AsNoTracking().SingleOrDefaultAsync(x => x.MaHopDong == id, ct);
            if (contract is null) return Results.NotFound();
            var details = await ContractDetails(id, db, ct);
            return Results.Ok(new { hopDong = contract, chiTiet = details });
        });

        contracts.MapPost("/{id}/ban-giao", async (
            string id, HandoverRequest request, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            var contract = await db.HopDong.SingleOrDefaultAsync(x => x.MaHopDong == id, ct);
            if (contract is null) return Results.NotFound();
            if (!scope.IsAdmin && contract.MaCuaHang != scope.StoreId) return Results.Forbid();
            if (contract.TrangThai != "CHO_BAN_GIAO") return Results.Conflict(new { loi = "Hợp đồng chưa được chuẩn bị đủ thiết bị để bàn giao." });
            if (!await db.ThanhToan.AnyAsync(x => x.MaHopDong == id && x.LoaiThanhToan == "TIEN_COC" && x.TrangThai == "THANH_CONG", ct))
                return Results.Conflict(new { loi = "Chưa xác nhận thanh toán tiền cọc." });

            var details = await db.ChiTietHopDong.Where(x => x.MaHopDong == id).ToListAsync(ct);
            if (details.Count == 0) return Results.Conflict(new { loi = "Hợp đồng chưa có thiết bị." });
            var supplied = request.ThietBi.ToDictionary(x => x.MaChiTietHopDong, StringComparer.OrdinalIgnoreCase);
            if (details.Any(x => !supplied.ContainsKey(x.MaChiTietHopDong)))
                return Results.BadRequest(new { loi = "Phải ghi nhận tình trạng của tất cả thiết bị." });

            var now = DateTime.Now;
            foreach (var detail in details)
            {
                detail.TinhTrangLucGiao = supplied[detail.MaChiTietHopDong].TinhTrang.Trim();
                detail.NgayGiaoThucTe = now;
            }
            var deviceIds = details.Select(x => x.MaThietBi).ToList();
            var devices = await db.ThietBi.Where(x => deviceIds.Contains(x.MaThietBi)).ToListAsync(ct);
            foreach (var device in devices) device.TrangThai = "DANG_THUE";
            contract.TrangThai = "DANG_THUE";
            await db.SaveChangesAsync(ct);
            return Results.Ok(new { contract.MaHopDong, contract.TrangThai, thoiGianBanGiao = now });
        }).RequireAuthorization("Staff");

        contracts.MapPost("/{id}/nhan-lai", async (
            string id, ReturnRequest request, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            var contract = await db.HopDong.SingleOrDefaultAsync(x => x.MaHopDong == id, ct);
            if (contract is null) return Results.NotFound();
            if (!scope.IsAdmin && contract.MaCuaHang != scope.StoreId) return Results.Forbid();
            if (contract.TrangThai != "DANG_THUE") return Results.Conflict(new { loi = "Hợp đồng chưa ở trạng thái đang thuê." });

            var details = await db.ChiTietHopDong.Where(x => x.MaHopDong == id).ToListAsync(ct);
            var supplied = request.ThietBi.ToDictionary(x => x.MaChiTietHopDong, StringComparer.OrdinalIgnoreCase);
            if (details.Count == 0 || details.Any(x => !supplied.ContainsKey(x.MaChiTietHopDong)))
                return Results.BadRequest(new { loi = "Phải ghi nhận tình trạng của tất cả thiết bị." });

            var now = DateTime.Now;
            foreach (var detail in details)
            {
                var item = supplied[detail.MaChiTietHopDong];
                detail.TinhTrangLucNhan = item.TinhTrang.Trim();
                detail.NgayNhanThucTe = now;
                detail.CoHuHong = item.CoHuHong;
            }
            var deviceIds = details.Select(x => x.MaThietBi).ToList();
            var devices = await db.ThietBi.Where(x => deviceIds.Contains(x.MaThietBi)).ToListAsync(ct);
            foreach (var device in devices)
            {
                var detail = details.Single(x => x.MaThietBi == device.MaThietBi);
                device.TrangThai = detail.CoHuHong ? "BAO_TRI" : "SAN_SANG";
                if (detail.TinhTrangLucNhan is not null) device.TinhTrang = detail.TinhTrangLucNhan;
            }
            contract.TrangThai = "CHO_HOAN_TRA";
            await db.SaveChangesAsync(ct);
            return Results.Ok(new { contract.MaHopDong, contract.TrangThai, thoiGianNhanLai = now });
        }).RequireAuthorization("Staff");

        app.MapPost("/api/chi-tiet-hop-dong/{id}/anh-bien-ban", async (
            string id, EvidenceImageRequest request, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            if (request.Loai is not ("BAN_GIAO" or "NHAN_LAI" or "HU_HONG") || string.IsNullOrWhiteSpace(request.DuongDanAnh))
                return Results.BadRequest(new { loi = "Loại hoặc đường dẫn ảnh không hợp lệ." });
            var contractId = await db.ChiTietHopDong.Where(x => x.MaChiTietHopDong == id)
                .Select(x => x.MaHopDong).SingleOrDefaultAsync(ct);
            if (contractId is null) return Results.NotFound();
            if (!await ApiAccess.CanAccessContractAsync(contractId, principal, db, ct)) return Results.Forbid();
            var image = new AnhBienBan
            {
                MaAnhBienBan = ApiAccess.NewId("BB"), MaChiTietHopDong = id, Loai = request.Loai,
                DuongDanAnh = request.DuongDanAnh.Trim(), MoTa = request.MoTa?.Trim(), ThoiGianChup = DateTime.Now
            };
            db.AnhBienBan.Add(image);
            await db.SaveChangesAsync(ct);
            return Results.Created($"/api/chi-tiet-hop-dong/{id}/anh-bien-ban", image);
        });
    }

    private static async Task<List<object>> ContractDetails(string id, RentalCameraContext db, CancellationToken ct) =>
        await db.ChiTietHopDong.AsNoTracking().Where(x => x.MaHopDong == id)
            .Join(db.ThietBi, ct => ct.MaThietBi, tb => tb.MaThietBi, (ct, tb) => new { ct, tb })
            .Join(db.DongMay, x => x.tb.MaDongMay, dm => dm.MaDongMay, (x, dm) => (object)new
            {
                x.ct.MaChiTietHopDong, x.ct.MaThietBi, dm.MaDongMay, dm.TenDongMay, x.tb.SoSerial,
                x.ct.TinhTrangLucGiao, x.ct.NgayGiaoThucTe, x.ct.TinhTrangLucNhan,
                x.ct.NgayNhanThucTe, x.ct.CoHuHong
            }).ToListAsync(ct);
}

public sealed record HandoverRequest(List<HandoverItemRequest> ThietBi);
public sealed record HandoverItemRequest(string MaChiTietHopDong, string TinhTrang);
public sealed record ReturnRequest(List<ReturnItemRequest> ThietBi);
public sealed record ReturnItemRequest(string MaChiTietHopDong, string TinhTrang, bool CoHuHong);
public sealed record EvidenceImageRequest(string Loai, string DuongDanAnh, string? MoTa);
