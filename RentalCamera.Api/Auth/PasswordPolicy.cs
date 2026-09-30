namespace RentalCamera.Api.Auth;

public static class PasswordPolicy
{
    public const string Description =
        "Mật khẩu phải có 8–128 ký tự, gồm chữ hoa, chữ thường, chữ số và ký tự đặc biệt.";

    public static bool IsValid(string? password) =>
        password is { Length: >= 8 and <= 128 } &&
        password.Any(char.IsUpper) &&
        password.Any(char.IsLower) &&
        password.Any(char.IsDigit) &&
        password.Any(c => !char.IsLetterOrDigit(c) && !char.IsWhiteSpace(c));
}
