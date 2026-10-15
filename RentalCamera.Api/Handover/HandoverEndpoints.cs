using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;
using RentalCamera.Api.Media;

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
            string id,
            [FromForm] string loai,
            IFormFile anh,
            [FromForm] string? moTa,
            ClaimsPrincipal principal,
            RentalCameraContext db,
            CloudinaryImageStorage imageStorage,
            ILoggerFactory loggerFactory,
            CancellationToken ct) =>
        {
            if (loai is not ("BAN_GIAO" or "NHAN_LAI" or "HU_HONG"))
                return Results.BadRequest(new { loi = "Loại ảnh phải là BAN_GIAO, NHAN_LAI hoặc HU_HONG." });
            if (anh.Length == 0)
                return Results.BadRequest(new { loi = "Chưa chọn file ảnh." });
            if (anh.Length > imageStorage.MaximumBytes)
                return Results.BadRequest(new { loi = $"Ảnh không được vượt quá {imageStorage.MaximumBytes / 1024 / 1024} MB." });
            if (anh.ContentType is not ("image/jpeg" or "image/png" or "image/webp"))
                return Results.BadRequest(new { loi = "Chỉ chấp nhận ảnh JPEG, PNG hoặc WEBP." });

            var contract = await db.ChiTietHopDong
                .Where(x => x.MaChiTietHopDong == id)
                .Join(db.HopDong, detail => detail.MaHopDong, item => item.MaHopDong,
                    (_, item) => new { item.MaHopDong, item.MaCuaHang })
                .SingleOrDefaultAsync(ct);
            if (contract is null) return Results.NotFound();

            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null || (!scope.IsAdmin && contract.MaCuaHang != scope.StoreId))
                return Results.Forbid();

            CloudinaryUploadResult upload;
            try
            {
                upload = await imageStorage.UploadEvidenceAsync(anh, id, ct);
            }
            catch (InvalidOperationException ex)
            {
                loggerFactory.CreateLogger("Cloudinary").LogError(ex, "Thiếu cấu hình Cloudinary.");
                return Results.Problem(ex.Message, statusCode: StatusCodes.Status503ServiceUnavailable);
            }
            catch (HttpRequestException ex)
            {
                loggerFactory.CreateLogger("Cloudinary").LogError(ex, "Upload ảnh biên bản thất bại.");
                return Results.Problem("Không thể tải ảnh lên Cloudinary.", statusCode: StatusCodes.Status502BadGateway);
            }

            var image = new AnhBienBan
            {
                MaAnhBienBan = ApiAccess.NewId("BB"), MaChiTietHopDong = id, Loai = loai,
                DuongDanAnh = upload.SecureUrl, MoTa = moTa?.Trim(), ThoiGianChup = DateTime.Now
            };
            db.AnhBienBan.Add(image);
            await db.SaveChangesAsync(ct);
            return Results.Created($"/api/chi-tiet-hop-dong/{id}/anh-bien-ban", image);
        }).DisableAntiforgery().RequireAuthorization("Staff");
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
