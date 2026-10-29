using System.Data.Common;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore.Diagnostics;

namespace RentalCamera.Api.Infrastructure;

public sealed class Schema33TrialGuard : DbConnectionInterceptor
{
    private readonly string server;
    private readonly bool sandboxVnpay;
    public const string DatabaseName = "RentalCameraDb30_Test";
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
