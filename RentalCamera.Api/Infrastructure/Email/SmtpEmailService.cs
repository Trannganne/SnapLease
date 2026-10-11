using System.Net;
using System.Net.Mail;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace RentalCamera.Api.Infrastructure.Email
{
    public class SmtpEmailService : IEmailService
    {
        private readonly IConfiguration _config;
        private readonly ILogger<SmtpEmailService> _logger;

        public SmtpEmailService(IConfiguration config, ILogger<SmtpEmailService> logger)
        {
            _config = config;
            _logger = logger;
        }

        public async Task SendEmailAsync(string toEmail, string subject, string htmlMessage)
        {
            var host = _config["Smtp:Host"];
            var portString = _config["Smtp:Port"];
            var username = _config["Smtp:Username"];
            var password = _config["Smtp:Password"];
            var senderEmail = _config["Smtp:SenderEmail"];
            var senderName = _config["Smtp:SenderName"];

            if (string.IsNullOrEmpty(host) || string.IsNullOrEmpty(username) || string.IsNullOrEmpty(password))
            {
                _logger.LogWarning("SMTP configuration is missing. Cannot send email to {Email}", toEmail);
                return;
            }

            int port = string.IsNullOrEmpty(portString) ? 587 : int.Parse(portString);

#pragma warning disable SYSLIB0014 // Type or member is obsolete
            // Bypass SSL certificate validation if there's an UntrustedRoot issue (e.g., in Docker container without full root certs)
            System.Net.ServicePointManager.ServerCertificateValidationCallback = (sender, certificate, chain, sslPolicyErrors) => true;

            using var client = new SmtpClient(host, port)
            {
                Credentials = new NetworkCredential(username, password),
                EnableSsl = true // STARTTLS
            };

            var mailMessage = new MailMessage
            {
                From = new MailAddress(senderEmail ?? username, senderName ?? "SnapLease"),
                Subject = subject,
                Body = htmlMessage,
                IsBodyHtml = true
            };

            mailMessage.To.Add(toEmail);

            try
            {
                await client.SendMailAsync(mailMessage);
                _logger.LogInformation("Email sent successfully to {Email}", toEmail);
            }
            catch (System.Exception ex)
            {
                _logger.LogError(ex, "Failed to send email to {Email}", toEmail);
                throw; // rethrow to let the caller handle it or fail the test
            }
#pragma warning restore SYSLIB0014 // Type or member is obsolete
        }
    }
}
