using System.Data.Common;
using System.Net.Mail;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore.Diagnostics;

namespace RentalCamera.Api.Infrastructure;

public sealed class Schema33TrialGuard : DbConnectionInterceptor
{
    private readonly string server;
    private readonly bool sandboxVnpay;
    public const string DatabaseName = "RentalCameraDb30_Test";
    public bool ContractSmtpDemoEnabled { get; private set; }
    public string? AllowedContractOtpRecipient { get; private set; }
    public bool AuthSmtpDemoEnabled { get; private set; }
    public Uri? AuthLinkBaseUri { get; private set; }
    public Schema33TrialGuard(IConfiguration c, IHostEnvironment env)
    {
        sandboxVnpay = env.EnvironmentName == "Schema33Sandbox";
        if (env.EnvironmentName is not ("Schema33Trial" or "Schema33Sandbox") ||
            !c.GetValue<bool>("Schema33Trial:Enabled") || !c.GetValue<bool>("Schema33Trial:PackageApproved"))
            throw new InvalidOperationException("Schema33 trial package guard chưa được duyệt/cấu hình. Không khởi động backend.");
        server = c["Schema33Trial:ExpectedDataSource"] ?? "";
        if (string.IsNullOrWhiteSpace(server) || c["Schema33Trial:ProviderMode"] != "Fake" ||
            c.GetValue<bool>("Rental:BackgroundJobsEnabled") || c.GetValue<bool>("Notifications:PushEnabled") ||
            c.GetValue<bool>("Chatbot:Enabled") || c.GetValue<bool>("ElectronicSignature:ReturnOtpInResponse") ||
            c.GetValue<bool>("PasswordReset:ReturnTokenInResponse")) throw new InvalidOperationException("Trial isolation guard không đầy đủ.");
        Validate(c.GetConnectionString("RentalCamera") ?? "");
        ValidateVnpay(c);
        ValidateEmail(c);
    }

    public bool SandboxVnpay => sandboxVnpay;

    private void ValidateVnpay(IConfiguration c)
    {
        if (!sandboxVnpay)
        {
            if (!c.GetValue<bool>("Vnpay:FakeTrial")) throw new InvalidOperationException("Fake payment mode bắt buộc.");
            foreach (var key in new[] { "PaymentUrl", "ReturnUrl", "IpnUrl", "QueryDrUrl" })
                if (!Uri.TryCreate(c["Vnpay:"+key],UriKind.Absolute,out var uri) || !uri.IsLoopback)
                    throw new InvalidOperationException("Fake payment URLs chỉ được loopback.");
            return;
        }

        if (c.GetValue<bool>("Vnpay:FakeTrial") || !c.GetValue<bool>("Vnpay:Enabled"))
            throw new InvalidOperationException("Schema33Sandbox yêu cầu VNPAY Sandbox thật và không cho phép FakeTrial.");
        if (!TryHttps(c["Vnpay:PaymentUrl"], out var payment) || payment.Host != "sandbox.vnpayment.vn" ||
            !TryHttps(c["Vnpay:QueryDrUrl"], out var queryDr) || queryDr.Host != "sandbox.vnpayment.vn" ||
            !TryHttps(c["Vnpay:ReturnUrl"], out var returnUrl) ||
            !TryHttps(c["Vnpay:IpnUrl"], out var ipnUrl) ||
            !string.Equals(returnUrl.Host, ipnUrl.Host, StringComparison.OrdinalIgnoreCase) ||
            returnUrl.AbsolutePath != "/api/thanh-toan/vnpay/return" ||
            ipnUrl.AbsolutePath != "/api/thanh-toan/vnpay/ipn")
            throw new InvalidOperationException("Cấu hình VNPAY Sandbox hoặc callback HTTPS không hợp lệ.");
    }

    private static bool TryHttps(string? value, out Uri uri) =>
        Uri.TryCreate(value, UriKind.Absolute, out uri!) && uri.Scheme == Uri.UriSchemeHttps;

    private void ValidateEmail(IConfiguration c)
    {
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
                !TryAuthLink(c, out var link))
                throw new InvalidOperationException("SMTP auth trial cần phê duyệt riêng và URL trung gian đúng cấu hình môi trường.");
            AuthSmtpDemoEnabled = true;
            AuthLinkBaseUri = link;
        }
        else if (authMode != "Fake" || c.GetValue<bool>("AuthEmail:SmtpApproved"))
            throw new InvalidOperationException("Chế độ email auth trial chưa được duyệt.");
    }
    private static bool IsPlainEmail(string? value) =>
        !string.IsNullOrWhiteSpace(value) && MailAddress.TryCreate(value, out var address) &&
        string.Equals(address.Address, value, StringComparison.OrdinalIgnoreCase);

    private bool TryAuthLink(IConfiguration c, out Uri link)
    {
        if (!Uri.TryCreate(c["AuthEmail:LinkBaseUrl"], UriKind.Absolute, out link!) ||
            link.AbsolutePath != "/auth-link" || link.UserInfo.Length != 0 ||
            link.Query.Length != 0 || link.Fragment.Length != 0)
            return false;

        if (!sandboxVnpay)
            return link.Scheme == Uri.UriSchemeHttp && link.IsLoopback && link.Port == 5003;

        return link.Scheme == Uri.UriSchemeHttps &&
            Uri.TryCreate(c["Vnpay:ReturnUrl"], UriKind.Absolute, out var callback) &&
            string.Equals(link.Host, callback.Host, StringComparison.OrdinalIgnoreCase);
    }
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
