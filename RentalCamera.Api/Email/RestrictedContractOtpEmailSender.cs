using System.Net.Mail;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Email;

// The default/auth/appendix senders stay fake. Only the contract request handler
// resolves this key, after the same database and provider guards have passed.
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
