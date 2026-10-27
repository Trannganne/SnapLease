using System.Security.Cryptography;
using System.Net.Mail;
using Microsoft.AspNetCore.DataProtection;
using RentalCamera.Api.Data;

namespace RentalCamera.Api.Auth;

public sealed record AuthLinkClaims(string AccountId, string Email, int Epoch, string Purpose, string Fingerprint);
public sealed class AuthLinkService(IDataProtectionProvider provider)
{
    private readonly ITimeLimitedDataProtector protector = provider.CreateProtector("SnapLease.Schema33.AuthLinks.v1").ToTimeLimitedDataProtector();
    public static string Fingerprint(string hash) => Convert.ToHexString(SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(hash)));
    public string Issue(TaiKhoan account, string email, string purpose, TimeSpan lifetime) =>
        protector.Protect(System.Text.Json.JsonSerializer.Serialize(new AuthLinkClaims(account.MaTaiKhoan, email, account.PhienBanBaoMat, purpose, Fingerprint(account.MatKhauHash))), lifetime);
    public bool TryRead(string? value, string purpose, out AuthLinkClaims claims)
    {
        claims = null!;
        if (string.IsNullOrWhiteSpace(value) || value.Length > 5000) return false;
        try { claims = System.Text.Json.JsonSerializer.Deserialize<AuthLinkClaims>(protector.Unprotect(value))!;
            return claims != null && claims.Purpose == purpose && claims.Epoch >= 0; }
        catch (Exception e) when (e is CryptographicException or FormatException or ArgumentException or System.Text.Json.JsonException) { return false; }
    }
    public static string? NormalizeEmail(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return null;
        var trimmed = value.Trim();
        if (trimmed.Length > 255) return null;
        try { var mail = new MailAddress(trimmed); return mail.Address == trimmed ? trimmed.ToUpperInvariant() : null; }
        catch (FormatException) { return null; }
    }
}
