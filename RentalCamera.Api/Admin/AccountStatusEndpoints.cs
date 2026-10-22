using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Admin;

public static class AccountStatusEndpoints
{
    public static void MapAccountStatusEndpoints(this IEndpointRouteBuilder app)
    {
        var accounts = app.MapGroup("/api/tai-khoan")
            .RequireAuthorization("Admin");

        accounts.MapPut("/{id}/trang-thai", async (
            string id,
            ChangeAccountStatusRequest request,
            ClaimsPrincipal principal,
            RentalCameraContext db,
            CancellationToken ct) =>
        {
            var newStatus = request.TrangThai?.Trim().ToUpperInvariant();
            if (newStatus is not ("HOAT_DONG" or "TAM_KHOA"))
                return Results.BadRequest(new { loi = "Trạng thái phải là HOAT_DONG hoặc TAM_KHOA." });

            var reason = string.IsNullOrWhiteSpace(request.LyDo) ? null : request.LyDo.Trim();
            if (reason?.Length > 500)
                return Results.BadRequest(new { loi = "Lý do không được vượt quá 500 ký tự." });

            var actorId = principal.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(actorId)) return Results.Unauthorized();

            var account = await db.TaiKhoan.SingleOrDefaultAsync(x => x.MaTaiKhoan == id, ct);
            if (account is null) return Results.NotFound();

            if (id == actorId && newStatus == "TAM_KHOA")
                return Results.Conflict(new { loi = "Admin không thể tự khóa tài khoản đang sử dụng." });

            if (account.VaiTro == "ADMIN" && newStatus == "TAM_KHOA")
            {
                var otherActiveAdmins = await db.TaiKhoan.CountAsync(
                    x => x.MaTaiKhoan != id && x.VaiTro == "ADMIN" && x.TrangThai == "HOAT_DONG", ct);
                if (otherActiveAdmins == 0)
                    return Results.Conflict(new { loi = "Không thể khóa Admin hoạt động cuối cùng." });
            }

            if (account.TrangThai == newStatus)
            {
                return Results.Ok(new AccountStatusResponse(
                    account.MaTaiKhoan,
                    account.TenDangNhap,
                    account.VaiTro,
                    account.TrangThai,
                    false,
                    null));
            }

            var oldStatus = account.TrangThai;
            var changedAt = DateTime.UtcNow;
            var history = new LichSuTrangThaiTaiKhoan
            {
                MaLichSu = ApiAccess.NewId("LS"),
                MaTaiKhoan = account.MaTaiKhoan,
                TrangThaiCu = oldStatus,
                TrangThaiMoi = newStatus,
                LyDo = reason,
                NguoiThaoTac = actorId,
                ThoiGian = changedAt
            };

            account.TrangThai = newStatus;
            db.LichSuTrangThaiTaiKhoan.Add(history);

            if (newStatus == "TAM_KHOA")
            {
                var deviceTokens = await db.FcmDeviceToken
                    .Where(x => x.MaTaiKhoan == id && x.IsActive)
                    .ToListAsync(ct);
                foreach (var deviceToken in deviceTokens)
                {
                    deviceToken.IsActive = false;
                    deviceToken.UpdatedAt = changedAt;
                }
            }

            await db.SaveChangesAsync(ct);

            return Results.Ok(new AccountStatusResponse(
                account.MaTaiKhoan,
                account.TenDangNhap,
                account.VaiTro,
                account.TrangThai,
                true,
                new AccountStatusHistoryResponse(
                    history.MaLichSu,
                    history.TrangThaiCu,
                    history.TrangThaiMoi,
                    history.LyDo,
                    history.NguoiThaoTac,
                    history.ThoiGian)));
        });

        accounts.MapGet("/{id}/lich-su-trang-thai", async (
            string id,
            RentalCameraContext db,
            CancellationToken ct) =>
        {
            if (!await db.TaiKhoan.AnyAsync(x => x.MaTaiKhoan == id, ct))
                return Results.NotFound();

            var history = await db.LichSuTrangThaiTaiKhoan.AsNoTracking()
                .Where(x => x.MaTaiKhoan == id)
                .OrderByDescending(x => x.ThoiGian)
                .Select(x => new AccountStatusHistoryResponse(
                    x.MaLichSu,
                    x.TrangThaiCu,
                    x.TrangThaiMoi,
                    x.LyDo,
                    x.NguoiThaoTac,
                    x.ThoiGian))
                .ToListAsync(ct);

            return Results.Ok(history);
        });
    }
}

public sealed record ChangeAccountStatusRequest(string? TrangThai, string? LyDo);

public sealed record AccountStatusResponse(
    string MaTaiKhoan,
    string TenDangNhap,
    string VaiTro,
    string TrangThai,
    bool DaThayDoi,
    AccountStatusHistoryResponse? LichSu);

public sealed record AccountStatusHistoryResponse(
    string MaLichSu,
    string TrangThaiCu,
    string TrangThaiMoi,
    string? LyDo,
    string NguoiThaoTac,
    DateTime ThoiGian);
