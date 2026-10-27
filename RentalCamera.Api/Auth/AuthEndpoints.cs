using System.Data;
using RentalCamera.Api.Infrastructure;
using RentalCamera.Api.Email;
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
                !PasswordPolicy.IsValid(request.MatKhau) ||
                string.IsNullOrWhiteSpace(request.SoDienThoai) ||
                !Regex.IsMatch(request.SoDienThoai, "^[0-9]{9,15}$"))
                return Results.BadRequest(new
                {
                    loi = $"Tên đăng nhập phải có 4–50 ký tự; {PasswordPolicy.Description} Số điện thoại phải hợp lệ."
                });

            if (!string.IsNullOrWhiteSpace(request.Email) && AuthLinkService.NormalizeEmail(request.Email)==null) return Results.BadRequest();
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
                // HoTen là bắt buộc trong database nhưng chỉ được người dùng cung cấp
                // ở bước xác minh danh tính sau này.
                HoTen = null,
                SoDienThoai = phone,
                Email = AuthLinkService.NormalizeEmail(request.Email)
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

        group.MapPost("/email/xac-minh/gui", async (ClaimsPrincipal principal, RentalCameraContext db, AuthLinkService links, IAuthEmailSender sender, IConfiguration config, CancellationToken ct) => {
            var accountId = ApiAccess.AccountId(principal);
            var account = await db.TaiKhoan.AsNoTracking().SingleOrDefaultAsync(a=>a.MaTaiKhoan==accountId && a.TrangThai=="HOAT_DONG",ct);
            var customer = await db.KhachThue.AsNoTracking().SingleOrDefaultAsync(k=>k.MaTaiKhoan==accountId,ct);
            if (account == null || customer?.Email==null) return Results.BadRequest(new { code="EMAIL_REQUIRED" });
            if (customer.EmailXacMinhLucUtc==null) await sender.SendAsync(customer.Email,"VERIFY_EMAIL",links.Issue(account,customer.Email,"VERIFY_EMAIL",TimeSpan.FromMinutes(Math.Clamp(config.GetValue("EmailVerification:TokenLifetimeMinutes",15),5,60))),ct);
            return Results.Accepted(value:new { thongBao="Yêu cầu xác minh email đã được tiếp nhận." });
        }).RequireAuthorization("Customer").RequireRateLimiting("auth");
        group.MapPost("/email/xac-minh", async (EmailVerificationRequest r, RentalCameraContext db, AuthLinkService links, CancellationToken ct) => {
            if (!links.TryRead(r.Token,"VERIFY_EMAIL",out var claim)) return Results.BadRequest(new { code="INVALID_AUTH_LINK" });
            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable,ct);
            await TransactionLock.AcquireAsync(db,"account:"+claim.AccountId,ct);
            await TransactionLock.AcquireAsync(db,"email:"+AuthLinkService.Fingerprint(claim.Email),ct);
            var account = await db.TaiKhoan.SingleOrDefaultAsync(a=>a.MaTaiKhoan==claim.AccountId && a.TrangThai=="HOAT_DONG",ct);
            var customer = await db.KhachThue.SingleOrDefaultAsync(k=>k.MaTaiKhoan==claim.AccountId,ct);
            if (account==null || customer?.Email!=claim.Email) return Results.BadRequest(new { code="INVALID_AUTH_LINK" });
            if (customer.EmailXacMinhLucUtc!=null) return Results.NoContent();
            if (account.PhienBanBaoMat!=claim.Epoch || AuthLinkService.Fingerprint(account.MatKhauHash)!=claim.Fingerprint) return Results.BadRequest(new { code="INVALID_AUTH_LINK" });
            if (await db.KhachThue.AnyAsync(k=>k.MaTaiKhoan!=claim.AccountId && k.Email==claim.Email && k.EmailXacMinhLucUtc!=null,ct)) return Results.Conflict(new { code="VERIFIED_EMAIL_ALREADY_USED" });
            customer.EmailXacMinhLucUtc=DateTime.UtcNow; account.PhienBanBaoMat=checked(account.PhienBanBaoMat+1);
            await db.SaveChangesAsync(ct); await tx.CommitAsync(ct); return Results.NoContent();
        }).RequireRateLimiting("auth");
        group.MapPut("/email", async (ChangeEmailRequest r, ClaimsPrincipal principal, RentalCameraContext db, CancellationToken ct) => {
            var email=AuthLinkService.NormalizeEmail(r.Email); if(email==null)return Results.BadRequest();
            var id=ApiAccess.AccountId(principal)!;
            await using var tx=await db.Database.BeginTransactionAsync(IsolationLevel.Serializable,ct);
            await TransactionLock.AcquireAsync(db,"account:"+id,ct);
            var account=await db.TaiKhoan.SingleAsync(a=>a.MaTaiKhoan==id,ct);
            var customer=await db.KhachThue.SingleOrDefaultAsync(k=>k.MaTaiKhoan==id,ct);if(customer==null)return Results.Forbid();
            if(customer.Email!=email){customer.Email=email;customer.EmailXacMinhLucUtc=null;account.PhienBanBaoMat=checked(account.PhienBanBaoMat+1);await db.SaveChangesAsync(ct);}
            await tx.CommitAsync(ct); return Results.NoContent();
        }).RequireAuthorization("Customer");
        group.MapPost("/quen-mat-khau", async (ForgotPasswordRequest request, RentalCameraContext db, AuthLinkService links, IAuthEmailSender sender, IConfiguration config, CancellationToken ct) => {
            var email=AuthLinkService.NormalizeEmail(request.EmailHoacSoDienThoai);
            if(email!=null){
                var customer=await db.KhachThue.AsNoTracking().SingleOrDefaultAsync(k=>k.Email==email && k.EmailXacMinhLucUtc!=null,ct);
                var account=customer==null?null:await db.TaiKhoan.AsNoTracking().SingleOrDefaultAsync(a=>a.MaTaiKhoan==customer.MaTaiKhoan && a.TrangThai=="HOAT_DONG",ct);
                if(account!=null) await sender.SendAsync(email,"RESET_PASSWORD",links.Issue(account,email,"RESET_PASSWORD",TimeSpan.FromMinutes(Math.Clamp(config.GetValue("PasswordReset:TokenLifetimeMinutes",15),5,60))),ct);
            }
            return Results.Accepted(value:new { thongBao="Nếu email đã xác minh hợp lệ, hướng dẫn đặt lại mật khẩu sẽ được gửi." });
        }).RequireRateLimiting("auth");
        group.MapPost("/dat-lai-mat-khau", async (ResetPasswordRequest request,RentalCameraContext db,IPasswordHasher<TaiKhoan> hasher,AuthLinkService links,CancellationToken ct)=>{
            if(!PasswordPolicy.IsValid(request.MatKhauMoi))return Results.BadRequest(new{loi=PasswordPolicy.Description});
            if(!links.TryRead(request.ResetToken,"RESET_PASSWORD",out var claim))return Results.BadRequest(new{code="INVALID_AUTH_LINK"});
            await using var tx=await db.Database.BeginTransactionAsync(IsolationLevel.Serializable,ct);
            await TransactionLock.AcquireAsync(db,"account:"+claim.AccountId,ct);
            var account=await db.TaiKhoan.SingleOrDefaultAsync(a=>a.MaTaiKhoan==claim.AccountId && a.TrangThai=="HOAT_DONG",ct);
            if(account==null || account.PhienBanBaoMat!=claim.Epoch || AuthLinkService.Fingerprint(account.MatKhauHash)!=claim.Fingerprint ||
                !await db.KhachThue.AnyAsync(k=>k.MaTaiKhoan==claim.AccountId && k.Email==claim.Email && k.EmailXacMinhLucUtc!=null,ct))return Results.BadRequest(new{code="INVALID_AUTH_LINK"});
            account.MatKhauHash=hasher.HashPassword(account,request.MatKhauMoi);account.PhienBanBaoMat=checked(account.PhienBanBaoMat+1);
            await db.SaveChangesAsync(ct);await tx.CommitAsync(ct);return Results.NoContent();
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
                accessToken = issuer.Issue(account.MaTaiKhoan,account.PhienBanBaoMat),
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
                !PasswordPolicy.IsValid(request.MatKhauMoi))
                return Results.BadRequest(new { loi = PasswordPolicy.Description });

            var accountId = principal.FindFirstValue(ClaimTypes.NameIdentifier);
            await using var tx=await db.Database.BeginTransactionAsync(IsolationLevel.Serializable,ct);
            await TransactionLock.AcquireAsync(db,"account:"+accountId,ct);
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

            account.MatKhauHash = hasher.HashPassword(account, request.MatKhauMoi); account.PhienBanBaoMat=checked(account.PhienBanBaoMat+1);
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            return Results.NoContent();
        }).RequireAuthorization();
    }
}

public sealed record RegisterRequest(string TenDangNhap, string MatKhau, string SoDienThoai, string? Email);
public sealed record ForgotPasswordRequest(string EmailHoacSoDienThoai);
public sealed record ResetPasswordRequest(string ResetToken, string MatKhauMoi);
public sealed record LoginRequest(string TenDangNhap, string MatKhau);
public sealed record ChangePasswordRequest(string MatKhauCu, string MatKhauMoi);

public sealed record EmailVerificationRequest(string Token);
public sealed record ChangeEmailRequest(string Email);
