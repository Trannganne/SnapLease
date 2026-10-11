using System.Threading.Tasks;

namespace RentalCamera.Api.Infrastructure.Email
{
    public interface IEmailService
    {
        Task SendEmailAsync(string toEmail, string subject, string htmlMessage);
    }
}
