using System.Text.Json;
using FirebaseAdmin;
using FirebaseAdmin.Auth;

namespace RentalCamera.Api.Auth;

public sealed record GoogleIdentity(string Subject, string Email, bool EmailVerified, string? DisplayName);

public interface IGoogleIdentityTokenVerifier
{
    Task<GoogleIdentity?> VerifyAsync(string idToken, CancellationToken cancellationToken);
}

public sealed class DisabledGoogleIdentityTokenVerifier : IGoogleIdentityTokenVerifier
{
    public Task<GoogleIdentity?> VerifyAsync(string idToken, CancellationToken cancellationToken) =>
        Task.FromResult<GoogleIdentity?>(null);
}

public sealed class FirebaseGoogleIdentityTokenVerifier(FirebaseApp app) : IGoogleIdentityTokenVerifier
{
    public async Task<GoogleIdentity?> VerifyAsync(string idToken, CancellationToken cancellationToken)
    {
        FirebaseToken token;
        try
        {
            token = await FirebaseAuth.GetAuth(app).VerifyIdTokenAsync(idToken, true, cancellationToken);
        }
        catch (FirebaseAuthException)
        {
            return null;
        }

        if (!TryString(token.Claims, "email", out var email) ||
            !TryBoolean(token.Claims, "email_verified", out var emailVerified) ||
            !emailVerified ||
            !IsGoogleProvider(token.Claims))
            return null;

        TryString(token.Claims, "name", out var displayName);
        return new GoogleIdentity(token.Uid, email, true, displayName);
    }

    private static bool IsGoogleProvider(IReadOnlyDictionary<string, object> claims)
    {
        if (!claims.TryGetValue("firebase", out var value) || value is null) return false;
        try
        {
            using var document = JsonDocument.Parse(JsonSerializer.Serialize(value));
            return document.RootElement.TryGetProperty("sign_in_provider", out var provider) &&
                ContainsGoogleProvider(provider);
        }
        catch (JsonException)
        {
            return false;
        }
    }

    private static bool ContainsGoogleProvider(JsonElement element)
    {
        if (element.ValueKind == JsonValueKind.String)
            return string.Equals(element.GetString(), "google.com", StringComparison.Ordinal);

        if (element.ValueKind == JsonValueKind.Array)
            return element.EnumerateArray().Any(ContainsGoogleProvider);

        if (element.ValueKind == JsonValueKind.Object)
            return element.EnumerateObject().Any(property => ContainsGoogleProvider(property.Value));

        return false;
    }

    private static bool TryString(IReadOnlyDictionary<string, object> claims, string key, out string value)
    {
        value = "";
        if (!claims.TryGetValue(key, out var raw) || raw is null) return false;
        value = raw is JsonElement element && element.ValueKind == JsonValueKind.String
            ? element.GetString() ?? ""
            : raw.ToString() ?? "";
        return !string.IsNullOrWhiteSpace(value);
    }

    private static bool TryBoolean(IReadOnlyDictionary<string, object> claims, string key, out bool value)
    {
        value = false;
        if (!claims.TryGetValue(key, out var raw) || raw is null) return false;
        if (raw is bool boolean) { value = boolean; return true; }
        if (raw is JsonElement element && element.ValueKind is JsonValueKind.True or JsonValueKind.False)
        { value = element.GetBoolean(); return true; }
        return bool.TryParse(raw.ToString(), out value);
    }
}
