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

        using var message = new MailMessage
        {
            From = new MailAddress(_options.FromAddress.Trim(), _options.FromName.Trim(), Encoding.UTF8),
            Subject = $"Mã OTP ký hợp đồng {contractId}",
            SubjectEncoding = Encoding.UTF8,
            BodyEncoding = Encoding.UTF8,
            IsBodyHtml = true,
            Body = $"""
                <p>Xin chào {safeName},</p>
                <p>Mã OTP dùng để xác nhận ký hợp đồng <strong>{safeContractId}</strong> là:</p>
                <p style="font-size:28px;font-weight:bold;letter-spacing:6px">{safeOtp}</p>
                <p>Mã có hiệu lực đến <strong>{expiresAt:HH:mm dd/MM/yyyy}</strong>.</p>
                <p>Không cung cấp mã này cho người khác. Nếu bạn không yêu cầu ký hợp đồng, hãy bỏ qua email này.</p>
                <p>Rental Camera</p>
                """
        };
        message.To.Add(new MailAddress(recipientEmail.Trim(), recipientName.Trim(), Encoding.UTF8));

        using var client = new SmtpClient(_options.Host.Trim(), _options.Port)
        {
            EnableSsl = _options.UseSsl,
            UseDefaultCredentials = false,
            Credentials = new NetworkCredential(_options.Username.Trim(), _options.Password),
            DeliveryMethod = SmtpDeliveryMethod.Network
        };

        logger.LogInformation("Đang gửi OTP ký hợp đồng {ContractId} tới email khách hàng.", contractId);
        try
        {
            await client.SendMailAsync(message, cancellationToken);
            logger.LogInformation("Đã gửi OTP ký hợp đồng {ContractId} qua email.", contractId);
        }
        catch (Exception exception)
        {
            logger.LogError(exception, "Gửi OTP ký hợp đồng {ContractId} qua email thất bại.", contractId);
            throw;
        }
    }
}
