using System.Security.Claims;
using System.Security.Cryptography;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using RentalCamera.Api.Data;

namespace RentalCamera.Api.Auth;

// Token Bearer nội bộ có hạn sử dụng; đây không phải JWT.
public sealed class BearerTokenHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> options,
    ILoggerFactory logger,
    UrlEncoder encoder,
    IDataProtectionProvider protectionProvider,
    RentalCameraContext db)
    : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    private readonly ITimeLimitedDataProtector _protector = protectionProvider
        .CreateProtector("RentalCamera.Api", "BearerToken", "v1")
        .ToTimeLimitedDataProtector();

    protected override async Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var authorization = Request.Headers.Authorization.ToString();
        if (!authorization.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
            return AuthenticateResult.NoResult();

        var token = authorization[7..].Trim();
        if (token.Length is < 20 or > 5000)
            return AuthenticateResult.Fail("Token không hợp lệ.");

        string accountId;
        try
        {
            accountId = _protector.Unprotect(token);
        }
        catch (Exception ex) when (ex is CryptographicException or FormatException or ArgumentException)
        {
            return AuthenticateResult.Fail("Token hết hạn hoặc không hợp lệ.");
        }

        var account = await db.TaiKhoan.AsNoTracking()
            .SingleOrDefaultAsync(x => x.MaTaiKhoan == accountId && x.TrangThai == "HOAT_DONG");
        if (account is null)
            return AuthenticateResult.Fail("Tài khoản không còn hoạt động.");

        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, account.MaTaiKhoan),
            new Claim(ClaimTypes.Name, account.TenDangNhap),
            new Claim(ClaimTypes.Role, account.VaiTro)
        };
        var principal = new ClaimsPrincipal(new ClaimsIdentity(claims, Scheme.Name));
        return AuthenticateResult.Success(new AuthenticationTicket(principal, Scheme.Name));
    }
}

public sealed class TokenIssuer(IDataProtectionProvider protectionProvider)
{
    private readonly ITimeLimitedDataProtector _protector = protectionProvider
        .CreateProtector("RentalCamera.Api", "BearerToken", "v1")
        .ToTimeLimitedDataProtector();

    public string Issue(string accountId) => _protector.Protect(accountId, TimeSpan.FromHours(1));
}
