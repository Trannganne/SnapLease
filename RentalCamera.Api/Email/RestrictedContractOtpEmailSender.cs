using System.Net.Mail;
using System.Net;
using RentalCamera.Api.Infrastructure;
using RentalCamera.Api.Auth;

namespace RentalCamera.Api.Email;

// Default senders stay fake. Contract and renewal-appendix OTP handlers
// resolve this key, after the same database and provider guards have passed.
public static class ContractSigningOtpRegistration
{
    public const string ServiceKey = "ContractSigningOtp";

    public static void Register(IServiceCollection services, Schema33TrialGuard guard)
    {
        if (guard.ContractSmtpDemoEnabled)
        {
            services.AddSingleton<SmtpContractOtpEmailSender>();
            services.AddKeyedSingleton<IContractOtpEmailSender>(ServiceKey, (sp, _) =>
                new RestrictedContractOtpEmailSender(
                    sp.GetRequiredService<SmtpContractOtpEmailSender>(), guard.AllowedContractOtpRecipient!));
        }
        else
        {
            services.AddKeyedSingleton<IContractOtpEmailSender>(ServiceKey, (sp, _) =>
                sp.GetRequiredService<FakeTrialSender>());
        }
    }
}

public static class AuthEmailRegistration
{
    public static void Register(IServiceCollection services, Schema33TrialGuard guard)
    {
        services.AddSingleton<IAuthEmailSender>(sp => guard.AuthSmtpDemoEnabled
            ? new RestrictedAuthEmailSender(sp.GetRequiredService<SmtpContractOtpEmailSender>(),
                guard.AllowedContractOtpRecipient!, guard.AuthLinkBaseUri!, sp.GetRequiredService<IConfiguration>())
            : sp.GetRequiredService<FakeTrialSender>());
    }
}

public sealed class RestrictedAuthEmailSender(SmtpContractOtpEmailSender inner,
    string allowedRecipient, Uri linkBaseUri, IConfiguration configuration) : IAuthEmailSender
{
    public static Uri BuildLink(Uri baseUri, string purpose, string token) =>
        new UriBuilder(baseUri) { Fragment = "purpose=" + Uri.EscapeDataString(purpose) + "&token=" + Uri.EscapeDataString(token) }.Uri;

    public async Task SendAsync(string email, string purpose, string token, CancellationToken ct)
    {
        if (purpose is not ("VERIFY_EMAIL" or "RESET_PASSWORD") ||
            AuthLinkService.NormalizeEmail(email) is not { } normalized ||
            !string.Equals(normalized, allowedRecipient, StringComparison.OrdinalIgnoreCase))
            throw new AuthEmailDeliveryException();
        var title = purpose == "VERIFY_EMAIL" ? "Xác minh email SnapLease" : "Đặt lại mật khẩu SnapLease";
        var section = purpose == "VERIFY_EMAIL" ? "EmailVerification" : "PasswordReset";
        var minutes = Math.Clamp(configuration.GetValue(section + ":TokenLifetimeMinutes", 15), 5, 60);
        var href = WebUtility.HtmlEncode(BuildLink(linkBaseUri, purpose, token).AbsoluteUri);
        var body = $"<p>{title}</p><p><a href=\"{href}\">Mở SnapLease để tiếp tục</a></p>" +
            $"<p>Liên kết có hiệu lực {minutes} phút. Chỉ mở trên điện thoại trial đang kết nối USB với máy chạy API local.</p>" +
            "<p>Mở liên kết không tự xác minh email hoặc đổi mật khẩu. Nếu bạn không yêu cầu, hãy bỏ qua email này. Không chia sẻ liên kết.</p>";
        try { await inner.SendMessageAsync(email, "", title, body, purpose, ct); }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch { throw new AuthEmailDeliveryException(); }
    }
}

public sealed class AuthEmailDeliveryException : Exception
{
    public AuthEmailDeliveryException() : base("Email auth trial chưa thể gửi. Không có token được trả về client.") { }
}

public sealed class RestrictedContractOtpEmailSender(
    IContractOtpEmailSender inner, string allowedRecipient) : IContractOtpEmailSender
{
    public bool IsConfigured => inner.IsConfigured;

    public Task SendAsync(string recipientEmail, string recipientName, string contractId,
        string otp, DateTime expiresAt, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var recipient = recipientEmail?.Trim();
        if (string.IsNullOrWhiteSpace(recipient) || !MailAddress.TryCreate(recipient, out var address) ||
            !string.Equals(address.Address, recipient, StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(recipient, allowedRecipient, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("SMTP OTP demo chỉ cho phép người nhận đã được duyệt.");

        // Keep the server-selected recipient. Never redirect to the allowlist.
        return inner.SendAsync(recipientEmail!, recipientName, contractId, otp, expiresAt, cancellationToken);
    }
}
