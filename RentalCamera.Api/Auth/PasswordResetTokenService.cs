using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.DataProtection;

namespace RentalCamera.Api.Auth;

public sealed class PasswordResetTokenService(IDataProtectionProvider protectionProvider)
{
    private readonly ITimeLimitedDataProtector _protector = protectionProvider
        .CreateProtector("RentalCamera.Api", "PasswordReset", "v1")
        .ToTimeLimitedDataProtector();

    public string Issue(string accountId, string passwordHash, TimeSpan lifetime)
    {
        var payload = $"{accountId}\n{Fingerprint(passwordHash)}";
        return _protector.Protect(payload, lifetime);
    }

    public bool TryRead(string token, out string accountId, out string passwordFingerprint)
    {
        accountId = "";
        passwordFingerprint = "";
        try
        {
            var payload = _protector.Unprotect(token);
            var separator = payload.IndexOf('\n');
            if (separator <= 0 || separator == payload.Length - 1) return false;
            accountId = payload[..separator];
            passwordFingerprint = payload[(separator + 1)..];
            return accountId.Length <= 20 && passwordFingerprint.Length > 0;
        }
        catch (Exception ex) when (ex is CryptographicException or FormatException or ArgumentException)
        {
            return false;
        }
    }

    public bool MatchesCurrentPassword(string passwordFingerprint, string passwordHash)
    {
        try
        {
            var expected = Convert.FromBase64String(passwordFingerprint);
            var current = Convert.FromBase64String(Fingerprint(passwordHash));
            return expected.Length == current.Length &&
                   CryptographicOperations.FixedTimeEquals(expected, current);
        }
        catch (FormatException)
        {
            return false;
        }
    }

    private static string Fingerprint(string passwordHash) =>
        Convert.ToBase64String(SHA256.HashData(Encoding.UTF8.GetBytes(passwordHash)));
}
