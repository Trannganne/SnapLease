using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;
using RentalCamera.Api.Media;
using RentalCamera.Api.Contracts;
using System.Text.Json;

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
            if(request.ThietBi is not { Count: >0 }||request.ThietBi.Any(x=>x is null||string.IsNullOrWhiteSpace(x.MaChiTietHopDong)||string.IsNullOrWhiteSpace(x.TinhTrang))||
                request.ThietBi.Select(x=>x.MaChiTietHopDong).Distinct(StringComparer.OrdinalIgnoreCase).Count()!=request.ThietBi.Count)return Results.BadRequest(new{loi="Cần danh sách thiết bị không trùng và tình trạng bàn giao."});
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null) return Results.Forbid();
            await using var tx = await db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable, ct);
            await TransactionLock.AcquireAsync(db, "contract:" + id, ct);
            if(RentalPolicy.ProtectedContracts.Contains(id))return Results.Conflict();
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

            var now = RentalPolicy.LocalNow;
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
            await tx.CommitAsync(ct);
            return Results.Ok(new { contract.MaHopDong, contract.TrangThai, thoiGianBanGiao = now });
        }).RequireAuthorization("Staff");

        contracts.MapPost("/{id}/xac-nhan-ban-giao", async (
            string id, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var customerId = await ApiAccess.CustomerIdAsync(principal, db, ct);
            if (customerId is null) return Results.Forbid();

            await using var tx = await db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable, ct);
            await TransactionLock.AcquireAsync(db, "contract:" + id, ct);

            var contract = await db.HopDong.SingleOrDefaultAsync(
                x => x.MaHopDong == id && x.MaKhachThue == customerId, ct);
            if (contract is null) return Results.NotFound();
            if (contract.TrangThai != "DANG_THUE")
                return Results.Conflict(new { loi = "Nhân viên chưa hoàn tất bàn giao thiết bị." });

            var handoverState = await db.ChiTietHopDong
                .Where(x => x.MaHopDong == id)
                .GroupBy(_ => 1)
                .Select(group => new
                {
                    SoThietBi = group.Count(),
                    ChuaBanGiao = group.Count(x => x.NgayGiaoThucTe == null)
                })
                .SingleOrDefaultAsync(ct);
            if (!CanCustomerConfirm(contract.TrangThai, handoverState?.SoThietBi ?? 0,
                    handoverState?.ChuaBanGiao ?? 0))
                return Results.Conflict(new { loi = "Biên bản bàn giao chưa đầy đủ." });

            if (contract.DaXacNhanBanGiao)
            {
                await tx.CommitAsync(ct);
                return Results.Ok(new
                {
                    contract.MaHopDong,
                    contract.TrangThai,
                    contract.DaXacNhanBanGiao,
                    daCapNhat = false
                });
            }

            contract.DaXacNhanBanGiao = true;
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            return Results.Ok(new
            {
                contract.MaHopDong,
                contract.TrangThai,
                contract.DaXacNhanBanGiao,
                daCapNhat = true
            });
        }).RequireAuthorization("Customer");

        contracts.MapPost("/{id}/nhan-lai", (string id, ReturnRequest request, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
            ReturnWorkflow.ReceiveAsync(id, request, principal, db, ct)).RequireAuthorization("Staff");
        app.MapReturnWorkflowEndpoints();

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
                DuongDanAnh = upload.SecureUrl, PublicId = upload.PublicId, MoTa = moTa?.Trim(), ThoiGianChup = RentalPolicy.LocalNow
            };
            db.AnhBienBan.Add(image);
            await db.SaveChangesAsync(ct);
            return Results.Created($"/api/chi-tiet-hop-dong/{id}/anh-bien-ban", image);
        }).DisableAntiforgery().RequireAuthorization("Staff");

        app.MapDelete("/api/anh-bien-ban/{id}", async (string id, ClaimsPrincipal principal, RentalCameraContext db,
            CloudinaryImageStorage imageStorage, ILoggerFactory loggerFactory, CancellationToken ct) =>
        {
            var image = await db.AnhBienBan.SingleOrDefaultAsync(x => x.MaAnhBienBan == id, ct);
            if (image is null) return Results.NotFound(new { loi = "Ảnh biên bản không tồn tại.", code = "EVIDENCE_NOT_FOUND" });
            var detail = await db.ChiTietHopDong.Where(x => x.MaChiTietHopDong == image.MaChiTietHopDong)
                .Join(db.HopDong, x => x.MaHopDong, x => x.MaHopDong, (d, h) => new { d, h }).SingleAsync(ct);
            var scope = await ApiAccess.StaffScopeAsync(principal, db, ct);
            if (scope is null || (!scope.IsAdmin && detail.h.MaCuaHang != scope.StoreId)) return Results.Forbid();
            if (detail.h.TrangThai is "HOAN_THANH" or "DA_HUY" || detail.d.NgayNhanThucTe != null)
                return Results.Conflict(new { loi = "Biên bản đã xác nhận hoặc quyết toán nên không thể xóa ảnh.", code = "EVIDENCE_FINALIZED" });
            if (!string.IsNullOrWhiteSpace(image.PublicId))
            {
                try { await imageStorage.DeleteReviewImageAsync(image.PublicId, ct); }
                catch (Exception ex) { loggerFactory.CreateLogger("Cloudinary").LogError(ex, "Xóa ảnh biên bản thất bại."); return Results.Problem("Không thể xóa tệp ảnh.", statusCode: 502); }
            }
            db.AnhBienBan.Remove(image); await db.SaveChangesAsync(ct); return Results.NoContent();
        }).RequireAuthorization("Staff");
    }

    public static bool CanCustomerConfirm(string contractStatus, int deviceCount, int missingHandoverCount) =>
        contractStatus == "DANG_THUE" && deviceCount > 0 && missingHandoverCount == 0;

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
public sealed record ReturnRequest(List<ReturnItemRequest> ThietBi, string? OperationId = null, DateTime? ThoiDiemThucNhan = null, string? LyDoGhiNhanMuon = null);
public sealed record ReturnItemRequest(string MaChiTietHopDong, string TinhTrang, bool CoHuHong,DateTime? NgayNhanThucTe=null,string? LyDoGhiNhanMuon=null, string? SoSerialDoiChieu=null);
