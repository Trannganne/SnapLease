using System.Net;
using System.Net.Mail;
using System.Text;
using Microsoft.Extensions.Options;

namespace RentalCamera.Api.Email;

public sealed class SmtpContractOtpEmailSender(
    IOptions<EmailOptions> options,
    ILogger<SmtpContractOtpEmailSender> logger) : IContractOtpEmailSender
{
    private readonly EmailOptions _options = options.Value;

    public bool IsConfigured =>
        _options.Enabled &&
        !string.IsNullOrWhiteSpace(_options.Host) &&
        _options.Port is > 0 and <= 65535 &&
        !string.IsNullOrWhiteSpace(_options.Username) &&
        !string.IsNullOrWhiteSpace(_options.Password) &&
        !string.IsNullOrWhiteSpace(_options.FromAddress);

    public async Task SendAsync(
        string recipientEmail,
        string recipientName,
        string contractId,
        string otp,
        DateTime expiresAt,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured)
            throw new InvalidOperationException("Dịch vụ gửi email chưa được cấu hình đầy đủ.");

        var safeName = WebUtility.HtmlEncode(recipientName);
        var safeContractId = WebUtility.HtmlEncode(contractId);
        var safeOtp = WebUtility.HtmlEncode(otp);

        var body = $"""
                <p>Xin chào {safeName},</p>
                <p>Mã OTP dùng để xác nhận ký hợp đồng <strong>{safeContractId}</strong> là:</p>
                <p style="font-size:28px;font-weight:bold;letter-spacing:6px">{safeOtp}</p>
                <p>Mã có hiệu lực đến <strong>{expiresAt:HH:mm dd/MM/yyyy}</strong>.</p>
                <p>Không cung cấp mã này cho người khác. Nếu bạn không yêu cầu ký hợp đồng, hãy bỏ qua email này.</p>
                <p>Rental Camera</p>
                """;
        await SendMessageAsync(recipientEmail, recipientName, $"Mã OTP ký hợp đồng {contractId}", body, "CONTRACT_OTP", cancellationToken);
    }

    public async Task SendMessageAsync(string recipientEmail, string recipientName, string subject,
        string htmlBody, string purpose, CancellationToken cancellationToken)
    {
        if (!IsConfigured) throw new InvalidOperationException("Dịch vụ gửi email chưa được cấu hình đầy đủ.");
        using var message = new MailMessage
        {
            From = new MailAddress(_options.FromAddress.Trim(), _options.FromName.Trim(), Encoding.UTF8),
            Subject = subject,
            SubjectEncoding = Encoding.UTF8,
            BodyEncoding = Encoding.UTF8,
            IsBodyHtml = true,
            Body = htmlBody
        };
        message.To.Add(new MailAddress(recipientEmail.Trim(), recipientName.Trim(), Encoding.UTF8));

        using var client = new SmtpClient(_options.Host.Trim(), _options.Port)
        {
            EnableSsl = _options.UseSsl,
            UseDefaultCredentials = false,
            Credentials = new NetworkCredential(_options.Username.Trim(), _options.Password),
            DeliveryMethod = SmtpDeliveryMethod.Network
        };

        logger.LogInformation("SMTP delivery started. Purpose={Purpose}", purpose);
        try
        {
            await client.SendMailAsync(message, cancellationToken);
            logger.LogInformation("SMTP delivery accepted. Purpose={Purpose}", purpose);
        }
        catch (Exception exception)
        {
            // SMTP exceptions may contain recipient addresses. Never log the message/body.
            logger.LogWarning("SMTP delivery failed. Purpose={Purpose} ErrorType={ErrorType}", purpose, exception.GetType().Name);
            throw;
        }
    }
}
