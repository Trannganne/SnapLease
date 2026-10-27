using System.Collections.Concurrent;
namespace RentalCamera.Api.Email;

// Test harness inspects this mailbox via DI only. Never expose tokens through HTTP or logs.
public interface IAuthEmailSender { Task SendAsync(string email, string purpose, string token, CancellationToken ct); }
public sealed record FakeTrialMessage(string Recipient, string Purpose, string Value);
public sealed class FakeTrialSender : IAuthEmailSender, IContractOtpEmailSender
{
    private readonly ConcurrentQueue<FakeTrialMessage> mailbox = new();
    public bool IsConfigured => true;
    public bool TryTake(out FakeTrialMessage? message) => mailbox.TryDequeue(out message);
    public Task SendAsync(string email, string purpose, string token, CancellationToken ct)
    {
        ct.ThrowIfCancellationRequested();
        if (mailbox.Count >= 100) throw new InvalidOperationException("Fake mailbox đầy; harness cần đọc thư trước.");
        mailbox.Enqueue(new(email, purpose, token)); return Task.CompletedTask;
    }
    public Task SendAsync(string recipientEmail, string recipientName, string contractId, string otp, DateTime expiresAt, CancellationToken cancellationToken) =>
        SendAsync(recipientEmail, "CONTRACT_OTP:" + contractId, otp, cancellationToken);
}
