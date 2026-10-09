namespace RentalCamera.Api.Email;

public interface IContractOtpEmailSender
{
    bool IsConfigured { get; }

    Task SendAsync(
        string recipientEmail,
        string recipientName,
        string contractId,
        string otp,
        DateTime expiresAt,
        CancellationToken cancellationToken);
}
