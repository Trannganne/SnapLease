using System.Data.Common;
using System.Net.Mail;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore.Diagnostics;

namespace RentalCamera.Api.Infrastructure;

public sealed class Schema33TrialGuard : DbConnectionInterceptor
{
    private readonly string server;
    public const string DatabaseName = "RentalCameraDb30_Test";
    public bool ContractSmtpDemoEnabled { get; }
    public string? AllowedContractOtpRecipient { get; }
    public bool AuthSmtpDemoEnabled { get; }
    public Uri? AuthLinkBaseUri { get; }
    public Schema33TrialGuard(IConfiguration c, IHostEnvironment env)
    {
        if (env.EnvironmentName != "Schema33Trial" || !c.GetValue<bool>("Schema33Trial:Enabled") || !c.GetValue<bool>("Schema33Trial:PackageApproved"))
            throw new InvalidOperationException("Schema33 trial package guard chưa được duyệt/cấu hình. Không khởi động backend.");
        server = c["Schema33Trial:ExpectedDataSource"] ?? "";
        if (string.IsNullOrWhiteSpace(server) || c["Schema33Trial:ProviderMode"] != "Fake" ||
            c.GetValue<bool>("Rental:BackgroundJobsEnabled") || c.GetValue<bool>("Notifications:PushEnabled") ||
            c.GetValue<bool>("Chatbot:Enabled") || c.GetValue<bool>("ElectronicSignature:ReturnOtpInResponse") ||
            c.GetValue<bool>("PasswordReset:ReturnTokenInResponse")) throw new InvalidOperationException("Trial isolation guard không đầy đủ.");
        Validate(c.GetConnectionString("RentalCamera") ?? "");
        if (!c.GetValue<bool>("Vnpay:FakeTrial")) throw new InvalidOperationException("Fake payment mode bắt buộc.");
        foreach (var key in new[] { "PaymentUrl", "ReturnUrl", "IpnUrl", "QueryDrUrl" })
            if (!Uri.TryCreate(c["Vnpay:"+key],UriKind.Absolute,out var uri) || !uri.IsLoopback)
                throw new InvalidOperationException("Fake payment URLs chỉ được loopback.");

        var emailMode = c["ContractOtpEmail:Mode"] ?? "Fake";
        if (emailMode == "Fake")
        {
            if (c.GetValue<bool>("Email:Enabled") || c.GetValue<bool>("ContractOtpEmail:SmtpApproved"))
                throw new InvalidOperationException("SMTP chưa được chọn và duyệt riêng cho OTP ký hợp đồng.");
        }
        else if (emailMode == "SmtpDemo")
        {
            var allowedRecipient = c["ContractOtpEmail:AllowedRecipient"]?.Trim();
            var username = c["Email:Username"]?.Trim();
            if (!c.GetValue<bool>("ContractOtpEmail:SmtpApproved") || !c.GetValue<bool>("Email:Enabled") ||
                string.IsNullOrWhiteSpace(c["Email:Host"]) || c.GetValue<int>("Email:Port") != 587 ||
                !c.GetValue<bool>("Email:UseSsl") || !IsPlainEmail(username) ||
                !string.Equals(username, c["Email:FromAddress"]?.Trim(), StringComparison.OrdinalIgnoreCase) ||
                string.IsNullOrWhiteSpace(c["Email:Password"]) || !IsPlainEmail(allowedRecipient) ||
                string.IsNullOrWhiteSpace(c["ElectronicSignature:Pepper"]))
                throw new InvalidOperationException("SMTP OTP demo chưa được duyệt hoặc cấu hình TLS/người nhận/bí mật chưa đầy đủ.");
            ContractSmtpDemoEnabled = true;
            AllowedContractOtpRecipient = allowedRecipient;
        }
        else
        {
            throw new InvalidOperationException("Chế độ OTP ký hợp đồng không được phép.");
        }
        var authMode = c["AuthEmail:Mode"] ?? "Fake";
        if (authMode == "SmtpDemo")
        {
            if (!ContractSmtpDemoEnabled || !c.GetValue<bool>("AuthEmail:SmtpApproved") ||
                !Uri.TryCreate(c["AuthEmail:LinkBaseUrl"], UriKind.Absolute, out var link) ||
                link.Scheme != "http" || !link.IsLoopback || link.Port != 5003 ||
                link.AbsolutePath != "/auth-link" || link.UserInfo.Length != 0 ||
                link.Query.Length != 0 || link.Fragment.Length != 0)
                throw new InvalidOperationException("SMTP auth trial cần phê duyệt riêng và URL trung gian loopback đúng cấu hình.");
            AuthSmtpDemoEnabled = true;
            AuthLinkBaseUri = link;
        }
        else if (authMode != "Fake" || c.GetValue<bool>("AuthEmail:SmtpApproved"))
            throw new InvalidOperationException("Chế độ email auth trial chưa được duyệt.");
    }
    private static bool IsPlainEmail(string? value) =>
        !string.IsNullOrWhiteSpace(value) && MailAddress.TryCreate(value, out var address) &&
        string.Equals(address.Address, value, StringComparison.OrdinalIgnoreCase);
    public void Validate(string value)
    {
        SqlConnectionStringBuilder b;
        try { b = new(value); } catch (ArgumentException) { throw new InvalidOperationException("Trial connection không hợp lệ."); }
        if (b.InitialCatalog != DatabaseName || !string.Equals(b.DataSource, server, StringComparison.OrdinalIgnoreCase) ||
            b.IntegratedSecurity || b.UserID is "sa" or "SA" || string.IsNullOrWhiteSpace(b.UserID) ||
            !string.IsNullOrWhiteSpace(b.AttachDBFilename)) throw new InvalidOperationException("Connection bị chặn: chỉ DB trial và login trial được duyệt.");
    }
    public override InterceptionResult ConnectionOpening(DbConnection connection, ConnectionEventData eventData, InterceptionResult result)
    { Validate(connection.ConnectionString); return result; }
    public override ValueTask<InterceptionResult> ConnectionOpeningAsync(DbConnection connection, ConnectionEventData eventData, InterceptionResult result, CancellationToken cancellationToken = default)
    { Validate(connection.ConnectionString); return ValueTask.FromResult(result); }
}

public sealed class DenyExternalHttpHandler : HttpMessageHandler
{
    protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken) =>
        throw new HttpRequestException("External HTTP is disabled in Schema33Trial; use the synthetic callback harness.");
}
