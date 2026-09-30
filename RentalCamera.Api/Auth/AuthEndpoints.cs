using System.Security.Claims;
using System.Security.Cryptography;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;

namespace RentalCamera.Api.Auth;

public static class AuthEndpoints
{
    public static void MapAuthEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/auth");

        group.MapPost("/register", async (
            RegisterRequest request,
            RentalCameraContext db,
            IPasswordHasher<TaiKhoan> hasher,
            CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(request.TenDangNhap) ||
                !Regex.IsMatch(request.TenDangNhap, "^[a-zA-Z0-9_.-]{4,50}$") ||
                string.IsNullOrWhiteSpace(request.MatKhau) || request.MatKhau.Length < 12 ||
                request.MatKhau.Length > 128 ||
                string.IsNullOrWhiteSpace(request.HoTen) || request.HoTen.Length > 150 ||
                string.IsNullOrWhiteSpace(request.SoDienThoai) ||
                !Regex.IsMatch(request.SoDienThoai, "^[0-9]{9,15}$"))
                return Results.BadRequest(new { loi = "Tên đăng nhập 4–50 ký tự; mật khẩu 12–128 ký tự; họ tên và số điện thoại hợp lệ." });

            var username = request.TenDangNhap.Trim();
            var phone = request.SoDienThoai.Trim();
            if (await db.TaiKhoan.AnyAsync(x => x.TenDangNhap == username, ct) ||
                await db.KhachThue.AnyAsync(x => x.SoDienThoai == phone, ct))
                return Results.Conflict(new { loi = "Tên đăng nhập hoặc số điện thoại đã tồn tại." });

            var account = new TaiKhoan
            {
                MaTaiKhoan = "TK" + Guid.NewGuid().ToString("N")[..17].ToUpperInvariant(),
                TenDangNhap = username,
                VaiTro = "KHACH_HANG",
                TrangThai = "HOAT_DONG",
                NgayTao = DateTime.Now
            };
            account.MatKhauHash = hasher.HashPassword(account, request.MatKhau);
            var customer = new KhachThue
            {
                MaKhachThue = "KH" + Guid.NewGuid().ToString("N")[..17].ToUpperInvariant(),
                MaTaiKhoan = account.MaTaiKhoan,
                HoTen = request.HoTen.Trim(),
                SoDienThoai = phone,
                Email = string.IsNullOrWhiteSpace(request.Email) ? null : request.Email.Trim()
            };
            db.TaiKhoan.Add(account);
            db.KhachThue.Add(customer);
            try
            {
                await db.SaveChangesAsync(ct);
            }
            catch (DbUpdateException)
            {
                return Results.Conflict(new { loi = "Không thể tạo tài khoản; hãy kiểm tra thông tin trùng lặp." });
            }

            return Results.Created($"/api/auth/me", new { account.MaTaiKhoan, customer.MaKhachThue, account.TenDangNhap });
        }).RequireRateLimiting("auth");

        group.MapPost("/login", async (
            LoginRequest request,
            RentalCameraContext db,
            IPasswordHasher<TaiKhoan> hasher,
            TokenIssuer issuer,
            CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(request.TenDangNhap) || string.IsNullOrEmpty(request.MatKhau))
                return Results.BadRequest(new { loi = "Thiếu tên đăng nhập hoặc mật khẩu." });

            var username = request.TenDangNhap.Trim();
            var account = await db.TaiKhoan.AsNoTracking()
                .SingleOrDefaultAsync(x => x.TenDangNhap == username && x.TrangThai == "HOAT_DONG", ct);
            if (account is null)
                return Results.Unauthorized();

            PasswordVerificationResult result;
            try
            {
                result = hasher.VerifyHashedPassword(account, account.MatKhauHash, request.MatKhau);
            }
            catch (Exception ex) when (ex is FormatException or ArgumentException or CryptographicException)
            {
                // Các hash giả trong dữ liệu mẫu không được chấp nhận làm mật khẩu thật.
                return Results.Unauthorized();
            }
            if (result == PasswordVerificationResult.Failed)
                return Results.Unauthorized();

            return Results.Ok(new
            {
                accessToken = issuer.Issue(account.MaTaiKhoan),
                tokenType = "Bearer",
                expiresInSeconds = 3600,
                account.MaTaiKhoan,
                account.TenDangNhap,
                account.VaiTro
            });
        }).RequireRateLimiting("auth");

        group.MapGet("/me", async (ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) =>
        {
            var accountId = principal.FindFirstValue(ClaimTypes.NameIdentifier)!;
            var customerId = await db.KhachThue.AsNoTracking()
                .Where(x => x.MaTaiKhoan == accountId).Select(x => x.MaKhachThue)
                .FirstOrDefaultAsync(ct);
            var employee = await db.NhanVien.AsNoTracking()
                .Where(x => x.MaTaiKhoan == accountId)
                .Select(x => new { x.MaNhanVien, x.MaCuaHang }).FirstOrDefaultAsync(ct);
            return Results.Ok(new
            {
                maTaiKhoan = accountId,
                tenDangNhap = principal.Identity?.Name,
                vaiTro = principal.FindFirstValue(ClaimTypes.Role),
                maKhachThue = customerId,
                maNhanVien = employee?.MaNhanVien,
                maCuaHang = employee?.MaCuaHang
            });
        }).RequireAuthorization();

        group.MapPut("/doi-mat-khau", async (
            ChangePasswordRequest request,
            ClaimsPrincipal principal,
            RentalCameraContext db,
            IPasswordHasher<TaiKhoan> hasher,
            CancellationToken ct) =>
        {
            if (string.IsNullOrEmpty(request.MatKhauCu) ||
                string.IsNullOrEmpty(request.MatKhauMoi) ||
                request.MatKhauMoi.Length is < 12 or > 128)
                return Results.BadRequest(new { loi = "Mật khẩu mới phải có từ 12 đến 128 ký tự." });

            var accountId = principal.FindFirstValue(ClaimTypes.NameIdentifier);
            var account = await db.TaiKhoan.SingleOrDefaultAsync(x => x.MaTaiKhoan == accountId, ct);
            if (account is null) return Results.Unauthorized();

            PasswordVerificationResult verification;
            try
            {
                verification = hasher.VerifyHashedPassword(account, account.MatKhauHash, request.MatKhauCu);
            }
            catch (Exception ex) when (ex is FormatException or ArgumentException or CryptographicException)
            {
                return Results.BadRequest(new { loi = "Mật khẩu hiện tại không đúng." });
            }
            if (verification == PasswordVerificationResult.Failed)
                return Results.BadRequest(new { loi = "Mật khẩu hiện tại không đúng." });

            account.MatKhauHash = hasher.HashPassword(account, request.MatKhauMoi);
            await db.SaveChangesAsync(ct);
            return Results.NoContent();
        }).RequireAuthorization();
    }
}

public sealed record RegisterRequest(string TenDangNhap, string MatKhau, string HoTen, string SoDienThoai, string? Email);
public sealed record LoginRequest(string TenDangNhap, string MatKhau);
public sealed record ChangePasswordRequest(string MatKhauCu, string MatKhauMoi);
